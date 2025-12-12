# train_children_level1_diagnosis.py
import sys
import os
import joblib
import pandas as pd
import lightgbm as lgb
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score

# --- FIX: Add the parent directory (where train_model.py lives) to the path ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# -----------------------------------------------------------------------------

if __name__ == '__main__':
    
    # --- 1. Define Paths and Configuration for the CHILDREN'S LEVEL 1 DIAGNOSIS ---
    
    # Canonical Input Path
    FILE_PATH = "../../data/children_scores/level1_children_scores.csv"
    
    # Canonical Output Path for the Level 1 Model
    MODEL_OUTPUT_PATH = "../../models/children_model/level1_diagnosis_lgbm_model.pkl"
    LABEL_ENCODER_PATH = "../../models/children_model/level1_diagnosis_label_encoder.pkl"
    
    # Define the 13 domain features (X). Note: The last feature is a placeholder/dummy.
    FEATURE_COLUMNS = [
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Inattention_Score', 'Depression_Score', 
        'Anger_Score', 'Irritability_Score', 'Mania_Score', 'Anxiety_Score', 
        'Psychosis_Score', 'Repetitive_Thoughts_Score', 'Substance_Use_Score', 
        'Suicidal_Ideation_Score'
    ]
    TARGET_COLUMN = "Clinical_Diagnosis"
    
    # Create the NESTED output directory path
    output_dir = os.path.dirname(MODEL_OUTPUT_PATH)
    os.makedirs(output_dir, exist_ok=True) 
    
    print("Starting Children's Level 1 Diagnosis Model Training...")
    
    try:
        # Load Data
        data = pd.read_csv(FILE_PATH)
        
        # 1. Prepare Features (X) and Target (Y)
        X = data[FEATURE_COLUMNS]
        y = data[TARGET_COLUMN]

        # 2. Encode Target
        le = LabelEncoder()
        y_encoded = le.fit_transform(y)
        num_classes = len(le.classes_)
        
        # 3. Split Data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_encoded, test_size=0.2, random_state=42
        )

        # 4. Define and Train the LightGBM Model
        lgb_clf = lgb.LGBMClassifier(
            objective='multiclass',
            num_class=num_classes,
            metric='multi_logloss',
            n_estimators=1000,
            learning_rate=0.05,
            random_state=42,
            n_jobs=-1,
            verbose=-1,
            early_stopping_round=50 
        )

        lgb_clf.fit(X_train, y_train, eval_set=[(X_test, y_test)])

        # 5. Save the Model and Encoder
        joblib.dump(lgb_clf, MODEL_OUTPUT_PATH)
        joblib.dump(le, LABEL_ENCODER_PATH)

        # 6. Evaluation (Optional but Recommended)
        y_pred = lgb_clf.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        print(f"\nModel Accuracy: {accuracy*100:.2f}%")
        print(f"Classes Trained: {le.classes_}")
        
        print("\nSuccessfully trained and saved the Children's Level 1 Diagnosis model!")

    except Exception as e:
        print(f"\nTraining failed due to an error: {e}")
        
    print("-" * 40)