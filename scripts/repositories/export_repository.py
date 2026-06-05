import pandas as pd

def export_to_excel(df: pd.DataFrame):
    """
    Exporta el DataFrame a Excel.
    """
    output_path = "output/resultado.xlsx"
    df.to_excel(output_path, index=False)
    print(f"\n✅ Archivo generado en: {output_path}")
