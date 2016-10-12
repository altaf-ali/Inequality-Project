#!/usr/bin/env Rscript

library(argparse)
library(logging)
library(yaml)
library(countrycode)
library(nightlight)

# GIS
library(RColorBrewer)
library(GISTools)
library(raster)
library(rgdal)
library(cshapes)
library(mapproj)

# hadleyverse
library(stringr)
library(readr)
library(dplyr)
library(ggplot2)

rm(list = ls())

arg_parser <- ArgumentParser()
arg_parser$add_argument("--config", required=TRUE, help="config file")
arg_parser$add_argument("--params", required=TRUE, help="parameters file")
arg_parser$add_argument("--task-id", required=TRUE, type="integer", help="SGE task ID")

if (interactive()) {
  output_root <- file.path("~/Scratch/inequality", format(Sys.Date(), "%Y_%m_%d"))
  args <- list(
    config = "config.yaml",
    params = file.path(output_root, "params.csv"),
    task_id = 24
  )
} else {
  args <- arg_parser$parse_args()
}

config <- yaml.load_file(args$config)

dataset_path <- function(config, dataset) {
    path.expand(file.path(config$datasets$root, dataset))
}
  
params <- read_csv(args$params)
task <- params[args$task_id,]

for (filename in c(task$log, task$data)) {
  dir_path <- dirname(filename)
  if (!dir.exists(dir_path)) 
    dir.create(dir_path, recursive=TRUE)
}

logger <- getLogger()
logger$setLevel(config$logging$level)
logger$addHandler(writeToConsole)
logger$addHandler(writeToFile, file = task$log)

logger$info("Loading nightlight dataset")
nightlight <- nightlight_load(dataset_path(config, config$datasets$noaa), logger$info)

logger$info("Loading Gridded Population of the World (GPW)")
gpw <- raster::raster(dataset_path(config, config$datasets$gpw))

logger$info("Loading GeoEPR")
geo_epr_path <- dataset_path(config, config$datasets$geo_epr)
geoepr <- rgdal::readOGR(dirname(geo_epr_path), basename(geo_epr_path))

# masking function
masked_obj_OLD <- function(source_data, spatial_mask) {
  extent_obj <- raster::extent(spatial_mask)
  cropped_obj <- raster::crop(source_data, extent_obj) 
  list(extent = extent_obj, raster = raster::mask(cropped_obj, mask = spatial_mask))
}

masked_obj <- function(source_data, spatial_mask) {
  extent_obj <- raster::extent(spatial_mask)
  cropped_obj <- raster::crop(source_data, extent_obj) 
  masked_obj <- raster::mask(cropped_obj, mask = spatial_mask)
  data_values <- raster::values(masked_obj)
  list(extent = extent_obj, 
       masked = masked_obj,
       raster = raster::setValues(masked_obj, seq_along(data_values)), 
       values = data_values)
}

show_obj <- function(obj) {
  prefix <- "\t"
  for (line in capture.output(show(obj))) {
    if (nchar(line))
      logger$info(sprintf("%s%s", prefix, line))
  }
}

logger$info("Getting spatial mask for country %s", task$gwc)
cshapes_2012 <- cshapes::cshp(date = as.Date('2012-06-30'))
country_mask <- subset(cshapes_2012, GWCODE == task$gwn)

logger$info("Applying country mask to GPW object")
gpw_obj <- masked_obj(gpw, country_mask)
show_obj(gpw_obj$raster)

logger$info("Converting GPW raster object to polygons")
gpw_obj$grids <- rasterToPolygons(gpw_obj$raster)
names(gpw_obj$grids)[1] <- "grid_id"
gpw_obj$grids$population_density <- gpw_obj$values
show_obj(gpw_obj$grids)

logger$info("Transforming GeoEPR projection to GPW coordinate reference system")
logger$info("    GeoEPR CRS: %s", raster::crs(geoepr))
logger$info("       GPW CRS: %s", raster::crs(gpw_obj$grids))
geoepr_groups <- sp::spTransform(subset(geoepr, gwid == task$gwn), raster::crs(gpw_obj$grids))

# find overlays
overlays <- sp::over(geoepr_groups, gpw_obj$grids, returnList = TRUE)

# bind all groups into a single data frame
grid_table <- dplyr::bind_rows(lapply(seq_along(overlays), function(i) {
  tbl_df(overlays[[i]]) %>%
    mutate(group_id = geoepr_groups@data$groupid[i],
           group = geoepr_groups@data$group[i])
}))

#find duplicates
geoepr_duplicates <- grid_table %>%
  group_by(grid_id) %>%
  summarize(count = n()) %>%
  filter(count > 1)

logger$info("Found %d duplidates in %d grids", nrow(geoepr_duplicates), nrow(gpw_obj$grids))

grid_table <- grid_table %>%
  anti_join(geoepr_duplicates, by = "grid_id")

logger$info("Merging nightlight data")

grid_table <- dplyr::bind_rows(lapply(nightlight[1:2], function(n) {
  nightlight_year <- as.numeric(str_match(names(n), "^F\\d{2}(\\d{4})")[2])
  logger$info("Resample nightlight data from %d", nightlight_year)
  
  nightlight_obj <- masked_obj(n, country_mask)
  nightlight_obj$raster <- raster::resample(nightlight_obj$masked, gpw_obj$masked)

  nightlight_table <- data_frame(
    year = nightlight_year,
    grid_id = seq_along(nightlight_obj$raster),
    nightlight = raster::values(nightlight_obj$raster)
  )
  
  grid_table %>%
    left_join(nightlight_table, by = "grid_id")
}))

logger$info("Merge complete")

grid_table <- grid_table %>%
  mutate(gwn = task$gwn, gwc = task$gwc) %>%
  select(gwn, gwc, year, grid_id, group_id, group, population_density, nightlight) %>%
  arrange(year, grid_id)

logger$info("Writing %s", task$data)
write_csv(grid_table, task$data, na = "")

# group_means <- grid_table %>%
#   filter(!is.na(population_density)) %>%
#   group_by(group, year) %>%
#   summarize(nightlight_mean = weighted.mean(nightlight, population_density, na.rm = TRUE))

# ggplot(group_means, aes(year, nightlight_mean, color=group)) +
#   geom_line()
# 
# plot(gpw_obj$grids, border = "gray80")
# gpw_obj$duplicate_grids <- subset(gpw_obj$grids, grid_id %in% geoepr_duplicates$grid_id)
# plot(gpw_obj$duplicate_grids, add = TRUE, col = "red")
# plot(geoepr_groups, add = TRUE, border = "gray75", col = add.alpha(brewer.pal(12, "Set3"), 0.5))



