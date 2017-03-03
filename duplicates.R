library(raster)
library(logging)
library(yaml)
library(countrycode)
library(dplyr)
library(readr)

rm(list = ls())

args <- list(
  config = "config.yaml"
)

config <- yaml.load_file(args$config)

logger <- getLogger()
logger$setLevel(config$logging$level)
logger$addHandler(writeToConsole)

expanded_path <- function(config, dataset) {
  path.expand(file.path(config$datasets$root, dataset))
}

logger$info("Loading Gridded Population of the World (GPW)")
gpw <- raster::raster(expanded_path(config, config$datasets$gpw))

logger$info("Loading GeoEPR")
geo_epr_path <- expanded_path(config, config$datasets$geo_epr)
geoepr <- rgdal::readOGR(dirname(geo_epr_path), basename(geo_epr_path))

masked_obj <- function(source_data, spatial_mask) {
  extent_obj <- raster::extent(spatial_mask)
  cropped_obj <- raster::crop(source_data, extent_obj) 
  masked_obj <- raster::mask(cropped_obj, mask = spatial_mask)
  data_values <- raster::values(masked_obj)
  list(extent = extent_obj, 
       raster = raster::setValues(masked_obj, seq_along(data_values)), 
       values = data_values)
}

show_obj <- function(obj) {
  prefix <- "\t"
  for (line in capture.output(show(obj))) {
    if (nchar(line))
      logger$debug(sprintf("%s%s", prefix, line))
  }
}

cshapes_2012 <- cshapes::cshp(date = as.Date('2012-06-30'))

get_grid_stats <- function(country) {
  gwc <- countrycode(country$gwn, "gwn", "gwc")

  logger$info("Getting spatial mask for %s (%d) %s", gwc, country$gwn, country$country_name)
  country_mask <- subset(cshapes_2012, GWCODE == country$gwn)
  
  logger$info("Applying country mask to GPW object")
  gpw_obj <- masked_obj(gpw, country_mask)
  show_obj(gpw_obj$raster)
  if (ncell(gpw_obj$raster) > 500000) {
    return(list(grids = ncell(gpw_obj$raster), multigroup_grids = NA))
  }
  
  logger$info("Converting GPW raster object to polygons")
  gpw_obj$grids <- rasterToPolygons(gpw_obj$raster)
  names(gpw_obj$grids)[1] <- "grid_id"
  gpw_obj$grids$population_density <- gpw_obj$values
  show_obj(gpw_obj$grids)
  
  logger$info("Transforming GeoEPR projection to GPW coordinate reference system")
  logger$debug("    GeoEPR CRS: %s", raster::crs(geoepr))
  logger$debug("       GPW CRS: %s", raster::crs(gpw_obj$grids))
  geoepr_groups <- sp::spTransform(subset(geoepr, gwid == country$gwn), raster::crs(gpw_obj$grids))
  
  # find overlays
  overlays <- sp::over(geoepr_groups, gpw_obj$grids, returnList = TRUE)
  
  # bind all groups into a single data frame
  group_table <- dplyr::bind_rows(lapply(seq_along(overlays), function(i) {
    tbl_df(overlays[[i]]) %>%
      mutate(group_id = geoepr_groups@data$groupid[i],
             group = geoepr_groups@data$group[i])
  }))
  
  #find duplicates
  multigroup_grids <- group_table %>%
    group_by(grid_id) %>%
    summarize(count = n()) %>%
    filter(count > 1)
  
  logger$info("Found %d duplidates in %d grids", nrow(multigroup_grids), nrow(gpw_obj$grids))
  
  list(grids = nrow(gpw_obj$grids), multigroup_grids = nrow(multigroup_grids))
}

grid_stats <- dplyr::bind_rows(lapply(seq_along(cshapes_2012), function(i) {
  country <- list(
    gwn = cshapes_2012$GWCODE[i],
    country_name = cshapes_2012$CNTRY_NAME[i]
  )
  
  if (country$gwn %in% geoepr$gwid) {
    country <- append(country, get_grid_stats(country))
  }
  
  as_data_frame(country)
}))
  
grid_stats <- grid_stats %>%
  mutate(multigroup_grids_percent = multigroup_grids / grids)

grid_stats %>%
  arrange(country_name) %>%
  write_csv("grid_stats.csv")
