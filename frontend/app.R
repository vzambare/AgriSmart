# ── app.R ─────────────────────────────────────────────────────────────────────
# Entry point for R Shiny app
# Run: shiny::runApp("frontend/")

library(shiny)

source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
