# train_adult_sleep.py
import sys
import os
import joblib

# --- FIX: Add the parent directory (where train_model.py lives) to the path ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# -----------------------------------------------------------------------------

from train_model import train_lgbm_model 

if __name__ == '__main__':
    
    # --- 1. Define Paths and Configuration for the ADULT SLEEP DOMAIN ---
    
    # Canonical Input Path: PROMIS Sleep Disturbance 8-item scale
    FILE_PATH = "../../data/adult_scores/sleep_scores.csv"
    
    # Canonical Output Path: ADULT MODEL directory
    MODEL_OUTPUT_PATH = "../../models/adult_model/sleep_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../../models/adult_model/sleep_label_encoder.pkl"
    
    # --- REVERSE SCORING MAPPING (CRITICAL) ---
    # These items must be reversed (Score = 6 - Raw Score)
    SLEEP_REVERSE_COLS = [
        'I was satisfied with my sleep.', 
        'My sleep was refreshing.', 
        'I got enough sleep.', 
        'My sleep quality was...'
    ]
    
    # Create the NESTED output directory path
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True) 
    
    print("Starting Adult Sleep Disturbance Model Training...")
    
    try:
        # --- 2. Call the Reusable Training Function ---
        train_lgbm_model(
            file_path=FILE_PATH,
            model_output_path=MODEL_OUTPUT_PATH,
            label_encoder_path=LABEL_ENCODER_PATH,
            reverse_cols_map=SLEEP_REVERSE_COLS, 
            label_column="End Result Label" 
        )
        
        print("\nSuccessfully trained and saved the Sleep Disturbance model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)