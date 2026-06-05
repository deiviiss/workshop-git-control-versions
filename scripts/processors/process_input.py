"""Obtencion/Limpieza y Transformacion de data"""

import pandas as pd
from scripts.services.cleaning_service import clean_strings, clean_numbers

def process_data() -> pd.DataFrame:
    """
    Lee archivos, aplica limpieza, realiza merge y construye layout final.
    """
    # 1. Leer archivos
    df_pagos = pd.read_excel("data/pagos.xlsx")
    df_catalogo = pd.read_csv("data/catalogo.csv")

    print("Pagos:")
    print(df_pagos.head())

    print("\nCatalogo:")
    print(df_catalogo.head())

    # 2. Limpieza básica
    df_pagos["Descripcion"] = clean_strings(df_pagos["Descripcion"])
    df_pagos["Monto"] = clean_numbers(df_pagos["Monto"])

    # 3. Merge
    df = df_pagos.merge(df_catalogo, on="Id", how="left")

    # 4. Layout final
    df_final = pd.DataFrame()
    df_final["Id"] = df["Id"]
    df_final["Descripcion"] = df["Descripcion"]
    df_final["Monto"] = df["Monto"]
    df_final["Categoria"] = df["Categoria"]
    df_final["MontoIva"] = df_final["Monto"] * 0.16  #

    return df_final
