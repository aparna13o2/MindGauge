# predict_depression_children.py
import joblib
import pandas as pd
import numpy as np
import math
import re

# --- 1. Model Loading ---
MODEL_PATH = '../../models/children_model/depression_lgbm_model.pkl'
ENCODER_PATH = '../../models/children_model/depression_label_encoder.pkl'

try:
    model = joblib.load(MODEL_PATH) 
    le = joblib.load(ENCODER_PATH) 
except FileNotFoundError:
    print("FATAL ERROR: Depression model files not found. Ensure you ran train_depression.py successfully.")
    exit()

# PROMIS Depression has NO reverse scored items.
DEPRESSION_REVERSE_COLS = [] 

def sanitize_name(name):
    """Applies the exact same sanitization used during training."""
    name = str(name).strip().replace(' ', '_').replace('(', '').replace(')', '')
    name = name.replace(',', '_').replace('.', '_').replace('-', '_').replace(':', '_')
    name = re.sub(r'__+', '_', name).strip('_')
    return name

def predict_severity(raw_symptom_scores):
    """
    Accepts 14 raw PROMIS scores and internally calculates the required 16 features.
    """
    if len(raw_symptom_scores) != 14:
        raise ValueError("Input must contain exactly 14 symptom scores for the Depression scale.")
        
    # No reverse scoring is needed, so processed scores = raw scores
    processed_scores = list(raw_symptom_scores)
            
    # --- Step 1: Calculate the 2 Missing Features (TR and PS) ---
    
    total_raw_score = sum(processed_scores)
    
    # Prorated Score (PS): Since all 14 items are present, PS = TR.
    prorated_score = total_raw_score
    
    # --- Step 2: Assemble the 16-Feature Input List and Names ---
    
    # 14 processed symptoms + TR + PS = 16 features
    input_list_16 = processed_scores + [total_raw_score, prorated_score]
    
    # Names of the 14 symptom columns (You must check your CSV for exact Q-names)
    symptom_names = [f'Q{i}' for i in range(1, 15)]
    
    # Assemble the 16 feature names (must be sanitized)
    feature_columns = [
        sanitize_name(name) for name in symptom_names
    ] + [
        sanitize_name('Total Raw Score (TR)'), 
        sanitize_name('Prorated Score (PS)')
    ]
    
    new_data = pd.DataFrame([input_list_16], columns=feature_columns)
    
    # --- Step 3: Predict and Decode ---
    raw_prediction = model.predict(new_data)
    encoded_prediction = np.argmax(raw_prediction[0]) 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label

if __name__ == '__main__':
    # --- Example Test Data (14 Scores Input, 1-5 scale) ---
    # Example: Total Raw Score 40 (Moderate Severity)
    new_scores = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 1, 1, 1]
    
    # Check sum: 11*3 + 3*1 = 36. This is a Moderate Severity score.
    
    result = predict_severity(new_scores)
    print(f"Predicted severity for Depression (PROMIS-14) is: {result}")