# predict_adult_level1_multiclass.py
import sys
import os
import joblib
import pandas as pd
import numpy as np

# --- FIX: Path setup remains the same ---
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.join(current_dir, '..')
sys.path.append(parent_dir)
# --------------------------------------

def predict_diagnosis(domain_scores):
    """
    Predicts the Multi-Class Clinical Diagnosis (e.g., Severe Psychopathology).
    """
    # --- 1. Model and Encoder Loading (Uses MULTI-CLASS path) ---
    MODEL_PATH = '../../models/adult_model/level1_diagnosis_lgbm_model.pkl'
    ENCODER_PATH = '../../models/adult_model/level1_diagnosis_label_encoder.pkl'
    
    try:
        model = joblib.load(MODEL_PATH) 
        le = joblib.load(ENCODER_PATH) 
    except FileNotFoundError:
        return "Prediction Error: Model files missing. Please run train_adult_level1_multiclass.py first."

    FEATURE_COLUMNS = [
        'Depression_Score', 'Anger_Score', 'Mania_Score', 'Anxiety_Score', 
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Repetitive_Thoughts_Score',
        'Substance_Use_Score', 'Suicidal_Score', 'Psychosis_Score','Memory_Score','Dissociation_Score', 'Personality_Functioning_Score'
    ]
    
    if len(domain_scores) != len(FEATURE_COLUMNS):
        raise ValueError(f"Input must contain exactly {len(FEATURE_COLUMNS)} domain scores.")
    
    # --- Predict and Decode ---
    encoded_prediction = model.predict([domain_scores])[0] 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label


def check_level2_referrals_dsm5(domain_scores):
    """
    Checks the Level 1 (0-4) domain scores against the official DSM-5 thresholds (1 or 2).
    """
    MILD_THRESHOLD = 2 
    SLIGHT_THRESHOLD = 1
    
    THRESHOLDS = {
        'Depression_Score': MILD_THRESHOLD, 
        'Anger_Score': MILD_THRESHOLD, 
        'Mania_Score': MILD_THRESHOLD, 
        'Anxiety_Score': MILD_THRESHOLD, 
        'Somatic_Score': MILD_THRESHOLD, 
        'Sleep_Disturbance_Score': MILD_THRESHOLD, 
        'Repetitive_Thoughts_Score': MILD_THRESHOLD, 
        'Substance_Use_Score': SLIGHT_THRESHOLD, 
        'Suicidal_Score': SLIGHT_THRESHOLD,
        'Psychosis_Score': SLIGHT_THRESHOLD,
        'Memory_Score': MILD_THRESHOLD,
        'Dissociation_Score': MILD_THRESHOLD, 
        'Personality_Functioning_Score': MILD_THRESHOLD
    }
    
    FEATURE_NAMES = [
        'Depression_Score', 'Anger_Score', 'Mania_Score', 'Anxiety_Score', 
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Repetitive_Thoughts_Score',
        'Substance_Use_Score', 'Suicidal_Score', 'Psychosis_Score','Memory_Score','Dissociation_Score', 'Personality_Functioning_Score'
    ]

    score_map = dict(zip(FEATURE_NAMES, domain_scores))
    referral_list = {}
    
    for domain, threshold in THRESHOLDS.items():
        if score_map.get(domain, 0) >= threshold:
            display_name = domain.replace('_Score', '').upper()
            referral_list[display_name] = f"Score: {score_map[domain]} (Level 1 Threshold: {threshold})"
            
    return referral_list

def run_prediction_scenario(test_scores, scenario_name):
    """Runs a single scenario and prints the consolidated output."""
    
    diagnosis = predict_diagnosis(test_scores)
    referrals = check_level2_referrals_dsm5(test_scores)
    
    # ... (rest of the print functions remain the same) ...

    print("\n" + "=" * 60)
    print(f"SCENARIO: {scenario_name}")
    print("=" * 60)
    
    print(f"1. HIGH-LEVEL DIAGNOSIS: {diagnosis}")
    
    print("\n2. LEVEL 2 REFERRAL CHECKLIST (Actionable Issues):")
    
    flagged_issues = []
    
    if referrals:
        for domain, reason in referrals.items():
            clean_domain = domain.upper()
            flagged_issues.append(clean_domain)
            print(f"    ✅ {clean_domain}: {reason}")
    else:
        print("    ✅ None. All core domains are below the clinical threshold.")
    
    # --- CONSOLIDATED SUMMARY BOX ---
    print("\n" + "-" * 60)
    print(f"SUMMARY: {diagnosis}")
    
    if flagged_issues:
        issue_list = ", ".join(flagged_issues)
        print(f"LEVEL 2 CHECK REQUIRED FOR: {issue_list}")
    else:
        print("LEVEL 2 CHECK REQUIRED FOR: None")
    print("-" * 60)


if __name__ == '__main__':
    
    # --- Example Test Data (13 Scores Input: 0-4 Scale) ---
    test_scores_high = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4] 
    test_scores_moderate = [2, 1, 0, 3, 2, 1, 0, 1, 0, 1, 0, 2, 3] 
    test_scores_low = [1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1]
    
    
    # --- RUN SCENARIOS ---
    print("=" * 70)
    print("      ADULT LEVEL 1 DIAGNOSTIC AND LEVEL 2 REFERRAL CHECKER (DSM-5 MULTI-CLASS)")
    print("=" * 70)
    
    run_prediction_scenario(test_scores_high, "SEVERE PROFILE (DSM-5 Multi-Class)")
    run_prediction_scenario(test_scores_moderate, "MILD/MODERATE PROFILE (DSM-5 Multi-Class)")
    run_prediction_scenario(test_scores_low, "LOW RISK PROFILE (DSM-5 Multi-Class)")