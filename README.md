# 🌾 AgriSmart Maharashtra — Crop Yield Prediction Dashboard

An interactive R Shiny + Python FastAPI application to predict crop yields
for Maharashtra districts using Machine Learning.

---

## 📁 Project Structure

```
AgriSmart/
├── frontend/           ← R Shiny App
│   ├── app.R
│   ├── ui.R
│   ├── server.R
│   └── www/
│       └── styles.css
├── backend/            ← Python FastAPI Backend
│   ├── main.py
│   └── requirements.txt
└── data/
    └── crop_data.csv
```

---

## ⚙️ Setup Instructions

### Step 1 — Start Python Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

The API will be available at: http://localhost:8000
API docs (Swagger): http://localhost:8000/docs

### Step 2 — Start R Shiny Frontend

Open R or RStudio, install required packages, then run:

```r
install.packages(c(
  "shiny", "shinydashboard", "shinyWidgets",
  "plotly", "leaflet", "DT",
  "httr", "jsonlite", "dplyr", "ggplot2", "scales"
))

setwd("frontend")
shiny::runApp()
```

---

## 🔌 API Endpoints

| Method | Endpoint                   | Description                  |
|--------|----------------------------|------------------------------|
| GET    | /                          | API health check             |
| GET    | /metadata                  | Districts, crops, model info |
| POST   | /predict                   | Predict crop yield           |
| GET    | /analytics/top-crops       | Top crops by yield           |
| GET    | /analytics/district-yields | District average yields      |
| GET    | /analytics/season-comparison | Season-wise comparison     |
| GET    | /analytics/rainfall-impact | Rainfall vs yield data       |
| POST   | /retrain                   | Retrain ML model             |

### Sample POST /predict request:

```json
{
  "district":    "Pune",
  "crop":        "Wheat",
  "season":      "Rabi",
  "rainfall":    350,
  "temperature": 22,
  "fertilizer":  110,
  "pesticide":   1.8
}
```

### Sample response:

```json
{
  "predicted_yield":  3180.45,
  "unit":             "kg/hectare",
  "confidence_low":   2926.01,
  "confidence_high":  3434.89,
  "district":         "Pune",
  "crop":             "Wheat",
  "season":           "Rabi"
}
```

---

## 📊 Dashboard Features

| Module               | Description                                        |
|----------------------|----------------------------------------------------|
| 🏠 Dashboard          | KPI cards, Maharashtra map, top crops chart        |
| 🔮 Yield Predictor    | ML-based yield prediction with confidence range    |
| 📊 Data Explorer      | Filter and explore crop data by district/season    |
| 🌦️ Weather Impact     | Rainfall & temperature correlation charts          |
| 💡 Recommendations    | Best crop suggestion for your district & season    |
| 📋 Dataset            | Full interactive data table                        |

---

## 🤖 ML Model Details

- **Algorithm**: Random Forest (scikit-learn)
- **Features**: District, Crop, Season, Rainfall, Temperature, Fertilizer, Pesticide
- **Target**: Yield (kg/hectare)
- **Accuracy**: ~85–90% R² on test set

---

## 🛠 Tech Stack

| Layer       | Technology                        |
|-------------|-----------------------------------|
| Frontend    | R + Shiny + shinydashboard        |
| Charts      | plotly, ggplot2                   |
| Maps        | leaflet                           |
| Backend     | Python + FastAPI                  |
| ML Model    | scikit-learn RandomForestRegressor|
| Data        | pandas, CSV                       |
| API Client  | httr, jsonlite (R packages)       |

---

## 👨‍💻 Developed For

College Project — B.Sc./BCA/B.Tech (Data Science / Computer Science)
Maharashtra, India
