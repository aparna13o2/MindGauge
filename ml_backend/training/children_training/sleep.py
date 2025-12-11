#sleep_children.py
import sys
import os
import joblib

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)

# Import the core training function
from train_model import train_lgbm_model 

if __name__ == '__main__':
    
    # --- 1. Define Paths and Configuration for the SLEEP DOMAIN ---
    
    # Path to your Sleep Disturbance data file
    FILE_PATH = "../../data/children_scores/sleep_scores.csv"
    
    # Use clear, domain-specific names for the model files
    MODEL_OUTPUT_PATH = "../../models/children_model/sleep_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../../models/children_model/sleep_label_encoder.pkl"
    
    # CRITICAL: Define the columns that must be REVERSE SCORED.
    # These strings MUST exactly match the header names in your CSV file.
    SLEEP_REVERSE_COLS = [
        # Columns that are 'good' outcomes (higher score means less disturbance)
        'I was satisfied with my sleep.', 
        'My sleep was refreshing.', 
        'I got enough sleep.', 
        'My sleep quality was...'
        # Add any other reversed columns here if your final data has them.
    ]
    
    # Ensure the models directory exists
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True)
    
    print("Starting Sleep Disturbance Model Training...")
    
    try:
        # --- 2. Call the Reusable Training Function ---
        # NOTE: The train_lgbm_model function no longer needs a target_sheet_name
        
        train_lgbm_model(
            file_path=FILE_PATH,
            model_output_path=MODEL_OUTPUT_PATH,
            label_encoder_path=LABEL_ENCODER_PATH,
            reverse_cols_map=SLEEP_REVERSE_COLS, # PASSES THE REVERSE SCORING INSTRUCTION
            label_column="End Result Label"      # Use the exact label column name from your CSV
        )
        
        print("\nSuccessfully trained and saved the Sleep Disturbance model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)