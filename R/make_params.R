library(yaml)

rm(list = ls())

config <- yaml.load_file('config.yaml')

# path expander
make_path <- function(base, dataset) {
  path.expand(file.path(base$root, dataset))
}

geo_epr_path <- make_path(config$datasets, config$datasets$geo_epr)
geoepr <- rgdal::readOGR(dirname(geo_epr_path), basename(geo_epr_path))

params <- data_frame(gwn = unique(geoepr$gwid)) %>%
  mutate(task_id = row_number()) %>%
  write_csv(make_path(config$output, config$output$params))

