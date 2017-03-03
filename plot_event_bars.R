library(readr)
library(dplyr)
library(tidyr)
library(stringr)

library(ggplot2)

rm(list = ls())

EVENT_DATA <- "~/Dropbox/wombat/outputData/merged_data.csv"

OUTPUT_FOLDER <- "~/Projects/inequality/visualizations/events"

merged_data <- read_csv(EVENT_DATA)

country_gwc <- "AFG"

events <- merged_data %>%
  #filter(Year > 2000, Year <= 2001) %>%
  #filter(Month == 1) %>%
  filter(GWC == country_gwc) %>%
  gather(ActorEventType, EventCount, matches("Civilian|Insurgent|Opposition|Rebel")) %>%
  separate(ActorEventType, c("Actor", "EventType"), sep = "_") %>%
  mutate(Date = as.Date(ISOdate(Year, Month, 1))) %>%
  mutate(EventType = substr(gsub("([A-Z])","\\ \\1",EventType),2,.Machine$integer.max)) %>%
  mutate(EventType = factor(EventType, levels = c("Material Cooperation", "Verbal Cooperation", "Verbal Conflict", "Material Conflict"))) %>%
  select(Country, GWC, Date, Actor, EventType, EventCount)

ggplot(events, aes(x = Date, y = EventCount, fill = EventType)) +
  geom_bar(stat="identity", position=position_dodge(), alpha = 0.7) +
  facet_wrap( ~ Actor, ncol = 2) +
  scale_fill_brewer(palette = "RdYlGn", direction=-1)

for (pal in row.names(brewer.pal.info)) {
  p <- ggplot(events, aes(x = Date, y = EventCount, fill = EventType)) +
    geom_bar(stat="identity", position=position_dodge()) +
    facet_wrap( ~ Actor, ncol = 2) +
    scale_fill_brewer(palette = pal)
  
  filename <- file.path(OUTPUT_FOLDER, "pal", paste0(pal, ".png"))
  ggsave(filename, p)
}


