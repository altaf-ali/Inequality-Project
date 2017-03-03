sapply(list.files(pattern = "_server.R"), source)
sapply(list.files(pattern = "_ui.R"), source)

# -----------------------------------------------------------------------------
dashboard_name <- function(s, prefix = NULL) {
  paste(c(prefix, gsub("\\s|[[:punct:]]", "_", tolower(s))), collapse = "_")
}

# -----------------------------------------------------------------------------
dashboard_tab <- function(s) {
  dashboard_name(s, "tab")
}

# -----------------------------------------------------------------------------
dashboard_menuItem <- function(item) {
  menuItem(item$name, tabName = item$id, icon = item$icon)
}

# -----------------------------------------------------------------------------
dashboard_conditionalMenuItem <- function(item) {
  conditionalPanel(
    condition = sprintf("input.sidebar_menu == '%s'", item$id),
    hr(),
    do.call(paste0(item$id, "_sidebar"), args = list(item$id))
  )
}

# -----------------------------------------------------------------------------
dashboard_tabItem <- function(item) {
  do.call(paste0(item$id, "_ui"), args = list(item$id))
}

# -----------------------------------------------------------------------------
dashboard_server <- function(modules) {
  sapply(modules, function(item) { 
    callModule(eval(as.symbol(paste0(item$id, "_server"))), id = item$id)
  })
}

