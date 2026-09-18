\# Respuestas del Laboratorio 1 — Git Fundamentals



\## 1. Working Directory, Staging Area y Local Repository



El Working Directory es la carpeta donde editamos los archivos. La Staging Area es la zona intermedia donde seleccionamos los cambios que queremos incluir en el siguiente commit. El Local Repository es el historial guardado dentro de `.git`.



Por ejemplo, `docs/lab1-respuestas.md` se crea y edita en el Working Directory, se prepara con `git add docs/lab1-respuestas.md` y finalmente se guarda en el historial con `git commit`.



\## 2. Modificar un archivo sin hacer git add



No. Git commit solo guarda los cambios que están en la Staging Area. Si modifico un archivo pero no ejecuto `git add`, ese cambio permanece en el Working Directory y no entra en el commit.



\## 3. Carpetas vacías



Las carpetas vacías no aparecían porque Git versiona archivos, no carpetas. Para conservarlas usamos archivos `.gitkeep` dentro de cada carpeta.



\## 4. HEAD



HEAD es el puntero que indica la rama y el commit en el que estoy trabajando actualmente. Por ejemplo, cuando aparece `HEAD -> main`, significa que estoy en la rama `main`.



\## 5. Branch frente a carpeta



`git switch -c nombre-rama` crea una nueva línea de historial dentro de Git, mientras que `mkdir nombre-carpeta` crea una carpeta física en el disco. Lo comprobamos porque al crear `feature/customer-search` no apareció ninguna carpeta `feature/` con `ls -la`.



\## 6. Marcadores de conflicto



El contenido situado entre `<<<<<<< HEAD` y `=======` correspondía a la versión que ya tenía la rama actual, `main`. El contenido entre `=======` y `>>>>>>> fix/readme-subtitle` correspondía a la versión de la rama que se estaba fusionando.



\## 7. Por qué no usar amend después de push



`git commit --amend` reemplaza el commit anterior y genera otro hash. Si el commit ya se ha subido, otras personas pueden tener la versión anterior. Cambiarla provoca historiales diferentes y problemas de sincronización. Después de hacer push es más seguro crear un commit nuevo.



\## 8. Borrar la carpeta .git



Se perdería el historial local, las ramas, los commits y la configuración del repositorio. Los archivos del proyecto seguirían en el disco, pero dejarían de estar controlados por ese repositorio Git.



\## 9. Diferencia entre Git y GitHub



Git es el programa que controla las versiones en el ordenador. GitHub es un servicio web que almacena repositorios Git y permite colaborar, revisar cambios y gestionar ramas y proyectos.



\## 10. Archivo .env con contraseñas



No se debe subir porque contiene información secreta. Aunque el repositorio sea privado, puede haber accesos indebidos, filtraciones o copias del historial. Las contraseñas también podrían seguir siendo recuperables aunque se borre después el archivo.



\## 11. Error non-fast-forward



Normalmente significa que el repositorio remoto tiene commits que todavía no existen en mi copia local. Primero ejecutaría:



```bash

git pull

```



Después resolvería cualquier conflicto y ejecutaría `git push`.



\## 12. Tipos de Conventional Commits



\- Añadir un índice de rendimiento a una tabla: `perf`.

\- Corregir una restricción mal definida: `fix`.

\- Actualizar el README: `docs`.



Ejemplos:



```text

perf(db): add customer lookup index

fix(db): correct invalid table constraint

docs: update README

```

