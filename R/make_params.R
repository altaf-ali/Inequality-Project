#!/usr/bin/env Rscript

library(argparse)
library(logging)
library(yaml)
library(countrycode)
library(dplyr)
library(readr)

rm(list = ls())

arg_parser <- ArgumentParser()
arg_parser$add_argument("--config", required=TRUE, help="config file")
args <- arg_parser$parse_args()

config <- yaml.load_file(args$config)

logger <- getLogger()
logger$setLevel(config$logging$level)
logger$addHandler(writeToConsole)

geo_epr_path <- file.path(config$datasets$root, config$datasets$geo_epr)

logger$info("Loading %s", geo_epr_path)
geoepr <- rgdal::readOGR(dirname(geo_epr_path), basename(geo_epr_path))

output_root <- file.path(config$output$root, format(Sys.Date(), "%Y_%m_%d"))
logger$info("Creating directory %s", output_root)
dir.create(output_root, recursive=TRUE)

params_file <- file.path(output_root, config$output$params)
logger$info("Writing %s", params_file)

params <- data_frame(gwn = unique(geoepr$gwid)) %>%
  mutate(task_id = row_number(),
  	     gwc = countrycode(gwn, "gwn", "gwc"),
  	     log = file.path(output_root, "log", paste0(gwc, ".log")),
  	     data = file.path(output_root, "data", paste0(gwc, ".csv"))
  	     ) %>%
  select(task_id, gwc, gwn, log, data) %>%
  write_csv(params_file)

