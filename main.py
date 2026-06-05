"""
Ejemplo de ETL con Pandas - Refactorizado
"""

from scripts.processors.process_input import process_data
from scripts.repositories.export_repository import export_to_excel

def main():
    """
    Ejecuta el ETL orquestando los diferentes componentes.
    """
    # 1 y 2. Leer, limpiar y procesar datos
    df_final = process_data()

    # 3. Exportar resultados
    export_to_excel(df_final)

if __name__ == "__main__":
    main()
