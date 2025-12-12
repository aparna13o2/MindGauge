# predict_adult_level1_diagnosis.py
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
    # Model loading and prediction logic remains the same
    MODEL_PATH = '../../models/adult_model/level1_diagnosis_lgbm_model.pkl'
    ENCODER_PATH = '../../models/adult_model/level1_diagnosis_label_encoder.pkl'
    
    try:
        model = joblib.load(MODEL_PATH) 
        le = joblib.load(ENCODER_PATH) 
    except FileNotFoundError:
        print("FATAL ERROR: Level 1 model files not found. Ensure you ran train_adult_level1_diagnosis.py successfully.")
        return "Prediction Error: Model files missing."

    FEATURE_COLUMNS = [
        'Depression_Score', 'Anger_Score', 'Mania_Score', 'Anxiety_Score', 
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Repetitive_Thoughts_Score',
        'Substance_Use_Score', 'Inattention_Score', 'Psychosis_Score', 
        'Dissociation_Score', 'Personality_Functioning_Score', 'Impulsivity_Score'
    ]
    
    if len(domain_scores) != len(FEATURE_COLUMNS):
        raise ValueError(f"Input must contain exactly {len(FEATURE_COLUMNS)} domain scores.")
    
    new_data = pd.DataFrame([domain_scores], columns=FEATURE_COLUMNS)
    raw_prediction = model.predict_proba(new_data)
    encoded_prediction = np.argmax(raw_prediction[0]) 
    predicted_label = le.inverse_transform([encoded_prediction])[0]
    
    return predicted_label

def check_level2_referrals(domain_scores):
    """
    Checks the 7 core domain scores against clinical thresholds.
    """
    THRESHOLDS = {
        'Depression_Score': 5,            
        'Anger_Score': 14,                
        'Anxiety_Score': 15,              
        'Somatic_Score': 5,               
        'Mania_Score': 6,                 
        'Repetitive_Thoughts_Score': 6,   
        'Sleep_Disturbance_Score': 25     
    }
    
    FEATURE_NAMES = [
        'Depression_Score', 'Anger_Score', 'Mania_Score', 'Anxiety_Score', 
        'Somatic_Score', 'Sleep_Disturbance_Score', 'Repetitive_Thoughts_Score',
        'Substance_Use_Score', 'Inattention_Score', 'Psychosis_Score', 
        'Dissociation_Score', 'Personality_Functioning_Score', 'Impulsivity_Score'
    ]

    score_map = dict(zip(FEATURE_NAMES, domain_scores))
    referral_list = {}
    
    # Check the 7 core domains against their clinical thresholds
    for domain, threshold in THRESHOLDS.items():
        if score_map.get(domain, 0) >= threshold:
            referral_list[domain] = f"Score: {score_map[domain]} (Threshold: {threshold})"
            
    # Check for Substance Use (any use, score >= 1, requires Level 2 check)
    substance_score = score_map.get('Substance_Use_Score', 0)
    if substance_score >= 1:
        referral_list['Substance_Use_Score'] = f"Score: {substance_score} (Threshold: 1)"
        
    return referral_list

def run_prediction_scenario(test_scores, scenario_name):
    """Runs a single scenario and prints the consolidated output."""
    
    diagnosis = predict_diagnosis(test_scores)
    referrals = check_level2_referrals(test_scores)
    
    print("\n" + "=" * 60)
    print(f"SCENARIO: {scenario_name}")
    print("=" * 60)
    
    print(f"1. HIGH-LEVEL DIAGNOSIS: {diagnosis}")
    
    print("\n2. LEVEL 2 REFERRAL CHECKLIST (Actionable Issues):")
    
    flagged_issues = []
    
    if referrals:
        for domain, reason in referrals.items():
            # Clean up domain name for display
            clean_domain = domain.replace('_Score', '').upper()
            flagged_issues.append(clean_domain)
            print(f"    ✅ {clean_domain}: {reason}")
    else:
        print("    ✅ None. All core domains are below the clinical threshold.")
    
    # --- CONSOLIDATED SUMMARY BOX (The requested output) ---
    print("\n" + "-" * 60)
    print(f"SUMMARY: {diagnosis}")
    
    if flagged_issues:
        issue_list = ", ".join(flagged_issues)
        print(f"LEVEL 2 CHECK REQUIRED FOR: {issue_list}")
    else:
        print("LEVEL 2 CHECK REQUIRED FOR: None")
    print("-" * 60)


if __name__ == '__main__':
    
    # --- Example Test Data (13 Scores Input) ---
    # [Dep, Anger, Mania, Anxiety, Somatic, Sleep, Repetitive, Substance, Inatt, Psychosis, Dissoc, Personality, Impulsivity]
    
    # Scenario 1: HIGH RISK (Scores cross many thresholds)
    test_scores_high = [27, 20, 20, 27, 30, 40, 20, 4, 18, 8, 7, 9, 9] 
    
    # Scenario 2: MODERATE RISK (Only a few thresholds crossed)
    test_scores_moderate = [7, 10, 5, 12, 4, 26, 0, 1, 5, 0, 1, 3, 4]
    
    # Scenario 3: LOW RISK (No thresholds crossed)
    test_scores_low = [2, 1, 0, 3, 4, 5, 1, 0, 2, 0, 1, 1, 2]
    
    
    # --- RUN SCENARIOS ---
    run_prediction_scenario(test_scores_high, "SEVERE PROFILE")
    run_prediction_scenario(test_scores_moderate, "MILD/MODERATE PROFILE")
    run_prediction_scenario(test_scores_low, "NO RISK PROFILE")