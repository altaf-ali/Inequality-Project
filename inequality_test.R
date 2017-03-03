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
