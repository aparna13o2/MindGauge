from train_model import train_lgbm_model

train_lgbm_model(
    excel_path="../data/adults_scores.xlsx",
    model_name_prefix="adults_lgbm"
)
