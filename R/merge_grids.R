# load packages
library(yaml)
library(logging)
library(argparse)

rm(list = ls())

config <- yaml.load_file('config.yaml')

# path expander
make_path <- function(base, dataset) {
  path.expand(file.path(base$root, dataset))
}

# logger <- getLogger()
# logger$setLevel(config$logging$level)
# logger$addHandler(writeToConsole)
# logger$addHandler(writeToFile, file = logfile)
