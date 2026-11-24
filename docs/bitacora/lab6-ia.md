He leído la política de uso de IA de la asignatura.

# Declaración de uso de IA · Lab 6 · E033

<!--
CÓMO SE RELLENA (léelo y borra este comentario si quieres; el script de evaluación lo ignora)
- La PRIMERA línea es obligatoria y no se toca: «He leído la política de uso de IA de la asignatura.»
- Copia este archivo como docs/bitacora/lab6-ia.md (junto a lab6-respuestas.md) y pon tu código en el título.
  Cada laboratorio tiene el suyo: en el Lab 7 será docs/bitacora/lab7-ia.md.
- Si NO has usado IA: deja solo la línea «No he usado IA.» y borra la entrada de ejemplo.
- Si la has usado: borra la línea «No he usado IA.» y escribe UNA entrada por cada uso, con los 7 campos.
  Un campo vacío es una entrada incompleta (D3: −0,5 por entrada).
- Preguntar a la IA como tutor o corregir la ortografía de un texto propio está permitido: decláralo también.
  Si no copiaste código, escribe «no aplica» en «Código recibido» y en «Evidencia de ejecución» (no cuentan como vacíos).
  Los demás campos son siempre obligatorios.
- Una entrada con TODOS los campos vacíos (la de ejemplo sin tocar) no cuenta: se ignora.
- El código copiado de una IA puntúa si lo EJECUTAS en tu contenedor, lo EXPLICAS con tus palabras,
  dices para qué lo usaste y adjuntas aquí el código y el prompt LITERAL.
-->

## Entrada 1
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
he copiado el zip en descargas, ejecuto lo que me has pasado?
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql
no aplica
```
- **Dónde lo usé (parte, script o pregunta):** Parte A.1 y A.2, copia del kit
- **Propósito (para qué lo necesitaba):** confirmar la ruta del kit en Descargas y comprobar que el 00-config.sh del kit solo añadía EVID_LAB6 y SQLPATH antes de sustituir el mío
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** Antes de ejecutar el bloque comprobé que el zip estaba en Descargas con el nombre correcto. Después comparé con diff el 00-config.sh del kit con el mío: solo cambiaban comentarios y añadía EVID_LAB6 y SQLPATH, así que pude sustituirlo sin perder nada.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** no aplica

## Entrada 2
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
dame ejemplos de esto para poder usarlos
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):**
```sql
no aplica
```
- **Dónde lo usé (parte, script o pregunta):** Parte A.3, config/.env
- **Propósito (para qué lo necesitaba):** ver el formato válido de las contraseñas y del código de alumno
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** Me sirvió para ver qué formato tenían que tener las tres líneas nuevas de config/.env: contraseñas de al menos 12 caracteres con mayúsculas, minúsculas, dígitos y un símbolo (# o _, sin caracteres que bash interprete) y mi código de alumno como E033.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** no aplica
