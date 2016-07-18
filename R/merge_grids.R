#!/usr/bin/env Rscript

library(argparse)
library(logging)
library(yaml)
library(countrycode)
library(nightlight)
library(dplyr)
library(readr)

rm(list = ls())

arg_parser <- ArgumentParser()
arg_parser$add_argument("--config", required=TRUE, help="config file")
arg_parser$add_argument("--params", required=TRUE, help="parameters file")
arg_parser$add_argument("--task-id", required=TRUE, type="integer", help="SGE task ID")
args <- arg_parser$parse_args()

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

logger$info("Merge started: country = %s", task$gwc)

nightlight <- nightlight_load(dataset_path(config, config$datasets$noaa))
gpw <- raster::raster(dataset_path(config, config$datasets$gpw))

geo_epr_path <- dataset_path(config, config$datasets$geo_epr)
geoepr <- rgdal::readOGR(dirname(geo_epr_path), basename(geo_epr_path))

logger$info("Merge complete")


