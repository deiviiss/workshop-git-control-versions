# Workshop ETL + Git 🛠️

Este proyecto es un ejercicio práctico diseñado para un taller sobre **Git** y procesos **ETL** (Extract, Transform, Load) utilizando **Pandas**.

## 🎯 Objetivo

Aprender a gestionar versiones de código: guardar cambios, "romper" funcionalidades y recuperarlas usando Git de forma efectiva.

---

## 📋 Requisitos Previos

*   **Python 3.8+** instalado.
*   **Git** configurado en tu máquina.

---

## 🚀 Cómo empezar (Réplica local)

Sigue estos pasos para ejecutar el proyecto en tu máquina:

1. **Clonar el repositorio** (si aún no lo has hecho):
   ```bash
   git clone https://github.com/deiviiss/workshop-git-control-versions.git
   cd workshop-git-control-versions
   ```

2. **Crear y activar un entorno virtual** (recomendado):
   ```bash
   # Windows
   python -m venv .venv
   .venv\Scripts\activate
   ```

3. **Instalar dependencias**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Ejecutar el proceso ETL**:
   ```bash
   python scripts/main.py
   ```

---

## 📦 ¿Qué hace este proceso?

El script principal realiza las siguientes tareas:
1.  **Extract**: Lee datos de un archivo Excel (`pagos.xlsx`) y un catálogo CSV (`catalogo.csv`).
2.  **Transform**: Limpia descripciones, normaliza montos y une (merge) la información de ambas fuentes.
3.  **Load**: Genera un reporte final consolidado en `output/resultado.xlsx`.

---

## 📂 Estructura del Proyecto

```text
workshop-git-etl/
├── data/           # Archivos fuente (Excel y CSV)
├── scripts/        # Lógica del ETL (main.py)
├── output/         # Resultado del proceso
├── requirements.txt # Dependencias de Python
└── README.md       # Este archivo
```

---

## 🧪 Dinámica del Workshop

Durante la sesión vas a:
*   ✨ Realizar cambios en la lógica de transformación.
*   💥 Romper el código a propósito para probar errores.
*   💾 Usar `git add` y `git commit` para salvar tus avances.
*   ⏪ Recuperar versiones anteriores cuando algo salga mal.

---

## ☁️ Trabajo con Repositorios Remotos

En la segunda parte del workshop aprenderemos a conectar nuestro proyecto local con un repositorio remoto en GitHub.

### Flujo básico

1. Volver a la rama principal:
   ```bash
   git checkout main
   ```

2. Verificar conexión remota:
   ```bash
   git remote -v
   ```

3. Traer cambios nuevos:
   ```bash
   git pull --rebase
   ```

4. Crear un repositorio vacío en GitHub.

5. Cambiar el repositorio remoto:
   ```bash
   git remote remove origin
   git remote add origin <repo_url>
   ```

6. Subir cambios al nuevo repositorio:
   ```bash
   git push -u origin main
   ```

## ¿Qué aprendemos aquí?
* Diferencia entre repositorio local y remoto.
* Cómo sincronizar cambios entre máquinas.
* Cómo conservar commits locales.
* Cómo publicar proyectos usando GitHub.

---

## ⚠️ Regla de Oro

**No tengas miedo de romper nada.** El taller se trata precisamente de aprender a volver atrás y entender que Git es tu red de seguridad. 🛡️
