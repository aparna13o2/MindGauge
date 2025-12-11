# train_depression.py
import sys
import os

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)

from train_model import train_lgbm_model 

if __name__ == '__main__':
    
    # --- 1. Define Paths and Configuration for the DEPRESSION DOMAIN ---
    
    # Path to your Depression data file
    FILE_PATH = "../../data/children_scores/depression_scores.csv"
    
    # Use clear, domain-specific names for the model files
    MODEL_OUTPUT_PATH = "../../models/children_model/depression_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../../models/children_model/depression_label_encoder.pkl"
    
    # The PROMIS Depression scale (14 items) typically has NO reverse scored items.
    DEPRESSION_REVERSE_COLS = [] 
    
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True)
    
    print("Starting Depression (PROMIS-14) Model Training...")
    
    try:
        # --- 2. Call the Reusable Training Function ---
        train_lgbm_model(
            file_path=FILE_PATH,
            model_output_path=MODEL_OUTPUT_PATH,
            label_encoder_path=LABEL_ENCODER_PATH,
            reverse_cols_map=DEPRESSION_REVERSE_COLS, # Empty list as no items are reversed
            label_column="End Result Label" # Use the exact label column name from your CSV
        )
        
        print("\nSuccessfully trained and saved the Depression model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)