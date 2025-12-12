# predict_children_level1_diagnosis.py
import sys
import os
import joblib
import pandas as pd
import numpy as np

# --- FIX: Add the parent directory (where train_model.py lives) to the path ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# -----------------------------------------------------------------------------

def predict_diagnosis(domain_scores):
    """
    Predicts the Clinical Diagnosis based on 12 Level 1 domain scores (Children).
    """
    # --- 1. Model and Encoder Loading ---
    MODEL_PATH = '../../models/children_model/level1_diagnosis_lgbm_model.pkl' # Use children's path
    ENCODER_PATH = '../../models/children_model/level1_diagnosis_label_encoder.pkl' # Use children's path
    
    try:
        model = joblib.load(MODEL_PATH) 
        le = joblib.load(ENCODER_PATH) 
    except FileNotFoundError:
        print("FATAL ERROR: Children's Level 1 model files not found. Ensure you trained this model successfully.")
        return "Prediction Error: Model files missing."

    # --- 2. Define Features (MUST MATCH Training Order) ---
    # Based on the Level 1 Measure domains (Somatic, Sleep, Inattention, Depression, Anger, Irritability, Mania, Anxiety, Psychosis, Repetitive Thoughts, Substance Use, Suicidal Ideation)
    FEATURE_COLUMNS = [
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Inattention_Score', 'Depression_Score', 
        'Anger_Score', 'Irritability_Score', 'Mania_Score', 'Anxiety_Score', 
        'Psychosis_Score', 'Repetitive_Thoughts_Score', 'Substance_Use_Score', 
        'Suicidal_Ideation_Score' # Assuming one dummy score to match 13 input features
    ]
    
    if len(domain_scores) != len(FEATURE_COLUMNS):
        # NOTE: The children's measure has 12 domains + 1 dummy, ensure input is 13
        raise ValueError(f"Input must contain exactly {len(FEATURE_COLUMNS)} domain scores (12 actual domains + 1 dummy).")
    
    # --- 3. Prepare Data for Prediction ---
    new_data = pd.DataFrame([domain_scores], columns=FEATURE_COLUMNS)
    
    # --- 4. Predict and Decode ---
    raw_prediction = model.predict_proba(new_data)
    encoded_prediction = np.argmax(raw_prediction[0]) 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label

def check_level2_referrals_dsm5(domain_scores):
    """
    Checks the Level 1 domain scores against the definitive DSM-5-TR thresholds (0-4 scale).
    """
    
    # --- DEFINITIVE DSM-5-TR LEVEL 1 CHILDREN'S THRESHOLDS ---
    # Thresholds are based on the highest item score (0-4 scale) within the domain.
    # 2 = Mild or greater (Standard Threshold for most domains)
    # 1 = Slight or greater (Risk/Special Domains: Inattention, Psychosis, Substance Use, Suicidal Ideation)
    
    MILD_THRESHOLD = 2 
    SLIGHT_THRESHOLD = 1
    
    THRESHOLDS = {
        'Somatic_Score': MILD_THRESHOLD,           # I. Somatic Symptoms
        'Sleep_Disturbance_Score': MILD_THRESHOLD, # II. Sleep Problems
        'Inattention_Score': SLIGHT_THRESHOLD,     # III. Inattention (Slight or greater)
        'Depression_Score': MILD_THRESHOLD,        # IV. Depression
        'Anger_Score': MILD_THRESHOLD,             # V. Anger
        'Irritability_Score': MILD_THRESHOLD,      # VI. Irritability
        'Mania_Score': MILD_THRESHOLD,             # VII. Mania
        'Anxiety_Score': MILD_THRESHOLD,           # VIII. Anxiety
        'Psychosis_Score': SLIGHT_THRESHOLD,       # IX. Psychosis (Slight or greater)
        'Repetitive_Thoughts_Score': MILD_THRESHOLD, # X. Repetitive Thoughts
        'Substance_Use_Score': SLIGHT_THRESHOLD,   # XI. Substance Use (Yes/No or Slight)
        'Suicidal_Ideation_Score': SLIGHT_THRESHOLD, # XII. Suicidal Ideation (Yes/No or Slight)
    }
    
    FEATURE_NAMES = [
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Inattention_Score', 'Depression_Score', 
        'Anger_Score', 'Irritability_Score', 'Mania_Score', 'Anxiety_Score', 
        'Psychosis_Score', 'Repetitive_Thoughts_Score', 'Substance_Use_Score', 
        'Suicidal_Ideation_Score'
    ]

    score_map = dict(zip(FEATURE_NAMES, domain_scores))
    referral_list = {}
    
    # Check the domains against their official Level 1 item thresholds
    for domain, threshold in THRESHOLDS.items():
        if score_map.get(domain, 0) >= threshold:
            # Clean up domain name for display
            display_name = domain.replace('_Score', '').upper()
            referral_list[display_name] = f"Score: {score_map[domain]} (Threshold: {threshold})"
            
    return referral_list

