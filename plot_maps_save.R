library(RColorBrewer)
library(GISTools)

library(cshapes)
library(countrycode)
library(nightlight)
library(raster)
library(dplyr)
library(broom)
library(ggplot2)

DATASET_ROOT <- "~/Datasets"
NOAA <- "noaa"
GPW <- "gpw/gldens00/glds00ag/w001001.adf"
GEO_EPR <- "geoEPR/2014"
NATURAL_EARTH <- "natural_earth"

OUTPUT_FOLDER <- "~/Projects/inequality/maps"

DEFAULT_COUNTRY <- "FRA"

cshapes_2012 <- cshapes::cshp(date = as.Date('2012-06-30'))

countries <- sort(countrycode(cshapes_2012$GWCODE, "gwn", "gwc"))


create_map <- function(gwc) {
  
}

for (gwc in countries) {
  country_map <- create_map(gwc)
}

input <- list(
  country = DEFAULT_COUNTRY,
  gwn = countrycode(DEFAULT_COUNTRY, "gwc", "gwn")
)

dataset_path <- function(dataset) {
  path.expand(file.path(DATASET_ROOT, dataset))
}

# masking function
masked_obj <- function(source_data, spatial_mask) {
  cropped_obj <- raster::crop(source_data, raster::extent(spatial_mask))
  raster::mask(cropped_obj, mask = spatial_mask) 
}

# load all datasets
nightlight <- nightlight_load(dataset_path(NOAA))
#nightlight <- nightlight[1:12]
countries <- rgdal::readOGR(dataset_path(NATURAL_EARTH), "ne_50m_admin_0_countries")  
gpw <- raster::raster(dataset_path(GPW))
geoepr <- rgdal::readOGR(dataset_path(GEO_EPR), "GeoEPR-2014")

geoepr_subset <- function() {
  country_code_cown <- countrycode(input$country, "iso3c", "cown")
  subset(geoepr, gwid == country_code_cown)    
}

groups <- geoepr_subset()
country <- subset(cshapes_2012, GWCODE == input$gwn)

country_name <- countrycode(input$gwn, "gwn", "country.name")
dev.off()
#par(mar=rep(1,4))
plot(groups, 
     border="lightgrey", 
     col = add.alpha(brewer.pal(12, "Set3"), 0.5), 
     main = country_name)
plot(country, border="darkgrey", lwd=2, add=TRUE)

group_centers <- gCentroid(groups, byid=TRUE)
center_coords <- as.data.frame(coordinates(group_centers))
text(center_coords$x, center_coords$y, as.character(groups$group), cex = 0.8)

groups_df <- tidy(groups)
country_df <- tidy(country)

qual_palette <- brewer.pal.info[brewer.pal.info$category == 'qual',]
color_vector <- unlist(mapply(brewer.pal, qual_palette$maxcolors, rownames(qual_palette)))

set.seed(22222)
ggplot(groups_df) + 
  ggtitle(country_name) +
  geom_polygon(aes(x=long, y=lat, group=group, fill=id), alpha = 0.5, colour="darkgrey") +
  scale_fill_manual(values = sample(color_vector, length(groups))) +
  geom_polygon(aes(x=long, y=lat), data=country_df, colour="dimgrey", fill=NA) +
  geom_text(aes(x, y, label=groups$group, fill = NA), center_coords) +
  theme(panel.grid = element_blank(),
        legend.position = "none",
        panel.background = element_blank(),
        axis.text = element_blank(), 
        axis.ticks = element_blank(),
        axis.title = element_blank())

