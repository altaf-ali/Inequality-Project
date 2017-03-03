# This is the server logic for a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

stop("DIE!!!")

library(shiny)
library(shinydashboard)

#source("dashboard.R")
#source("config.R")
#source("home_server.R")


shinyServer(function(input, output, session) {
  
  modules <- list(
    TabItem_Home
  )
  
  dashboard_server(modules)
})

