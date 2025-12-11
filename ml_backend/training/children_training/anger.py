# train_anger.py
import sys
import os
# --- FIX: Add the models directory to the path ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# --------------------------------------------------

from train_model import train_lgbm_model 

if __name__ == '__main__':
    
    # --- 1. Define Paths and Configuration for the ANGER DOMAIN ---
    
    # Path to your Anger data file (two levels up to the data folder)
    FILE_PATH = "../../data/children_scores/anger_scores.csv"
    
    MODEL_OUTPUT_PATH = "../../models/children_model/anger_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../../models/children_model/anger_label_encoder.pkl"
    
    # ANGER (13 items) typically has NO reverse scored items.
    ANGER_REVERSE_COLS = [] 
    
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True)
    
    print("Starting Anger Model Training...")
    
    try:
        # --- 2. Call the Reusable Training Function ---
        train_lgbm_model(
            file_path=FILE_PATH,
            model_output_path=MODEL_OUTPUT_PATH,
            label_encoder_path=LABEL_ENCODER_PATH,
            reverse_cols_map=ANGER_REVERSE_COLS, 
            label_column="End Result Label" 
        )
        
        print("\nSuccessfully trained and saved the Anger model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)