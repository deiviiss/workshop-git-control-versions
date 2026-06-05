import pandas as pd

def clean_strings(series: pd.Series) -> pd.Series:
    """Aplica limpieza a strings: quita espacios y pasa a minúsculas"""
    return series.astype(str).str.strip().str.lower()

def clean_numbers(series: pd.Series) -> pd.Series:
    """Aplica limpieza a números: convierte a numérico y rellena nulos con 0"""
    return pd.to_numeric(series, errors="coerce").fillna(0)
