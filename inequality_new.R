library(countrycode)
library(raster)
library(rgdal)
library(sp)
library(ggplot2)
library(readr)
library(tidyr)
library(dplyr)

rm(list = ls())
source("~/Projects/nightlight/nightlight.R")

DATASET_ROOT <- "~/Datasets"
NOAA <- "noaa"
GPW <- "gpw/gldens00/glds00ag/w001001.adf"
GEO_EPR <- "geoEPR/2014"
NATURAL_EARTH <- "natural_earth"

OUTPUT_ROOT <- "~/Projects/inequality/data/"

dataset_path <- function(dataset) {
  path.expand(file.path(DATASET_ROOT, dataset))
}

nightlight_data <- nightlight_load(dataset_path(NOAA))
countries <- rgdal::readOGR(dataset_path(NATURAL_EARTH), "ne_50m_admin_0_countries")  
population_data <- raster::raster(dataset_path(GPW))
population_groups <- rgdal::readOGR(dataset_path(GEO_EPR), "GeoEPR-2014")

masked_obj <- function(source_data, spatial_data) {
  cropped_obj <- raster::crop(source_data, raster::extent(spatial_data))
  raster::mask(cropped_obj, mask = spatial_data) 
}

build_grid_table <- function(population, groups) {
  population_obj <- population
  population_obj_values <- raster::values(population_obj)
  population_obj <- raster::setValues(population_obj, seq_along(population_obj))
  
  grids <- rasterToPolygons(population_obj)
  grids@data$grid_id <- seq_along(population_obj)
  grids@data$population_density <- population_obj_values

  groups_obj <- groups
  groups <- sp::spTransform(groups_obj, raster::crs(grids))
  overlays <- sp::over(groups, grids, returnList = TRUE)
  
  groups_list <- lapply(seq_along(overlays), function(i) {
    data.frame(overlays[[i]], group_id = groups@data$groupid[i])
  })
  
  dplyr::bind_rows(groups_list) %>%
    dplyr::mutate(group = factor(group_id, levels = groups@data$groupid, labels = groups@data$group)) %>%
    dplyr::select(grid_id, group, group_id, population_density)
}

# Runtime Parameters
grid_scale <- 1

# Test case: (use iso3c code)
country_iso3c <- "DZA"

country_cown <- countrycode(country_iso3c, "iso3c", "cown")

spatial_data <- subset(countries, iso_a3 == country_iso3c)

population_obj <- masked_obj(population_data, spatial_data)

grids <- rasterToPolygons(population_obj)
groups_obj <- population_groups[population_groups$gwid == country_cown,]

grids_DZA <- build_grid_table(population_obj, groups_obj)
nightlight_obj <- raster::resample(masked_obj(nightlight_data[[1]], spatial_data), population_obj)

grid_table <- dplyr::bind_rows(lapply(nightlight_data, function(n) { 
  nightlight_year <- as.numeric(str_match(n@data@names, "^F\\d{2}(\\d{4})")[2])
  message(paste(Sys.time(), "resample nightlight data from", nightlight_year))

  nightlight_obj <- raster::resample(masked_obj(n, spatial_data), population_obj)

  build_grid_table(population_obj, groups_obj, nightlight_obj) %>%
    mutate(year = nightlight_year) %>%
    select(year, grid_id, group_id, group, population_density, nightlight)
}))

DZA <- grid_table
write.csv(grid_table, file.path(OUTPUT_ROOT, paste0(country_iso3c, ".csv")), row.names = FALSE)
          
group_means <- grid_table %>%
  filter(!is.na(population_density)) %>%
  group_by(group, year) %>%
  summarize(nightlight_mean = weighted.mean(nightlight, population_density, na.rm = TRUE))

ggplot(group_means, aes(year, nightlight_mean, color=group)) +
  geom_line()

         