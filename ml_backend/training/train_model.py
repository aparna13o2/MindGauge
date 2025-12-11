import pandas as pd
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
import lightgbm as lgb
import joblib
from lightgbm import early_stopping
import numpy as np
import re
import math

# ==============================================================================
# 1. FINAL DATA PREPARATION FUNCTION (Stable and uses Name-Based Reverse Scoring)
# ==============================================================================

def convert_sheet(df, reverse_score_names):
    
    # --- 1. Store descriptive names and sanitize them ---
    df.columns = [str(col).strip() for col in df.columns]
    original_column_names = df.columns.tolist()
    
    # CRITICAL FIX: Sanitize Feature Names for LightGBM compatibility
    sanitized_original_names = []
    
    for name in original_column_names:
        # Replace illegal characters with an underscore
        name = name.replace(' ', '_')
        name = name.replace('(', '').replace(')', '')
        name = name.replace(',', '_').replace('.', '_').replace('-', '_').replace(':', '_')
        
        # Remove any resulting multiple underscores or leading/trailing ones
        name = re.sub(r'__+', '_', name).strip('_')
        sanitized_original_names.append(name)
        
    original_column_names = sanitized_original_names
    
    # --- 2. Rename to generic names for robust indexing/selection ---
    clean_columns = [f'col_{i}' for i in range(len(df.columns))]
    df.columns = clean_columns
    
    label_col_name = df.columns[-1]

    # --- 3. Convert to numeric and apply name-based reverse scoring ---
    for i, col in enumerate(df.columns):
        
        current_name = original_column_names[i]
        
        # Skip Sample ID (col_0) and the Label (last column) from conversion
        if col == 'col_0' or col == label_col_name:
            continue
        
        data_values = df[[col]].values.flatten()
        data_series = pd.Series(data_values)
        
        df[col] = pd.to_numeric(data_series, errors="coerce")
        
        # Apply Reverse Scoring based on the descriptive name
        if current_name in reverse_score_names:
            df[col] = 6 - df[col] 

    # Restore descriptive names for final output and feature importance
    df.columns = original_column_names
    
    return df


# ==============================================================================
# 2. MAIN TRAINING FUNCTION (Universal, CSV Loading, ML Logic)
# ==============================================================================

def train_lgbm_model(file_path, model_output_path, label_encoder_path, reverse_cols_map, label_column="label"):
    
    print(f"Training model for: {file_path}")

    # --- Data Loading (Stable CSV method) ---
    try:
        # Read CSV directly; this assumes the first row is the header
        data = pd.read_csv(file_path,header=0)
    except Exception as e:
        print(f"FATAL ERROR: Could not load CSV file at {file_path}")
        raise e
        
    # Process the data using the universal convert_sheet function
    print("Processing data from CSV...")
    data = convert_sheet(data.copy(), reverse_cols_map) 
    
    print(f"Final combined data shape: {data.shape}")
    print("All final columns:", data.columns.tolist())

    # --- Feature Selection and Initial Target Separation ---
    label_column_name = data.columns[-1]
    y_raw = data[label_column_name]
    
    # DYNAMIC FEATURE SELECTION: Select all columns *except* the first (Sample ID) and the last (Label)
    all_cols = data.columns.tolist()
    feature_cols = [col for col in all_cols if col != all_cols[0] and col != label_column_name]
    X_raw = data[feature_cols].copy() 
    
    # --- Pre-processing and Class Cleaning ---
    X_raw = X_raw.fillna(X_raw.mean())
    y_cleaned = y_raw.dropna() 
    X_aligned = X_raw.loc[y_cleaned.index]

    # Temporarily encode to identify classes
    le = LabelEncoder()
    le.fit(y_cleaned)
    y_encoded_temp = le.transform(y_cleaned)

    # 1. Identify classes to remove (rogue 'label' or classes with < 2 samples)
    classes_to_remove_labels = []
    if label_column in le.classes_:
        classes_to_remove_labels.append(label_column)
    
    current_class_counts = pd.Series(y_encoded_temp).value_counts()
    underrepresented_codes = current_class_counts[current_class_counts < 2].index.tolist()
    
    if underrepresented_codes:
        underrepresented_labels = le.inverse_transform(underrepresented_codes).tolist()
        classes_to_remove_labels.extend(underrepresented_labels)

    # 2. Filter the data based on the labels to be removed
    if classes_to_remove_labels:
        y_final = y_cleaned[~y_cleaned.isin(classes_to_remove_labels)]
        X_aligned = X_raw.loc[y_final.index]
    else:
        y_final = y_cleaned

    # 3. Final Label Encoding on the cleaned, filtered set
    le = LabelEncoder()
    y_encoded = le.fit_transform(y_final)
    
    # Final check of data state
    final_class_counts = pd.Series(y_encoded).value_counts()
    if (final_class_counts < 2).any():
        raise ValueError("Critical: After cleaning, stratification is still not possible. Check data manually.")
    
    print("\nFinal Cleaned Label mapping:", dict(zip(le.classes_, le.transform(le.classes_))))
    print("Final Class Distribution Counts:\n", final_class_counts)


    # --- Training Split with Stratification ---
    X_train, X_test, y_train, y_test = train_test_split(
        X_aligned, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded 
    )

    # --- LightGBM Model Training Parameters ---
    train_data = lgb.Dataset(X_train, label=y_train)
    test_data = lgb.Dataset(X_test, label=y_test)

    params = {
        "objective": "multiclass",
        "num_class": len(le.classes_),
        "learning_rate": 0.01,
        "num_leaves": 20,         # <-- INCREASED
        "max_depth": 6,           # <-- INCREASED
        "metric": "multi_logloss",
        "n_jobs": -1,
        "verbose": -1,
        "lambda_l1": 0.01,        # <-- REDUCED REGULARIZATION
        "lambda_l2": 0.01,        # <-- REDUCED REGULARIZATION
        "min_child_samples": 5,   # <-- REDUCED
        "is_unbalance": True
    }

    callbacks = [early_stopping(stopping_rounds=30, verbose=-1)]

    model = lgb.train(params, train_data, valid_sets=[test_data], num_boost_round=3000, callbacks=callbacks)

    # --- Save Model and Encoder ---
    joblib.dump(model, model_output_path)
    joblib.dump(le, label_encoder_path)

    print("\nTraining complete. Model saved.")
    
    # --- Feature Importance ---
    importance = pd.DataFrame({"feature": X_aligned.columns, "importance": model.feature_importance()})
    print("\nFeature Importance:\n", importance.sort_values(by="importance", ascending=False))