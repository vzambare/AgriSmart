# ── server.R ──────────────────────────────────────────────────────────────────
library(shiny)
library(shinydashboard)
library(httr)
library(jsonlite)
library(dplyr)
library(ggplot2)
library(plotly)
library(leaflet)
library(DT)

API_BASE <- "http://localhost:8000"

# ── Helper: call API ──────────────────────────────────────────────────────────
api_get <- function(endpoint) {
  tryCatch({
    res <- GET(paste0(API_BASE, endpoint))
    if (status_code(res) == 200) fromJSON(content(res, "text", encoding = "UTF-8"))
    else NULL
  }, error = function(e) NULL)
}

# ── Load local CSV as fallback ────────────────────────────────────────────────
local_data <- read.csv(file.path("..", "data", "crop_data.csv"), stringsAsFactors = FALSE)

# ── Maharashtra district coordinates ─────────────────────────────────────────
district_coords <- data.frame(
  District  = c("Pune","Nashik","Nagpur","Aurangabad","Kolhapur",
                "Solapur","Amravati","Latur","Satara","Sangli",
                "Jalgaon","Ahmednagar","Osmanabad","Nanded","Wardha",
                "Yavatmal","Buldana"),
  lat = c(18.52,20.00,21.15,19.88,16.70,17.68,20.93,18.40,17.68,16.86,
          21.00,19.09,18.18,19.15,20.75,20.40,20.53),
  lng = c(73.86,73.79,79.09,75.34,74.23,75.91,77.75,76.56,74.00,74.60,
          75.56,74.74,76.04,77.32,78.60,78.13,76.18),
  stringsAsFactors = FALSE
)

