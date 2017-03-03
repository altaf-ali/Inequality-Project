library(dplyr)
library(ggplot2)
library(ggvis)
library(countrycode)

rm(list = ls())

OUTPUT_FOLDER <- "~/Projects/inequality/visualizations/nightlight"

grids <- readRDS("data/grids.rds")
head(grids)

countries <- unique(grids$gwc)

create_plot <- function(country_gwc, grids) {
  country_name <- countrycode(country_gwc, "gwc", "country.name")
  
  grids %>%
    filter(gwc == country_gwc, !is.na(population_density)) %>%
    group_by(year, group) %>%
    summarize(nightlight_mean = weighted.mean(nightlight, population_density, na.rm = TRUE)) %>%
    mutate(Date = as.Date(ISOdate(year, 1, 1))) %>%
    ggplot(aes(Date, nightlight_mean, color=group)) +
      ggtitle(country_name) +
      stat_smooth(size = 0.7, level = 0) +
      ylab("Weighted Nightlight Mean") +
      geom_point(size = 1) +
      theme(legend.title=element_blank(),
            axis.text.x = element_text(angle = 30),
            axis.title.x = element_blank()) +
    scale_x_date(date_breaks = "2 years", 
                 date_minor_breaks = "1 year",
                 date_labels = "%Y")
}

save_plot <- function(gwc, grids, outdir) {
  country_plot <- create_plot(gwc, grids)
  ggsave(file.path(outdir, paste0(gwc, ".png")), plot = country_plot)
}

plot_all <- function() {
  for (gwc in countries) {
    message("Creating nightline plot: ", gwc)
    save_plot(gwc, grids, OUTPUT_FOLDER)
  }
}

plot_all()

create_plot("IRQ", grids) 
