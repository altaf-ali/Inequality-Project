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

grid_summary <- dplyr::bind_rows(lapply(unique(population_groups$gwid), function(gwid) {
  country_name <- countrycode(gwid, "cown", "country.name")
  print(country_name)
  country_iso3c <- countrycode(gwid, "cown", "iso3c")
  
  spatial_data <- subset(countries, iso_a3 == country_iso3c)
  if (length(spatial_data$featurecla)) {
    population_obj <- masked_obj(population_data, spatial_data)
    
    num_rows <- nrow(population_obj)
    num_cols <- nrow(population_obj)
    num_cells <- ncell(population_obj)
  } else {
    print("... missing data")
    num_rows <- NA
    num_cols <- NA
    num_cells <- NA
  }
  
  data_frame(country_gwid = gwid,
             country_iso3c = country_iso3c,
             country_name = country_name,
             rows = num_rows,
             cols = num_cols,
             cells = num_cells)
}))


colnames(grid_summary)[3] = "country_name"
grid_summary <- grid_summary %>%
  arrange(country_iso3c)

write_csv(grid_summary, "~/Projects/inequality/data/grid_summary.csv")
