# ── ui.R ─────────────────────────────────────────────────────────────────────
library(shiny)
library(shinydashboard)
library(shinyWidgets)
library(plotly)
library(leaflet)
library(DT)

ui <- dashboardPage(
  skin = "green",

  # ── Header ────────────────────────────────────────────────────────────────
  dashboardHeader(
    title = tags$span(
      tags$img(src = "logo.png", height = "30px", style = "margin-right:8px;"),
      "AgriSmart Maharashtra"
    ),
    titleWidth = 280
  ),

  # ── Sidebar ───────────────────────────────────────────────────────────────
  dashboardSidebar(
    width = 280,
    sidebarMenu(
      id = "sidebar",
      menuItem("🏠 Dashboard",       tabName = "dashboard",   icon = icon("tachometer-alt")),
      menuItem("🔮 Yield Predictor", tabName = "predictor",   icon = icon("seedling")),
      menuItem("📊 Data Explorer",   tabName = "explorer",    icon = icon("chart-bar")),
      menuItem("🌦️ Weather Impact",  tabName = "weather",     icon = icon("cloud-rain")),
      menuItem("💡 Recommendations", tabName = "recommend",   icon = icon("lightbulb")),
      menuItem("📋 Dataset",         tabName = "dataset",     icon = icon("table"))
    ),
    tags$hr(),
    tags$div(
      style = "padding:15px; color:#ccc; font-size:12px;",
      tags$b("API Status:"),
      tags$br(),
      uiOutput("api_status")
    )
  ),

  # ── Body ──────────────────────────────────────────────────────────────────
  dashboardBody(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
    ),

    tabItems(

      # ── 1. DASHBOARD ──────────────────────────────────────────────────────
      tabItem(tabName = "dashboard",
        fluidRow(
          valueBoxOutput("vbox_districts", width = 3),
          valueBoxOutput("vbox_crops",     width = 3),
          valueBoxOutput("vbox_avg_yield", width = 3),
          valueBoxOutput("vbox_model_r2",  width = 3)
        ),
        fluidRow(
          box(title = "📍 District-wise Average Yield Map", status = "success",
              solidHeader = TRUE, width = 8, height = 520,
              leafletOutput("district_map", height = 460)),
          box(title = "🏆 Top 5 Crops by Yield", status = "success",
              solidHeader = TRUE, width = 4, height = 520,
              plotlyOutput("top_crops_chart", height = 460))
        )
      ),

      # ── 2. YIELD PREDICTOR ────────────────────────────────────────────────
      tabItem(tabName = "predictor",
        fluidRow(
          box(title = "🌾 Enter Farm Parameters", status = "success",
              solidHeader = TRUE, width = 4,
              selectInput("pred_district", "📍 District",
                          choices = NULL, selected = NULL),
              selectInput("pred_crop", "🌱 Crop Type",
                          choices = NULL, selected = NULL),
              selectInput("pred_season", "📅 Season",
                          choices = c("Kharif", "Rabi", "Zaid")),
              sliderInput("pred_rainfall", "🌧️ Rainfall (mm)",
                          min = 200, max = 1500, value = 700, step = 10),
              sliderInput("pred_temp", "🌡️ Temperature (°C)",
                          min = 15, max = 40, value = 28, step = 0.5),
              sliderInput("pred_fertilizer", "🧪 Fertilizer (kg/ha)",
                          min = 50, max = 250, value = 120, step = 5),
              sliderInput("pred_pesticide", "🐛 Pesticide (kg/ha)",
                          min = 0.5, max = 5.0, value = 2.0, step = 0.1),
              actionBttn("predict_btn", "🔮 Predict Yield",
                         style = "fill", color = "success", size = "md",
                         block = TRUE)
          ),
          box(title = "📈 Prediction Result", status = "success",
              solidHeader = TRUE, width = 8,
              uiOutput("prediction_result"),
              tags$hr(),
              plotlyOutput("confidence_plot", height = 300),
              tags$hr(),
              plotlyOutput("similar_farms_chart", height = 280)
          )
        )
      ),

      # ── 3. DATA EXPLORER ──────────────────────────────────────────────────
      tabItem(tabName = "explorer",
        fluidRow(
          box(title = "Filters", status = "success", solidHeader = TRUE, width = 12,
              column(4, selectInput("exp_season", "Season",
                                   choices = c("All","Kharif","Rabi","Zaid"),
                                   selected = "All")),
              column(4, selectInput("exp_crop", "Crop",
                                   choices = c("All"), selected = "All")),
              column(4, selectInput("exp_district", "District",
                                   choices = c("All"), selected = "All"))
          )
        ),
        fluidRow(
          box(title = "📊 Yield by Crop", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("yield_by_crop", height = 360)),
          box(title = "📍 Yield by District", status = "success",
              solidHeader = TRUE, width = 6,
              plotlyOutput("yield_by_district", height = 360))
        ),
        fluidRow(
          box(title = "📅 Kharif vs Rabi Comparison", status = "success",
              solidHeader = TRUE, width = 12,
              plotlyOutput("season_comparison", height = 360))
        )
      ),

      # ── 4. WEATHER IMPACT ─────────────────────────────────────────────────
      tabItem(tabName = "weather",
        fluidRow(
          box(title = "🌧️ Rainfall vs Yield", status = "info",
              solidHeader = TRUE, width = 6,
              plotlyOutput("rainfall_yield_scatter", height = 400)),
          box(title = "🌡️ Temperature vs Yield", status = "warning",
              solidHeader = TRUE, width = 6,
              plotlyOutput("temp_yield_scatter", height = 400))
        ),
        fluidRow(
          box(title = "🧪 Fertilizer Impact on Yield", status = "success",
              solidHeader = TRUE, width = 12,
              plotlyOutput("fertilizer_yield_chart", height = 360))
        )
      ),

      # ── 5. RECOMMENDATIONS ────────────────────────────────────────────────
      tabItem(tabName = "recommend",
        fluidRow(
          box(title = "💡 Get Crop Recommendation", status = "success",
              solidHeader = TRUE, width = 4,
              selectInput("rec_district", "📍 Your District", choices = NULL),
              selectInput("rec_season",   "📅 Current Season",
                          choices = c("Kharif","Rabi","Zaid")),
              sliderInput("rec_rainfall", "Expected Rainfall (mm)",
                          min = 200, max = 1500, value = 700, step = 10),
              actionBttn("recommend_btn", "💡 Get Recommendation",
                         style = "fill", color = "warning", size = "md",
                         block = TRUE)
          ),
          box(title = "🌱 Best Crops for Your Conditions", status = "success",
              solidHeader = TRUE, width = 8,
              uiOutput("recommendation_output"),
              plotlyOutput("rec_chart", height = 320)
          )
        )
      ),

      # ── 6. DATASET ────────────────────────────────────────────────────────
      tabItem(tabName = "dataset",
        fluidRow(
          box(title = "📋 Complete Crop Dataset — Maharashtra", status = "success",
              solidHeader = TRUE, width = 12,
              DTOutput("full_table"))
        )
      )

    ) # end tabItems
  )   # end dashboardBody
)
