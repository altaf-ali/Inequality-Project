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

if (interactive()) {
  args <- list(
    config = "config.yaml"
  )
} else {
  args <- arg_parser$parse_args()
}

config <- yaml.load_file(args$config)

logger <- getLogger()
logger$setLevel(config$logging$level)
logger$addHandler(writeToConsole)

logger$info("Getting a list of all files in %s", output_root)
files <- list.files(file.path(config$output$root, "latest"), "*.csv", full.names = TRUE)

grids <- dplyr::bind_rows(lapply(files, function(f) {
  read.csv(f, stringsAsFactors = FALSE)
}))

saveRDS(grids, "grids.rds")