server <- function(input, output, session) {

  # ── Fetch metadata from API ─────────────────────────────────────────────────
  meta <- reactive({
    api_get("/metadata")
  })

  # ── API status indicator ────────────────────────────────────────────────────
  output$api_status <- renderUI({
    m <- meta()
    if (!is.null(m)) {
      tags$span(style = "color:#2ecc71;", "● Connected")
    } else {
      tags$span(style = "color:#e74c3c;", "● Offline (using local data)")
    }
  })

  # ── Populate dropdowns ──────────────────────────────────────────────────────
  observe({
    m <- meta()
    districts <- if (!is.null(m)) m$districts else sort(unique(local_data$District))
    crops     <- if (!is.null(m)) m$crops     else sort(unique(local_data$Crop))

    updateSelectInput(session, "pred_district", choices = districts, selected = districts[1])
    updateSelectInput(session, "pred_crop",     choices = crops,     selected = crops[1])
    updateSelectInput(session, "rec_district",  choices = districts, selected = districts[1])

    updateSelectInput(session, "exp_crop",
                      choices = c("All", sort(unique(local_data$Crop))))
    updateSelectInput(session, "exp_district",
                      choices = c("All", sort(unique(local_data$District))))
  })

  # ── Value boxes ─────────────────────────────────────────────────────────────
  output$vbox_districts <- renderValueBox({
    valueBox(length(unique(local_data$District)), "Districts Covered",
             icon = icon("map-marker-alt"), color = "green")
  })
  output$vbox_crops <- renderValueBox({
    valueBox(length(unique(local_data$Crop)), "Crop Types",
             icon = icon("leaf"), color = "olive")
  })
  output$vbox_avg_yield <- renderValueBox({
    valueBox(paste0(round(mean(local_data$Yield_kg_ha)), " kg/ha"),
             "Avg Yield", icon = icon("chart-line"), color = "teal")
  })
  output$vbox_model_r2 <- renderValueBox({
    m  <- meta()
    r2 <- if (!is.null(m)) paste0(round(m$model_r2 * 100, 1), "%") else "N/A"
    valueBox(r2, "Model Accuracy (R²)", icon = icon("brain"), color = "blue")
  })

  # ── District Map ────────────────────────────────────────────────────────────
  output$district_map <- renderLeaflet({
    avg_by_dist <- local_data %>%
      group_by(District) %>%
      summarise(avg_yield = round(mean(Yield_kg_ha), 0), .groups = "drop")

    map_data <- left_join(district_coords, avg_by_dist, by = "District")

    pal <- colorNumeric(palette = c("#fff7bc","#78c679","#006837"),
                        domain = map_data$avg_yield, na.color = "#ccc")

    leaflet(map_data) %>%
      addTiles() %>%
      setView(lng = 76.5, lat = 19.5, zoom = 6) %>%
      addCircleMarkers(
        lng = ~lng, lat = ~lat,
        radius = ~scales::rescale(avg_yield, to = c(8, 22)),
        color  = ~pal(avg_yield),
        fillColor  = ~pal(avg_yield),
        fillOpacity = 0.85, weight = 1.5,
        popup = ~paste0("<b>", District, "</b><br>Avg Yield: ",
                        format(avg_yield, big.mark = ","), " kg/ha")
      ) %>%
      addLegend("bottomright", pal = pal, values = ~avg_yield,
                title = "Avg Yield (kg/ha)", opacity = 0.9)
  })

  # ── Top crops chart ─────────────────────────────────────────────────────────
  output$top_crops_chart <- renderPlotly({
    top <- local_data %>%
      group_by(Crop) %>%
      summarise(avg_yield = mean(Yield_kg_ha), .groups = "drop") %>%
      arrange(desc(avg_yield)) %>% head(5)

    plot_ly(top, x = ~avg_yield, y = ~reorder(Crop, avg_yield),
            type = "bar", orientation = "h",
            marker = list(color = c("#1a9641","#a6d96a","#ffffbf","#fdae61","#d7191c"))) %>%
      layout(xaxis = list(title = "Avg Yield (kg/ha)"),
             yaxis = list(title = ""),
             margin = list(l = 80))
  })

  # ── PREDICTION ──────────────────────────────────────────────────────────────
  prediction <- eventReactive(input$predict_btn, {
    req(input$pred_district, input$pred_crop)
    body_data <- list(
      district    = input$pred_district,
      crop        = input$pred_crop,
      season      = input$pred_season,
      rainfall    = input$pred_rainfall,
      temperature = input$pred_temp,
      fertilizer  = input$pred_fertilizer,
      pesticide   = input$pred_pesticide
    )
    tryCatch({
      res <- POST(paste0(API_BASE, "/predict"),
                  body = body_data, encode = "json",
                  content_type_json())
      if (status_code(res) == 200)
        fromJSON(content(res, "text", encoding = "UTF-8"))
      else NULL
    }, error = function(e) NULL)
  })

  output$prediction_result <- renderUI({
    pred <- prediction()
    if (is.null(pred)) {
      return(tags$div(class = "alert alert-warning",
                      "⚠️ Could not connect to prediction API. Make sure Python backend is running."))
    }
    yld <- pred$predicted_yield
    grade <- if (yld > 30000) "🌟 Excellent" else if (yld > 5000) "✅ Good" else "⚠️ Average"

    tags$div(
      tags$div(class = "prediction-box",
        tags$h2(style = "color:#27ae60; text-align:center; font-size:2.5em;",
                paste0(format(round(yld), big.mark = ","), " kg/ha")),
        tags$p(style = "text-align:center; font-size:1.1em;",
               paste("Estimated yield for", pred$crop, "in", pred$district)),
        tags$p(style = "text-align:center; font-size:1.3em;", grade),
        tags$hr(),
        fluidRow(
          column(4, tags$div(class = "stat-box",
            tags$b("Low Estimate"), tags$br(),
            format(round(pred$confidence_low), big.mark = ","), " kg/ha")),
          column(4, tags$div(class = "stat-box",
            tags$b("Predicted"), tags$br(),
            format(round(yld), big.mark = ","), " kg/ha")),
          column(4, tags$div(class = "stat-box",
            tags$b("High Estimate"), tags$br(),
            format(round(pred$confidence_high), big.mark = ","), " kg/ha"))
        )
      )
    )
  })

  output$confidence_plot <- renderPlotly({
    pred <- prediction()
    req(!is.null(pred))
    df <- data.frame(
      label = c("Low", "Predicted", "High"),
      value = c(pred$confidence_low, pred$predicted_yield, pred$confidence_high)
    )
    plot_ly(df, x = ~label, y = ~value, type = "bar",
            marker = list(color = c("#e74c3c","#27ae60","#3498db"))) %>%
      layout(title  = "Confidence Range",
             yaxis  = list(title = "Yield (kg/ha)"),
             xaxis  = list(title = ""))
  })

  output$similar_farms_chart <- renderPlotly({
    pred <- prediction()
    req(!is.null(pred))
    sim <- local_data %>%
      filter(Crop == input$pred_crop, Season == input$pred_season) %>%
      group_by(District) %>%
      summarise(avg = mean(Yield_kg_ha), .groups = "drop") %>%
      arrange(desc(avg))

    plot_ly(sim, x = ~District, y = ~avg, type = "bar",
            marker = list(color = "#27ae60")) %>%
      layout(title  = paste("Historical Avg Yield for", input$pred_crop, "by District"),
             xaxis  = list(title = "", tickangle = -30),
             yaxis  = list(title = "Yield (kg/ha)"))
  })

  # ── DATA EXPLORER ───────────────────────────────────────────────────────────
  filtered_data <- reactive({
    df <- local_data
    if (input$exp_season   != "All") df <- df %>% filter(Season   == input$exp_season)
    if (input$exp_crop     != "All") df <- df %>% filter(Crop     == input$exp_crop)
    if (input$exp_district != "All") df <- df %>% filter(District == input$exp_district)
    df
  })

  output$yield_by_crop <- renderPlotly({
    df <- filtered_data() %>%
      group_by(Crop) %>%
      summarise(avg = mean(Yield_kg_ha), .groups = "drop") %>%
      arrange(desc(avg))
    plot_ly(df, x = ~Crop, y = ~avg, type = "bar",
            marker = list(color = "#27ae60")) %>%
      layout(xaxis = list(tickangle = -30), yaxis = list(title = "Avg Yield (kg/ha)"))
  })

  output$yield_by_district <- renderPlotly({
    df <- filtered_data() %>%
      group_by(District) %>%
      summarise(avg = mean(Yield_kg_ha), .groups = "drop") %>%
      arrange(desc(avg))
    plot_ly(df, x = ~District, y = ~avg, type = "bar",
            marker = list(color = "#2980b9")) %>%
      layout(xaxis = list(tickangle = -30), yaxis = list(title = "Avg Yield (kg/ha)"))
  })

  output$season_comparison <- renderPlotly({
    df <- local_data %>%
      group_by(Season, Crop) %>%
      summarise(avg = mean(Yield_kg_ha), .groups = "drop")
    plot_ly(df, x = ~Crop, y = ~avg, color = ~Season, type = "bar",
            colors = c("#27ae60","#e67e22","#8e44ad")) %>%
      layout(barmode = "group",
             xaxis = list(tickangle = -30),
             yaxis = list(title = "Avg Yield (kg/ha)"))
  })

  # ── WEATHER IMPACT ──────────────────────────────────────────────────────────
  output$rainfall_yield_scatter <- renderPlotly({
    plot_ly(local_data, x = ~Rainfall_mm, y = ~Yield_kg_ha,
            color = ~Crop, type = "scatter", mode = "markers",
            marker = list(size = 9, opacity = 0.75)) %>%
      layout(xaxis = list(title = "Rainfall (mm)"),
             yaxis = list(title = "Yield (kg/ha)"))
  })

  output$temp_yield_scatter <- renderPlotly({
    plot_ly(local_data, x = ~Temperature_C, y = ~Yield_kg_ha,
            color = ~Season, type = "scatter", mode = "markers",
            marker = list(size = 9, opacity = 0.75)) %>%
      layout(xaxis = list(title = "Temperature (°C)"),
             yaxis = list(title = "Yield (kg/ha)"))
  })

  output$fertilizer_yield_chart <- renderPlotly({
    plot_ly(local_data, x = ~Fertilizer_kg_ha, y = ~Yield_kg_ha,
            color = ~Crop, type = "scatter", mode = "markers",
            marker = list(size = 9, opacity = 0.75)) %>%
      layout(xaxis = list(title = "Fertilizer (kg/ha)"),
             yaxis = list(title = "Yield (kg/ha)"))
  })

  # ── RECOMMENDATIONS ─────────────────────────────────────────────────────────
  recommendations <- eventReactive(input$recommend_btn, {
    df <- local_data %>%
      filter(Season   == input$rec_season,
             District == input$rec_district) %>%
      group_by(Crop) %>%
      summarise(avg_yield = mean(Yield_kg_ha), .groups = "drop") %>%
      arrange(desc(avg_yield))
    df
  })

  output$recommendation_output <- renderUI({
    rec <- recommendations()
    req(nrow(rec) > 0)
    best <- rec$Crop[1]
    tags$div(
      tags$div(class = "alert alert-success",
        tags$h4("🏆 Best Crop: ", tags$b(best)),
        tags$p(paste("For", input$rec_district, "in", input$rec_season,
                     "season, based on historical yield data."))
      )
    )
  })

  output$rec_chart <- renderPlotly({
    rec <- recommendations()
    req(nrow(rec) > 0)
    plot_ly(rec, x = ~reorder(Crop, avg_yield), y = ~avg_yield,
            type = "bar", orientation = "v",
            marker = list(color = "#f39c12")) %>%
      layout(xaxis = list(title = "Crop"),
             yaxis = list(title = "Avg Yield (kg/ha)"),
             title  = paste("Crop Yields —", input$rec_district, input$rec_season))
  })

  # ── FULL DATASET TABLE ──────────────────────────────────────────────────────
  output$full_table <- renderDT({
    datatable(local_data,
              options  = list(pageLength = 15, scrollX = TRUE),
              rownames = FALSE,
              class    = "table-striped table-hover")
  })
}
