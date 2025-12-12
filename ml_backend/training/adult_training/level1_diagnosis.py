# train_adult_level1_multiclass.py
import sys
import os
import joblib
import pandas as pd
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score

# --- FIX: Path setup remains the same ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# -----------------------------------------------------------------------------

if __name__ == '__main__':
    
    # --- 1. Define Paths and Configuration ---
    
    # INPUT DATA: Uses the CSV with features scaled 0-4 (Highest Item Score)
    FILE_PATH = "../../data/adult_scores/level1_adult_scores.csv" 
    
    # NEW OUTPUT MODEL: Uses new multiclass name
    MODEL_OUTPUT_PATH = "../../models/adult_model/level1_diagnosis_lgbm_model.pkl" 
    LABEL_ENCODER_PATH = "../../models/adult_model/level1_diagnosis_label_encoder.pkl" 
    
    FEATURE_COLUMNS = [
        'Depression_Score', 'Anger_Score', 'Mania_Score', 'Anxiety_Score', 
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Repetitive_Thoughts_Score',
        'Substance_Use_Score', 'Suicidal_Score', 'Psychosis_Score','Memory_Score','Dissociation_Score', 'Personality_Functioning_Score'
    ]
    TARGET_COLUMN = "Clinical_Diagnosis" # The original multi-class column
    
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True) 
    
    print("Starting Adult Level 1 Diagnosis Model Training (MULTI-CLASS)...")
    
    try:
        # 1. Load Data
        data = pd.read_csv(FILE_PATH)
        
        # 2. --- DATA BALANCING (Over-sample minority classes for better learning) ---
        data_severe = data[data[TARGET_COLUMN].str.contains('Severe Psychopathology')]
        data_minority = data[data[TARGET_COLUMN] != 'No Diagnosis']
        
        # Over-sample the minority class (repeat samples twice to help multi-class learning)
        data_minority_oversampled = pd.concat([data_minority] * 2, ignore_index=True)
        
        # Combine the balanced dataset
        data_balanced = pd.concat([data_severe] * 3 + [data_minority_oversampled] * 2 + [data[data[TARGET_COLUMN] == 'No Diagnosis']], ignore_index=True)
        print(f"Dataset balanced: New size is {len(data_balanced)} samples.")
        
        # 3. Prepare Features and Target
        X = data_balanced[FEATURE_COLUMNS]
        y = data_balanced[TARGET_COLUMN] # Use the original multi-class labels

        # 4. Encode Target 
        le = LabelEncoder()
        y_encoded = le.fit_transform(y)
        num_classes = len(le.classes_)
        
        # 5. Split Data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_encoded, test_size=0.2, random_state=42
        )

        # 6. Define and Train the LightGBM Model (using 'multiclass' objective)
        lgb_clf = lgb.LGBMClassifier(
            objective='multiclass', # KEY CHANGE: Multi-class classification
            num_class=num_classes,
            metric='multi_logloss',
            n_estimators=1000,
            learning_rate=0.05,
            random_state=42,
            n_jobs=-1,
            verbose=-1,
            early_stopping_round=50 
        )

        print("Training model...")
        lgb_clf.fit(X_train, y_train, eval_set=[(X_test, y_test)])

        # 7. Save the Model and Encoder
        joblib.dump(lgb_clf, MODEL_OUTPUT_PATH)
        joblib.dump(le, LABEL_ENCODER_PATH)

        # 8. Evaluation
        y_pred = lgb_clf.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        print("\n" + "=" * 40)
        print("Training Complete & Model Saved")
        print(f"Model Accuracy (Test Set): {accuracy*100:.2f}%")
        print(f"Classes Trained: {le.classes_}")
        print("=" * 40)

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)