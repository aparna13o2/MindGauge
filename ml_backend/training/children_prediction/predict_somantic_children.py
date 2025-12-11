# predict_somantic_children.py
import joblib
import pandas as pd
import numpy as np
import math
import re

# --- 1. Model Loading (MUST BE DONE OUTSIDE THE FUNCTION) ---
# Update these paths if your model files are saved elsewhere
MODEL_PATH = '../../models/children_model/somatic_lgbm_model.pkl'
ENCODER_PATH = '../../models/children_model/somatic_label_encoder.pkl'

try:
    model = joblib.load(MODEL_PATH) 
    le = joblib.load(ENCODER_PATH) 
except FileNotFoundError:
    print("FATAL ERROR: Model files not found. Ensure you ran train_somatic.py successfully.")
    exit()

def sanitize_name(name):
    """Applies the exact same sanitization used during training."""
    name = str(name).strip().replace(' ', '_')
    name = name.replace('(', '').replace(')', '')
    name = name.replace(',', '_').replace('.', '_').replace('-', '_').replace(':', '_')
    name = re.sub(r'__+', '_', name).strip('_')
    return name

def predict_severity(symptom_scores):
    """
    Accepts 13 raw scores and internally calculates the required 15 features.
    """
    if len(symptom_scores) != 13:
        raise ValueError("Input must contain exactly 13 symptom scores.")
        
    # --- STEP 1: Calculate the 2 Missing Features ---
    
    total_raw_score = sum(symptom_scores)
    
    # Calculate Prorated Score (PS) 
    prorated_score = round((total_raw_score * 15) / 13)
    
    # --- STEP 2: Assemble the 15-Feature Input List and Names ---
    
    # This list MUST have exactly 15 elements (13 symptoms + TR + PS)
    input_list_15 = symptom_scores + [total_raw_score, prorated_score]
    
    # These names MUST EXACTLY MATCH the sanitized names used in your successful training run (15 total)
    feature_columns = [
        # 13 Symptom Names (Match the order of your input list!)
        sanitize_name('Stomach pain'), sanitize_name('Back pain'), sanitize_name('Pain in your arms, legs, or joints'),
        sanitize_name('Headaches'), sanitize_name('Chest pain'), sanitize_name('Dizziness'),
        sanitize_name('Fainting spells'), sanitize_name('Feeling your heart pound or race'), sanitize_name('Shortness of breath'),
        sanitize_name('Constipation, loose bowels, or diarrhea'), sanitize_name('Nausea, gas, or indigestion'),
        sanitize_name('Feeling tired or having low energy'), sanitize_name('Trouble sleeping'),
        
        # Calculated Scores
        sanitize_name('Total Raw Score (TR)'), 
        sanitize_name('Prorated Score (PS)')
    ]
    
    # Create a DataFrame with the 15-item list
    new_data = pd.DataFrame([input_list_15], columns=feature_columns)
    
    # --- STEP 3: Predict and Decode ---

    raw_prediction = model.predict(new_data)
    encoded_prediction = np.argmax(raw_prediction[0]) 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label

if __name__ == '__main__':
    # --- Example Test Data (Total Raw Score 7, Prorated Score 8) ---
    new_scores = [1, 1, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 0] 
    
    # The call to the function happens here, where 'model' is defined above.
    result = predict_severity(new_scores)
    print(f"Predicted severity for input {new_scores} is: {result}")