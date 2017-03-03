library(RColorBrewer)
library(cshapes)
library(rgeos)

library(countrycode)
library(ggplot2)
library(broom)
library(dplyr)

DATASET_ROOT <- "~/Datasets"

GEO_EPR <- "geoEPR/2014"
OUTPUT_FOLDER <- "~/Projects/inequality/visualizations/maps"

create_map <- function(gwc, geoepr, cshapes) {
  par(mar=rep(1,4))
  
  gwn <- countrycode(gwc, "gwc", "gwn")
  country_name <- countrycode(gwc, "gwc", "country.name")
  
  country_cshape <- subset(cshapes, GWCODE == gwn)
  country_geoepr <- subset(geoepr, gwid == gwn)    
 
  country <- tidy(country_cshape)
  groups <- tidy(country_geoepr)
  
  if (nrow(groups) <= 0) {
    message("  group data not available")
    return()
  }
  
  qual_palette <- brewer.pal.info[brewer.pal.info$category == 'qual',]
  color_vector <- unlist(mapply(brewer.pal, qual_palette$maxcolors, rownames(qual_palette)))

  set.seed(33333)
  color_palette <- sample(color_vector, length(country_geoepr))

  group_centers <- gCentroid(country_geoepr, byid=TRUE)
  center_coords <- as.data.frame(coordinates(group_centers))

  country_plot <- ggplot(groups) + 
    ggtitle(country_name) +
    geom_polygon(aes(x=long, y=lat, group=group, fill=id), alpha = 0.5, colour="darkgrey") +
    scale_fill_manual(values = color_palette) +
    #geom_polygon(aes(x=long, y=lat), data=country, colour="dimgrey", fill=NA) +
    geom_text(aes(x, y, label=country_geoepr$group, fill = NA), center_coords) +
    theme(panel.grid = element_blank(),
          legend.position = "none",
          panel.background = element_blank(),
          axis.text = element_blank(), 
          axis.ticks = element_blank(),
          axis.title = element_blank())

  for (piece_id in unique(country$piece)) {
    country_piece <- country %>%
        filter(piece == piece_id)
    
    country_plot <- country_plot + geom_polygon(aes(x=long, y=lat), data=country_piece, colour="dimgrey", fill=NA)
  }
  
  return(country_plot)
}

save_map <- function(gwc, geoepr, cshapes, outdir) {
  country_plot <- create_map(gwc, geoepr, cshapes)
  ggsave(file.path(outdir, paste0(gwc, ".png")), plot = country_plot)
}
  
geoepr <- rgdal::readOGR(path.expand(file.path(DATASET_ROOT, GEO_EPR)), "GeoEPR-2014")
cshapes_2012 <- cshapes::cshp(date = as.Date('2012-06-30'))

countries <- sort(countrycode(cshapes_2012$GWCODE, "gwn", "gwc"))

for (gwc in countries) {
  message("Creating map: ", gwc)
  save_map(gwc, geoepr, cshapes_2012, OUTPUT_FOLDER)
}

#create_map("IRQ", geoepr, cshapes_2012)
