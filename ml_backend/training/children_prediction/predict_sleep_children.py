# predict_sleep_children.py
import joblib
import pandas as pd
import numpy as np
import math
import re

# --- 1. Model Loading ---
# UPDATE THESE PATHS to match where your sleep models are saved
MODEL_PATH = '../../models/children_model/sleep_lgbm_model.pkl'
ENCODER_PATH = '../../models/children_model/sleep_label_encoder.pkl'

try:
    model = joblib.load(MODEL_PATH) 
    le = joblib.load(ENCODER_PATH) 
except FileNotFoundError:
    print("FATAL ERROR: Sleep model files not found. Ensure you ran train_sleep.py successfully.")
    exit()

# --- 2. Configuration (MUST MATCH train_sleep.py) ---

# Define the exact names of the columns that must be REVERSE SCORED.
# These MUST MATCH the headers in your sleep_scores.csv AND the configuration in train_sleep.py.
SLEEP_REVERSE_COLS = [
    'I was satisfied with my sleep.', 
    'My sleep was refreshing.', 
    'I got enough sleep.', 
    'My sleep quality was...'
]

def sanitize_name(name):
    """Applies the exact same sanitization used during training."""
    name = str(name).strip().replace(' ', '_')
    name = name.replace('(', '').replace(')', '')
    name = name.replace(',', '_').replace('.', '_').replace('-', '_').replace(':', '_')
    name = re.sub(r'__+', '_', name).strip('_')
    return name

def predict_severity(raw_symptom_scores):
    """
    Predicts the sleep severity label by accepting 8 raw scores and internally 
    calculating the required 10 features (8 symptoms + TR + PS).
    """
    if len(raw_symptom_scores) != 8:
        raise ValueError("Input must contain exactly 8 symptom scores for the Sleep scale.")
        
    # --- Step 1: Pre-process Raw Scores (Reverse Scoring) ---
    
    # Names of all 8 symptom columns in their input order
    symptom_names = [
        'My sleep was restless.', 'I was satisfied with my sleep.', 'My sleep was refreshing.', 
        'I had difficulty falling asleep.', 'I had trouble staying asleep.', 'I had trouble sleeping.', 
        'I got enough sleep.', 'My sleep quality was...'
    ]
    
    # Apply reverse scoring to the raw inputs before calculation
    processed_scores = []
    for i, score in enumerate(raw_symptom_scores):
        name = symptom_names[i]
        
        if name in SLEEP_REVERSE_COLS:
            # Reverse formula for 1-5 scale: Scored = 6 - Raw
            processed_scores.append(6 - score)
        else:
            processed_scores.append(score)
            
    # --- Step 2: Calculate the 2 Missing Features (TR and PS) ---
    
    # 1. Calculate Total Raw Score (TR)
    total_raw_score = sum(processed_scores)
    
    # 2. Calculate Prorated Score (PS) 
    # Sleep scale is 8 items, often scaled to a different raw total (e.g., 40, depending on the tool).
    # Assuming the prorated score is the same as the raw score for simplicity if scaling factor is 1.
    # If the scaling factor is 10 items (e.g., 8 items scaled to 10), use (TR * 10) / 8.
    # For now, we will use the simple proportional scaling for demonstration:
    
    # Assuming the model was trained on 8 items scaled to 10 max items for prorating:
    # prorated_score = round((total_raw_score * 10) / 8) 
    
    # Let's assume the TR and PS are the same for simplicity unless scaling is confirmed:
    prorated_score = total_raw_score 
    
    # --- Step 3: Assemble the 10-Feature Input List and Names ---
    
    # 8 processed symptoms + TR + PS = 10 features
    input_list_10 = processed_scores + [total_raw_score, prorated_score]
    
    # Assemble the 10 feature names (must be sanitized)
    feature_columns = [
        sanitize_name(name) for name in symptom_names
    ] + [
        sanitize_name('Total Raw Score (TR)'), 
        sanitize_name('Prorated Score (PS)')
    ]
    
    new_data = pd.DataFrame([input_list_10], columns=feature_columns)
    
    # --- Step 4: Predict and Decode ---

    raw_prediction = model.predict(new_data)
    encoded_prediction = np.argmax(raw_prediction[0]) 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label

if __name__ == '__main__':
    # --- Example Test Data (8 Scores Input) ---
    # Example scores (1-5 scale): 
    # [Restless, Satisfied(R), Refreshing(R), Difficulty, TroubleStay, TroubleSleep, Enough(R), Quality(R)]
    # A low disturbance score (e.g., all 1s on non-reversed items, all 5s on reversed items)
    
    # Input Raw Scores (8 items):
    new_scores = [1, 5, 5, 1, 1, 1, 5, 5] 
    
    # Expected Processed Scores: [1, 1, 1, 1, 1, 1, 1, 1] -> TR=8, PS=8
    
    result = predict_severity(new_scores)
    print(f"Predicted severity for input {new_scores} is: {result}")