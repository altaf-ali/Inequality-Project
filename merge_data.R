library(ineq)
library(dplyr)
library(tidyr)
library(ggplot2)
library(countrycode)

grids <- readRDS("~/Dropbox/wombat/outputData/grids/grids.rds")

head(grids)

groups <- grids %>%
  group_by(group, group_id) %>%
  summarize()

group_means <- grids %>%
  filter(!is.na(population_density)) %>%
  group_by(gwn, gwc, year, group_id, group) %>%
  summarize(nightlight_mean = weighted.mean(nightlight, population_density, na.rm = TRUE))

head(group_means)

gini_data <- group_means %>%
  group_by(gwn, gwc, year) %>%
  summarize(nightlight_gini = Gini(nightlight_mean))

jsdivergence <- function(p, q) {
  m <- 0.5 * (p + q)
  return (0.5 * (sum(p * log(p / m)) + sum(q * log(q / m))))
}

get_distribution <- function(x, bins = 10) {
  n <- length(x)
  dist <- table(cut(x, breaks = seq(0, max(x), max(x)/bins)))
  as.vector(dist/sum(dist))
}

get_jsdivergence_mean <- function(group_id, nightlight) {
  data <- data_frame(group_id = group_id, weighted_nightlight = nightlight)
  
  groups <- data %>%
    group_by(group_id) %>%
    summarize()
  
  group_differences <- c()
  for (row in 1:nrow(groups)) {
    for (col in 1:nrow(groups)) {
      if (row != col) {
        group_1 <- data %>%
          filter(group_id == as.integer(groups[row, "group_id"]))
        
        group_2 <- data %>%
          filter(group_id == as.integer(groups[col, "group_id"]))
        
        x1 <- get_distribution(group_1$weighted_nightlight, 4)
        x2 <- get_distribution(group_2$weighted_nightlight, 4)
        result <- jsdivergence(x1, x2)
        if (!is.na(result)) {
          group_differences <- append(group_differences, result)
        }
      }
    }
  }
  mean(group_differences)
}

group_jsdivergence <- grids %>%
  filter(!is.na(population_density), population_density > 0, !is.na(nightlight), nightlight > 0) %>%
  mutate(weighted_nightlight = nightlight / population_density) %>%
  group_by(gwn, gwc, year) %>%
  summarize(jsdivergence_mean = get_jsdivergence_mean(group_id, weighted_nightlight))
  
head(group_jsdivergence)

merged_data <- summarized_data %>%
  left_join(group_jsdivergence, by = c("gwn", "gwc", "year"))

merged_data <- merged_data %>%
  arrange(gwc, year)

write.csv(merged_data, "~/Dropbox/wombat/outputData/merged_grids.csv", row.names = FALSE)

country_data <- merged_data %>%
  filter(GWC == "AFG")

ggplot(country_data, aes(Year)) +
  geom_line(aes(y = nightlight_gini)) +
  geom_line(aes(y = jsdivergence_mean)) +
  theme(axis.text = element_text(size=14),
        axis.title.x = element_blank(),
        axis.title.y = element_blank())

ged_monthly <- read.csv("~/Dropbox/wombat/outputData/monthly_counts/ged_monthly.csv", stringsAsFactors = FALSE)
icews_monthly <- read.csv("~/Dropbox/wombat/outputData/monthly_counts/icews_monthly.csv", stringsAsFactors = FALSE)

ged_monthly <- ged_monthly %>%
  filter(country == "Afghanistan", year == 2000)

icews_monthly <- icews_monthly %>%
  filter(Country == "Afghanistan", Year == 2000)

icews_monthly <- read.csv("~/Dropbox/wombat/outputData/monthly_counts/icews_monthly.csv", stringsAsFactors = FALSE)

ged_monthly <- ged_monthly %>%
  separate(month, c("year", "month"), sep = "-") %>%
  mutate(year = as.integer(year), month = as.integer(month))
  
merged_data <- icews_monthly %>%
  left_join(ged_monthly, by = c("Country" = "country", "Year" = "year", "Month" = "month")) %>%
  mutate(GWC = countrycode(Country, "country.name", "gwc"),
         GWN = countrycode(Country, "country.name", "gwn")) %>%
  left_join(gini_data, by = c("GWN" = "gwn", "GWC" = "gwc", "Year" = "year")) %>%
  left_join(group_jsdivergence, by = c("GWN" = "gwn", "GWC" = "gwc", "Year" = "year")) %>%
  filter(!is.na(GWC)) %>%
  select(Country, GWC, GWN, Year, Month, everything()) %>%
  arrange(Country, Year, Month)

write.csv(merged_data, "~/Dropbox/wombat/outputData/merged_data.csv", row.names = FALSE)

head(merged_data)
