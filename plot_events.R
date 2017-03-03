library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(countrycode)

library(ggplot2)

rm(list = ls())

EVENT_DATA <- "~/Dropbox/wombat/outputData/merged_data.csv"

OUTPUT_FOLDER <- "~/Projects/inequality/visualizations/events"

merged_data <- read_csv(EVENT_DATA)

countries <- unique(merged_data$GWC)

create_plot <- function(merged_data, country_gwc) {
  country_name <- countrycode(country_gwc, "gwc", "country.name")

  events <- merged_data %>%
    filter(GWC == country_gwc) %>%
    filter(Year > 2000, Year < 2008) %>%
    gather(ActorEventType, EventCount, matches("Civilian|Insurgent|Opposition|Rebel")) %>%
    separate(ActorEventType, c("Actor", "EventType"), sep = "_") %>%
    mutate(Date = as.Date(ISOdate(Year, Month, 1))) %>%
    mutate(EventType = substr(gsub("([A-Z])","\\ \\1",EventType),2,.Machine$integer.max)) %>%
    mutate(EventType = factor(EventType, levels = c("Material Cooperation", "Verbal Cooperation", "Verbal Conflict", "Material Conflict"))) %>%
    select(Country, GWC, Date, Actor, EventType, EventCount)
  
  x_axis_breaks <- seq(min(events$Date), max(events$Date), by="4 years")

  events %>%
    ggplot(aes(Date, EventCount, fill = EventType)) +
      ggtitle(country_name) +
      scale_x_date(breaks = seq(min(events$Date), max(events$Date), by="4 years"), 
                   date_minor_breaks = "2 years",
                   date_labels = "%Y") +
      ylab("Active Days per Month") +
      ylim(0, 31) +
      #scale_fill_brewer(palette = "RdYlGn", direction=-1) +
      scale_fill_brewer(palette = "RdYlGn", direction=-1) +
      theme(legend.title=element_blank(),
            axis.text.x = element_text(angle = 30),
            axis.title.x = element_blank(),
            strip.text.x = element_text(size = 12)) +
    facet_wrap( ~ Actor, ncol = 2)
}

create_line_plot <- function(merged_data, country_gwc) {
  create_plot(merged_data, country_gwc) +
    geom_line()
}

create_smooth_plot <- function(merged_data, country_gwc) {
  create_plot(merged_data, country_gwc) +
    stat_smooth(size = 0.7, level = 0)
}

create_bar_plot <- function(merged_data, country_gwc) {
  create_plot(merged_data, country_gwc) +
    geom_bar(stat="identity", position=position_dodge(), alpha = 1)
}

save_plot <- function(merged_data, gwc, plot_func, outdir) {
  country_plot <- plot_func(merged_data, gwc)
  ggsave(file.path(outdir, paste0(gwc, ".png")), plot = country_plot)
}

plot_all <- function(plot_func, outdir) {
  for (gwc in countries) {
    message("Creating ICEWS plot: ", gwc)
    save_plot(merged_data, gwc, plot_func, outdir)
  }
}

#plot_all(create_line_plot, file.path(OUTPUT_FOLDER, "icews"))
#plot_all(create_smooth_plot, file.path(OUTPUT_FOLDER, "icews_smooth"))

#plot_all(create_bar_plot, file.path(OUTPUT_FOLDER, "icews_bar"))

create_bar_plot(merged_data, "AFG")
