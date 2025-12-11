# predict_mania_children.py
import sys
import os
import joblib
import pandas as pd
import numpy as np
import math
import re

# --- FIX: Add the parent directory (where train_model.py lives) to the path ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# -----------------------------------------------------------------------------

# --- 1. Model Loading ---
MODEL_PATH = '../../models/children_model/mania_lgbm_model.pkl'
ENCODER_PATH = '../../models/children_model/mania_label_encoder.pkl'

try:
    model = joblib.load(MODEL_PATH) 
    le = joblib.load(ENCODER_PATH) 
except FileNotFoundError:
    print("FATAL ERROR: Mania model files not found. Ensure you ran train_mania.py successfully.")
    exit()

def sanitize_name(name):
    """Applies the exact same sanitization used during training."""
    name = str(name).strip().replace(' ', '_').replace('(', '').replace(')', '')
    name = name.replace(',', '_').replace('.', '_').replace('-', '_').replace(':', '_')
    name = re.sub(r'__+', '_', name).strip('_')
    return name

def predict_severity(raw_symptom_scores):
    """
    Accepts 5 raw ASRM scores and internally calculates the required 7 features.
    """
    if len(raw_symptom_scores) != 5:
        raise ValueError("Input must contain exactly 5 symptom scores for the Mania (ASRM) scale.")
        
    # ASRM has no reverse scoring, so processed scores = raw scores
    processed_scores = list(raw_symptom_scores)
            
    # --- Step 1: Calculate the 2 Missing Features (TR and PS) ---
    
    total_raw_score = sum(processed_scores)
    prorated_score = total_raw_score # Since all 5 items are present, PS = TR.
    
    # --- Step 2: Assemble the 7-Feature Input List and Names ---
    
    # 5 processed symptoms + TR + PS = 7 features
    input_list_7 = processed_scores + [total_raw_score, prorated_score]
    
    # Names of the 5 symptom columns (based on the CSV structure provided)
    symptom_names = [
        'Do you feel happier or more cheerful than usual?', 
        'Do you feel more self-confident than usual?', 
        'Do you need less sleep than usual?', 
        'Do you talk more than usual?', 
        'Have you been more active than usual?'
    ]
    
    # Assemble the 7 feature names (must be sanitized)
    feature_columns = [
        sanitize_name(name) for name in symptom_names
    ] + [
        sanitize_name('Total Raw Score (TR)'), 
        sanitize_name('Prorated Score (PS)')
    ]
    
    new_data = pd.DataFrame([input_list_7], columns=feature_columns)
    
    # --- Step 3: Predict and Decode ---
    raw_prediction = model.predict(new_data)
    encoded_prediction = np.argmax(raw_prediction[0]) 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label

if __name__ == '__main__':
    # --- Example Test Data (5 Scores Input, 0-4 scale) ---
    
    # Example 1: High Mania (Total Raw Score 10, Expected: Significant Mania)
    scores_significant = [3, 4, 1, 2, 0] 
    
    # Example 2: Low Mania (Total Raw Score 5, Expected: Less Significant Mania)
    scores_less_significant = [1, 1, 1, 1, 1] 
    
    result_significant = predict_severity(scores_significant)
    result_low = predict_severity(scores_less_significant)
    
    print(f"Prediction for score {scores_significant} (TR=10): {result_significant}")
    print(f"Prediction for score {scores_less_significant} (TR=5): {result_low}")