# This is the user-interface definition of a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(shinydashboard)

source("dashboard.R")
source("config.R")
source("home_ui.R")

dashboard_header <- dashboardHeader(title = APP_TITLE)

dashboard_sidebar <- dashboardSidebar(
  sidebarMenu(
    id = "sidebar_menu",
    dashboard_menuItem(TabItem_Home),
    dashboard_conditionalMenuItem(TabItem_Home)
  )
)

dashboard_body <- dashboardBody(
  tabItems(
    dashboard_tabItem(TabItem_Home)
  )
)

dashboardPage(dashboard_header, dashboard_sidebar, dashboard_body)
