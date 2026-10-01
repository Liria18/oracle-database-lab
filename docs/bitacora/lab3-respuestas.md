# Lab 3 — Respuestas de comprobación

## Docker

1. Una imagen es la plantilla de solo lectura; un contenedor es una instancia creada a partir de ella. En G2, `hello-world` se creó desde su imagen y terminó tras mostrar un mensaje; en G4 entré en un contenedor Alpine y trabajé en su terminal.

2. En G5, `nota.txt` estaba en el sistema de archivos del contenedor eliminado, así que el contenedor nuevo no lo tenía. En G6 se escribió en un volumen con nombre: al montar ese mismo volumen en otro contenedor, el archivo seguía allí.

3. `docker ps` muestra los contenedores en marcha; `docker ps -a` incluye también los detenidos. `Exited 0` significa que el proceso principal terminó correctamente, no que Docker haya fallado.

4. En `-p 8181:8181`, el primer 8181 es el puerto de mi equipo y el segundo, el del contenedor. En el ejercicio de nginx, `-p 8080:80` funciona porque nginx escucha dentro en el 80; invertirlo como `-p 80:8080` enviaría la petición a un puerto interno donde nginx no escucha.

5. El proceso principal de `hello-world` solo imprime un mensaje y termina; por eso su contenedor se detiene. El de Oracle mantiene en ejecución el servicio de base de datos, por lo que continúa activo.

6. El digest `sha256` identifica el contenido exacto de una imagen. Registrarlo importa porque la etiqueta `latest` puede apuntar a otra imagen en el futuro; mi evidencia permite identificar cuál utilicé.

7. Los datos de Oracle están en el volumen con nombre `oralab-26ai-data`. `docker rm oralab-26ai` elimina el contenedor, pero no ese volumen; `docker volume rm oralab-26ai-data` borraría el volumen y sus datos. No debo ejecutarlo sobre este entorno.

## Git, organización y evidencia

8. El Issue describe lo que hay que conseguir; la rama aísla el trabajo, los commits dejan constancia de cada paso y el Pull Request permite revisarlo antes de integrarlo. En una carpeta aparte perdería esa trazabilidad y parte de la reproducibilidad del laboratorio.

9. `source 00-config.sh` ejecuta el archivo en mi shell actual, así que sus constantes quedan disponibles para los comandos siguientes. `bash 00-config.sh` abre un proceso hijo: al terminar, sus variables no quedan cargadas en mi terminal.

10. `20260915T091230Z` es la fecha y hora UTC; `02` identifica el paso; `docker` describe el contenido; `.script.log` indica una grabación o salida de terminal. El formato permite ordenar y localizar las evidencias sin depender de la zona horaria.

11. `.gitattributes` fija finales de línea LF para los scripts y otros archivos de texto. Así se evitan cambios de formato entre Windows y Linux y fallos de ejecución causados por archivos `.sh` con finales CRLF.

12. Un merge commit conserva los commits separados de instalación, migraciones y verificaciones. Con squash quedaría un único commit y sería más difícil seguir qué evidencia corresponde a cada etapa.

## Seguridad

13. Primero, `.gitignore` excluye los archivos reales de secretos; segundo, una plantilla versionada documenta los nombres sin incluir valores; tercero, las contraseñas reales viven en archivos locales; cuarto, los scripts las cargan en tiempo de ejecución. Sin la primera capa podría añadir por accidente un archivo con contraseñas a Git.

14. Si tecleo una contraseña literal en `docker run`, puede quedar en el historial de la terminal y ser visible mientras se ejecuta el proceso. Usar una variable evita escribir el valor en el comando guardado, aunque el archivo del script no se publique.

15. No basta con borrar el secreto en otro commit: el commit anterior sigue en el historial. Debo dejar de publicarlo, considerar comprometida la contraseña, rotarla y coordinar la limpieza del historial si ya se publicó.

## Oracle y herramientas

16. Un `archivo.sql` de mi repositorio no existe automáticamente dentro del contenedor, y un `SPOOL` ejecutado allí escribiría el archivo allí, no en mi repositorio. Por eso enviamos el SQL desde el anfitrión a `sqlplus` con `docker exec -i` y capturamos su salida localmente con `tee`.

17. `WHENEVER SQLERROR EXIT SQL.SQLCODE` hace que SQLPlus termine con un error cuando falla una sentencia SQL. Sin esa instrucción, una migración podría seguir ejecutándose y aparentar éxito pese a haber quedado incompleta.

18. Una migración es un cambio de estructura de base de datos registrado y aplicado en un orden definido. V000 prepara los entornos y V001 crea sus objetos; cambiarlas después de aplicarlas haría que el mismo nombre representara estructuras diferentes según cuándo se instaló la base.

19. `FREEPDB1` es el servicio de la base pluggable donde trabajamos. `FREE` se refiere al contenedor raíz de Oracle, no al entorno de trabajo deseado; además, la conexión se configura por nombre de servicio, no por SID.

20. SQLcl añade una experiencia de línea de comandos más cómoda y funciones modernas para trabajar con SQL. SQLPlus sigue siendo una herramienta básica y ampliamente disponible, especialmente útil para scripts y administración; conocer ambas permite elegir la adecuada según el entorno.

## Entorno de trabajo

21. Pasamos a Ubuntu en WSL 2 porque ejecuta un entorno Linux real, más parecido al de los servidores. Git Bash puede transformar rutas y argumentos de Docker, requiere soluciones adicionales para ciertas sesiones interactivas y no trae de serie herramientas de administración como `ss` o `free`.

22. Trabajar en el repositorio clonado dentro del sistema de archivos de Ubuntu evita la lentitud y los problemas de permisos o finales de línea al operar continuamente sobre `/mnt/c`. Recomendamos bash para scripts compartidos porque está disponible en los servidores del curso y evita diferencias de interpretación con zsh.
