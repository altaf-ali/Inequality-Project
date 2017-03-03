library(ggplot2)
library(DT)

home_ui <- function(id) {
  ns <- NS(id)
  
  tabItem(
    tabName = id,
    fluidRow(
      box(
        width = 6,
        status = "success",
        plotOutput(ns("groups"))
      ),
      box(
        width = 6,
        status = "success",
        plotOutput(ns("nightlight"))
      )
    ),
    fluidRow(
      box(
        width = 12,
        status = "success",
        DT::dataTableOutput(ns("groups"))
      )
    )
  )
}

home_sidebar <- function(id) {
  ns <- NS(id)

  selectInput(ns("country"), label = "Country", choices = NULL)
}