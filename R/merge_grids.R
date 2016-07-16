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
arg_parser$add_argument("--params", required=TRUE, help="parameters file")
arg_parser$add_argument("--task-id", required=TRUE, type="integer", help="SGE task ID")
args <- arg_parser$parse_args()

config <- yaml.load_file(args$config)

params <- read_csv(args$params)
task <- params[args$task_id,]

for (path in c(task$log, task$data)) {
  if (!dir.exists(path)) 
    dir.create(path, recursive=TRUE)
}

logger <- getLogger()
logger$setLevel(config$logging$level)
logger$addHandler(writeToConsole)
logger$addHandler(writeToFile, file = task$log)

gwc <- countrycode(task$gwn, "gwn", "gwc")
if (is.na(gwc))
  stop(paste("Invalid country code", args$gwn))#

logger$info("Merge started: country = %s", gwc)

logger$info("Merge complete: country = %s", gwc)

