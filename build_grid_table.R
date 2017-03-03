# load packages
library(countrycode)
library(raster)
library(rgdal)
library(sp)
library(readr)
library(tidyr)
library(dplyr)
library(RColorBrewer)
library(ineq)
library(logging)
library(argparse)

rm(list = ls())

LOG_FILE <- "/tmp/foo.log"
LOG_LEVEL <- "DEBUG"

logger <- getLogger()
logger$setLevel(LOG_LEVEL)
logger$addHandler(writeToConsole)
logger$addHandler(writeToFile, file = LOG_FILE)

main <- function() {
  logger$info("Starting")
  
  # parse command line args
  args <- commandArgs(trailingOnly = TRUE)

  args = c("a", "x", "m")
  logger$info("command line arguments = %s", paste(args, collapse = " "))  
  
  if (is.null(args) || !length(args)) {
    stop("Missing argument")
  }

  stop("EXIT")
  
  args = c("BHR")
  #args = c("MUS")
  #args = c("LBN")
  #args = c("BTN")
  args = c("LBN")
  
  # country codes
  country <- list(
    iso3c = args[1],
    iso3n = countrycode(args[1], "iso3c", "iso3n"),
    cow3n = countrycode(args[1], "iso3c", "cown")
  )
  
  source("~/projects/nightlight/nightlight.R")
  
  DATASET_ROOT <- "~/datasets"
  NOAA <- "noaa"
  GPW <- "gpw/gldens00/glds00ag/w001001.adf"
  GEO_EPR <- "geoEPR/2014"
  NATURAL_EARTH <- "natural_earth"
  
  OUTPUT_ROOT <- "~/projects/inequality/data"
  
  # path expander
  dataset_path <- function(dataset) {
    path.expand(file.path(DATASET_ROOT, dataset))
  }
  
  # masking function
  masked_obj <- function(source_data, spatial_mask) {
    cropped_obj <- raster::crop(source_data, raster::extent(spatial_mask))
    raster::mask(cropped_obj, mask = spatial_mask) 
  }
  
  # load all datasets
  nightlight <- nightlight_load(dataset_path(NOAA))
  countries <- rgdal::readOGR(dataset_path(NATURAL_EARTH), "ne_50m_admin_0_countries")  
  gpw <- raster::raster(dataset_path(GPW))
  geoepr <- rgdal::readOGR(dataset_path(GEO_EPR), "GeoEPR-2014")
  
  spatial_mask <- subset(countries, iso_a3 == country$iso3c)
  
  gpw_masked <- masked_obj(gpw, spatial_mask)
  
  population_density <- raster::values(gpw_masked)
  gpw_masked <- raster::setValues(gpw_masked, seq_along(gpw_masked))
  
  gpw_grids <- rasterToPolygons(gpw_masked)
  
  gpw_grids@data$grid_id <- seq_along(gpw_masked)
  gpw_grids@data$population_density <- population_density
  
  geoepr_groups <- sp::spTransform(subset(geoepr, gwid == country$cow3n), raster::crs(gpw_grids))
  overlays <- sp::over(geoepr_groups, gpw_grids, returnList = TRUE)
  
  # bind all groups into a single data frame
  grid_table <- dplyr::bind_rows(lapply(seq_along(overlays), function(i) {
    tbl_df(overlays[[i]]) %>%
      mutate(group_id = geoepr_groups@data$groupid[i],
             group = geoepr_groups@data$group[i])
  }))
  
  # remove grids with more than one group
  duplicate_grids <- grid_table %>%
    group_by(grid_id) %>%
    summarize(count = n()) %>%
    filter(count > 1)
  
  grid_table <- grid_table %>%
    anti_join(duplicate_grids, by = "grid_id")
  
  grid_table <- dplyr::bind_rows(lapply(nightlight, function(n) {
    nightlight_year <- as.numeric(str_match(names(n), "^F\\d{2}(\\d{4})")[2])
    message(paste(Sys.time(), "resample nightlight data from", nightlight_year))
    
    nightlight_obj <- raster::resample(masked_obj(n, spatial_mask), gpw_masked)
    
    nightlight_table <- data_frame(
      year = nightlight_year,
      grid_id = seq_along(nightlight_obj),
      nightlight = raster::values(nightlight_obj)
    )
    
    grid_table %>%
      left_join(nightlight_table, by = "grid_id")
  }))
  
  grid_table <- grid_table %>%
    mutate(country_iso3c = country$iso3c) %>%
    select(country_iso3c, year, grid_id, group_id, group, population_density, nightlight)
  
  #write_csv(grid_table, file.path(OUTPUT_ROOT, paste0(country$iso3c, ".csv")))
}

# exception handling
result <- tryCatch({
  main()
}, warning = function(w) { 
  logger$warn(w)
}, error = function(e) {
  logger$error(e)
}, finally = {
  logger$info("Terminating")
})

