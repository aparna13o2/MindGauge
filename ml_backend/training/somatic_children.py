# somatic_children.py (Corrected for CSV)
import os
import joblib

# Assuming train_lgbm_model is defined in train_model.py
from train_model import train_lgbm_model 

if __name__ == '__main__':
    # --- 1. Define Paths and Configuration for the SOMATIC DOMAIN ---
    
    # !!! FILE PATH NOW POINTS TO THE CSV FILE !!!
    FILE_PATH = "../data/somatic_scores.csv"
    
    # Use clear, domain-specific names for the model files
    MODEL_OUTPUT_PATH = "../models/somatic_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../models/somatic_label_encoder.pkl"
    
    # Somatic Symptoms (PHQ-15) has NO reverse scored items.
    SOMATIC_REVERSE_COLS = [] 
    
    os.makedirs('../models', exist_ok=True)
    
    print("Starting Somatic Symptom Model Training...")
    
    try:
        # --- 2. Call the Reusable Training Function (with corrected arguments) ---
        train_lgbm_model(
            file_path=FILE_PATH, # Changed from excel_path
            model_output_path=MODEL_OUTPUT_PATH,
            label_encoder_path=LABEL_ENCODER_PATH,
            reverse_cols_map=SOMATIC_REVERSE_COLS, 
            label_column="End Result Label" # Use the actual label column name from your CSV
        )
        
        print("\nSuccessfully trained and saved the Somatic Symptom model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)