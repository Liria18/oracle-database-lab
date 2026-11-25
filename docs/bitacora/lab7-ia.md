He leído la política de uso de IA de la asignatura.

# Declaración de uso de IA · Lab 7 · E033

## Entrada 1
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
[AVISO] el banco T6 aún no existe: lo crea  caso --preparar  (unos 40 s)
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):** no aplica
- **Dónde lo usé (parte, script o pregunta):** Parte A, A.2 y A.5
- **Propósito (para qué lo necesitaba):** saber si el AVISO de instalar.sh era un error o si podía seguir con la Parte A
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** el aviso solo indica que el banco T6 todavía no está creado; no es un fallo, se resuelve en A.5 con caso --preparar, así que hice antes la copia lab7-inicio y después creé el banco
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** no aplica

## Entrada 2
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
FALLO optimizer_index_cost_adj de FREEPDB1 = 4100 (por defecto, 100)
FALLO No queda el valor guardado en el SPFILE de la PDB (se quitó con RESET)
FALLO La V2 de la búsqueda vuelve a usar IX_T6_PED_CP
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):** las sentencias de los archivos *_INC-605_arreglo.txt, *_INC-608_arreglo.txt e *_INC-610_arreglo.txt de docs/bitacora/lab7/evidencia/incidentes/
- **Dónde lo usé (parte, script o pregunta):** Parte G, arreglo de INC-605, INC-608 e INC-610
- **Propósito (para qué lo necesitaba):** confirmar la sintaxis exacta de DBMS_STATS y de ALTER SYSTEM RESET en una PDB antes de aplicar el arreglo que había decidido con el playbook
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** en INC-605 quito el bloqueo de CESTA con UNLOCK_TABLE_STATS y recojo sus 183 100 filas reales; en INC-608 cambio la preferencia METHOD_OPT para que ESTADO conserve su histograma, recojo como pendientes, las pruebo en mi sesión y las publico; en INC-610 devuelvo optimizer_index_cost_adj a 100 en memoria y lo quito del SPFILE de la PDB con RESET para que no vuelva tras un reinicio
- **Evidencia de ejecución (archivo de docs/bitacora/lab7/evidencia con mi cabecera):** docs/bitacora/lab7/evidencia/incidentes/*_arreglo.txt y los *_verificar.txt en OK
