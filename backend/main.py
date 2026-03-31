from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, mean_absolute_error
import pickle
import os

app = FastAPI(title="AgriSmart API", description="Crop Yield Prediction API for Maharashtra")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Data & Model paths ──────────────────────────────────────────────────────
DATA_PATH  = os.path.join(os.path.dirname(__file__), "..", "data", "crop_data.csv")
MODEL_PATH = os.path.join(os.path.dirname(__file__), "model", "rf_model.pkl")
META_PATH  = os.path.join(os.path.dirname(__file__), "model", "metadata.pkl")

# ── Train and save model ────────────────────────────────────────────────────
def train_model():
    df = pd.read_csv(DATA_PATH)

    le_district = LabelEncoder()
    le_crop     = LabelEncoder()
    le_season   = LabelEncoder()

    df["District_enc"] = le_district.fit_transform(df["District"])
    df["Crop_enc"]     = le_crop.fit_transform(df["Crop"])
    df["Season_enc"]   = le_season.fit_transform(df["Season"])

    features = ["District_enc","Crop_enc","Season_enc",
                "Rainfall_mm","Temperature_C","Fertilizer_kg_ha","Pesticide_kg_ha"]
    X = df[features]
    y = df["Yield_kg_ha"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = RandomForestRegressor(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    r2  = r2_score(y_test, y_pred)
    mae = mean_absolute_error(y_test, y_pred)

    os.makedirs(os.path.dirname(MODEL_PATH), exist_ok=True)
    with open(MODEL_PATH, "wb") as f:
        pickle.dump(model, f)

    meta = {
        "le_district": le_district,
        "le_crop":     le_crop,
        "le_season":   le_season,
        "r2":          round(r2,  4),
        "mae":         round(mae, 2),
        "districts":   list(le_district.classes_),
        "crops":       list(le_crop.classes_),
        "seasons":     list(le_season.classes_),
    }
    with open(META_PATH, "wb") as f:
        pickle.dump(meta, f)

    print(f"✅ Model trained | R²={r2:.4f} | MAE={mae:.2f}")
    return model, meta

# ── Load or train ───────────────────────────────────────────────────────────
if os.path.exists(MODEL_PATH) and os.path.exists(META_PATH):
    with open(MODEL_PATH, "rb") as f:
        model = pickle.load(f)
    with open(META_PATH, "rb") as f:
        meta = pickle.load(f)
    print("✅ Model loaded from disk")
else:
    model, meta = train_model()

# ── Request schema ──────────────────────────────────────────────────────────
class PredictRequest(BaseModel):
    district:    str
    crop:        str
    season:      str
    rainfall:    float
    temperature: float
    fertilizer:  float
    pesticide:   float

# ── Endpoints ───────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {"message": "AgriSmart Crop Yield Prediction API", "status": "running"}

@app.get("/metadata")
def get_metadata():
    return {
        "districts": meta["districts"],
        "crops":     meta["crops"],
        "seasons":   meta["seasons"],
        "model_r2":  meta["r2"],
        "model_mae": meta["mae"],
    }

@app.post("/predict")
def predict(req: PredictRequest):
    try:
        dist_enc   = meta["le_district"].transform([req.district])[0]
        crop_enc   = meta["le_crop"].transform([req.crop])[0]
        season_enc = meta["le_season"].transform([req.season])[0]
    except ValueError as e:
        raise HTTPException(status_code=400, detail=f"Invalid input: {e}")

    X = np.array([[dist_enc, crop_enc, season_enc,
                   req.rainfall, req.temperature,
                   req.fertilizer, req.pesticide]])

    pred = model.predict(X)[0]

    # Simple confidence band (±8 %)
    low  = round(pred * 0.92, 2)
    high = round(pred * 1.08, 2)

    return {
        "predicted_yield": round(pred, 2),
        "unit":            "kg/hectare",
        "confidence_low":  low,
        "confidence_high": high,
        "district":        req.district,
        "crop":            req.crop,
        "season":          req.season,
    }

@app.get("/analytics/top-crops")
def top_crops():
    df = pd.read_csv(DATA_PATH)
    top = (df.groupby("Crop")["Yield_kg_ha"]
             .mean()
             .reset_index()
             .sort_values("Yield_kg_ha", ascending=False)
             .head(10))
    return top.to_dict(orient="records")

@app.get("/analytics/district-yields")
def district_yields():
    df = pd.read_csv(DATA_PATH)
    dist = (df.groupby("District")["Yield_kg_ha"]
              .mean()
              .reset_index()
              .sort_values("Yield_kg_ha", ascending=False))
    return dist.to_dict(orient="records")

@app.get("/analytics/season-comparison")
def season_comparison():
    df = pd.read_csv(DATA_PATH)
    seas = (df.groupby(["Season","Crop"])["Yield_kg_ha"]
              .mean()
              .reset_index())
    return seas.to_dict(orient="records")

@app.get("/analytics/rainfall-impact")
def rainfall_impact():
    df = pd.read_csv(DATA_PATH)
    return df[["Rainfall_mm","Yield_kg_ha","Crop"]].to_dict(orient="records")

@app.post("/retrain")
def retrain():
    global model, meta
    model, meta = train_model()
    return {"message": "Model retrained successfully", "r2": meta["r2"], "mae": meta["mae"]}
