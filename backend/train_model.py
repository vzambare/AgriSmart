"""
train_model.py
Run this script ONCE to train and save the ML model before starting the API.
Usage: python train_model.py
"""
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score, mean_absolute_error
import pickle, os

DATA_PATH  = os.path.join("..", "data", "crop_data.csv")
MODEL_DIR  = os.path.join("model")
MODEL_PATH = os.path.join(MODEL_DIR, "rf_model.pkl")
META_PATH  = os.path.join(MODEL_DIR, "metadata.pkl")

os.makedirs(MODEL_DIR, exist_ok=True)

df = pd.read_csv(DATA_PATH)
print(f"📂 Dataset loaded: {len(df)} rows, {df['Crop'].nunique()} crops, {df['District'].nunique()} districts")

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

print("🤖 Training Random Forest model...")
model = RandomForestRegressor(n_estimators=200, max_depth=None, random_state=42, n_jobs=-1)
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
r2  = r2_score(y_test, y_pred)
mae = mean_absolute_error(y_test, y_pred)

print(f"\n✅ Model Performance:")
print(f"   R² Score : {r2:.4f}  ({round(r2*100,1)}%)")
print(f"   MAE      : {mae:.2f} kg/ha")

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

print(f"\n💾 Model saved → {MODEL_PATH}")
print(f"💾 Metadata saved → {META_PATH}")
print(f"\n🌾 Districts: {meta['districts']}")
print(f"🌱 Crops    : {meta['crops']}")
