# train_adult_repetitive_thoughts.py
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
    
    # --- 1. Define Paths and Configuration for the ADULT REPETITIVE THOUGHTS DOMAIN ---
    
    # Canonical Input Path: FOCI 5-item scale
    FILE_PATH = "../../data/adult_scores/repetitive_thoughts_scores.csv"
    
    # Canonical Output Path: ADULT MODEL directory
    MODEL_OUTPUT_PATH = "../../models/adult_model/repetitive_thoughts_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../../models/adult_model/repetitive_thoughts_label_encoder.pkl"
    
    # FOCI has NO reverse scored items.
    REPETITIVE_THOUGHTS_REVERSE_COLS = [] 
    
    # Create the NESTED output directory path
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True) 
    
    print("Starting Adult Repetitive Thoughts Model Training...")
    
    try:
        # --- 2. Call the Reusable Training Function ---
        train_lgbm_model(
            file_path=FILE_PATH,
            model_output_path=MODEL_OUTPUT_PATH,
            label_encoder_path=LABEL_ENCODER_PATH,
            reverse_cols_map=REPETITIVE_THOUGHTS_REVERSE_COLS, 
            label_column="End Result Label" 
        )
        
        print("\nSuccessfully trained and saved the Repetitive Thoughts model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)