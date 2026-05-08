"""
Ejemplo de ETL con Pandas
"""

import pandas as pd


def main():
    """
    Ejecuta el ETL
    """

    # 1. Leer archivos
    df_pagos = pd.read_excel("data/pagos.xlsx")
    df_catalogo = pd.read_csv("data/catalogo.csv")

    print("Pagos:")
    print(df_pagos.head())

    print("\nCatalogo:")
    print(df_catalogo.head())

    # 2. Limpieza básica
    df_pagos["Descripcion"] = (
        df_pagos["Descripcion"].astype(str).str.strip().str.lower()
    )
    df_pagos["Monto"] = pd.to_numeric(df_pagos["Monto"], errors="coerce").fillna(0)

    # 3. Merge
    df = df_pagos.merge(df_catalogo, on="Id", how="left")

    # 4. Layout final
    df_final = pd.DataFrame()
    df_final["Id"] = df["Id"]
    df_final["Descripcion"] = df["Descripcion"]
    df_final["Monto"] = df["Monto"]
    df_final["Categoria"] = df["Categoria"]

    # 5. Exportar
    output_path = "output/resultado.xlsx"
    df_final.to_excel(output_path, index=False)

    print(f"\n✅ Archivo generado en: {output_path}")


if __name__ == "__main__":
    main()