def run_prediction_scenario(test_scores, scenario_name):
    """Runs a single scenario and prints the consolidated output."""
    
    # Note: If the children's model has not been trained, this will return "Prediction Error"
    diagnosis = predict_diagnosis(test_scores)
    referrals = check_level2_referrals_dsm5(test_scores)
    
    print("\n" + "=" * 60)
    print(f"CHILDREN'S SCENARIO: {scenario_name}")
    print("=" * 60)
    
    print(f"1. HIGH-LEVEL DIAGNOSIS: {diagnosis}")
    
    print("\n2. LEVEL 2 REFERRAL CHECKLIST (Actionable Issues):")
    
    flagged_issues = []
    
    if referrals:
        for domain, reason in referrals.items():
            # Clean up domain name for display
            clean_domain = domain.upper()
            flagged_issues.append(clean_domain)
            print(f"    ✅ {clean_domain}: {reason}")
    else:
        print("    ✅ None. All core domains are below the clinical threshold.")
    
    # --- CONSOLIDATED SUMMARY BOX (The final requested output) ---
    print("\n" + "-" * 60)
    print(f"SUMMARY: {diagnosis}")
    
    if flagged_issues:
        issue_list = ", ".join(flagged_issues)
        print(f"LEVEL 2 CHECK REQUIRED FOR: {issue_list}")
    else:
        print("LEVEL 2 CHECK REQUIRED FOR: None")
    print("-" * 60)


if __name__ == '__main__':
    
    # --- Example Test Data (13 Scores Input: 12 domains + 1 dummy) ---
    # These scores represent the HIGHEST ITEM SCORE (0-4) within the domain.
    # Order: [Somatic, Sleep, Inattention, Depression, Anger, Irritability, Mania, Anxiety, Psychosis, Repetitive, Substance, Suicidal]
    
    # Scenario 1: SEVERE RISK (Scores are high or risk-elevated)
    test_scores_high = [4, 3, 4, 4, 4, 3, 3, 4, 2, 4, 4, 1] 
    
    # Scenario 2: MILD/MODERATE RISK (Scores are at or slightly above Mild (2))
    test_scores_moderate = [2, 2, 1, 2, 2, 2, 2, 2, 0, 2, 0, 0]
    
    # Scenario 3: LOW RISK (All scores are 0 or 1, below the Mild (2) threshold)
    test_scores_low = [1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0]
    
    
    # --- RUN SCENARIOS ---
    print("=" * 70)
    print("      CHILDREN'S LEVEL 1 DIAGNOSTIC AND LEVEL 2 REFERRAL CHECKER")
    print("=" * 70)
    
    run_prediction_scenario(test_scores_high, "SEVERE PROFILE (Most items > Mild)")
    run_prediction_scenario(test_scores_moderate, "MILD/MODERATE PROFILE (Most items = Mild)")
    run_prediction_scenario(test_scores_low, "LOW RISK PROFILE (Most items < Mild)")
    