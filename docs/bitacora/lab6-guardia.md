# Lab 6 · Guardia: postmortems (E033)

## INC-601 · Secretaría no puede guardar la ficha del alumno 101 (bloqueo de fila)
- Detección: 19:07 UTC · ticket INC-601 del equipo de secretaría: la pantalla de Ana García se queda colgada al guardar el estado del alumno 101.
- Impacto: ANA_GARCIA no pudo actualizar la fila 101 de ACA_ESTUDIANTES mientras duró el bloqueo (unos minutos). El resto de filas y usuarios no estaban afectados.
- Diagnóstico: 08-diagnostico.sql, secciones 1 y 3: el SID 218 (ANA_GARCIA) esperaba en `enq: TX - row lock contention` con BLOCKING_SESSION = 56. El 56 era APP_ACADEMIA (module matriculas, action cierre-periodo), con TX en lmode 6, en espera Idle (`PL/SQL lock timer`): no estaba trabajando, solo retenía la fila. La sección 4 indicaba 1 bloque y 1 registro de undo, así que deshacerlo no costaba nada.
- Causa raíz: el proceso de cierre de periodo de la aplicación modifica una fila y deja la transacción abierta sin COMMIT mientras espera, así que cualquier otra sesión que toque esa fila se queda bloqueada.
- Intervención: `ALTER SYSTEM KILL SESSION '56,17938' IMMEDIATE;` en FREEPDB1. Es lo mínimo: termina solo la sesión bloqueadora y deshace un único UPDATE sin confirmar. No toca la cuenta, ni el servicio, ni reinicia nada.
- Validación: 08-diagnostico.sql otra vez: secciones 1 a 4 vacías (ya no hay nadie esperando). El alumno 101 quedó en ACTIVO, que es lo que Ana quería guardar: su UPDATE terminó en cuanto se liberó la fila.
- Acción preventiva: que el proceso de cierre haga COMMIT antes de cualquier espera. Configurar una alerta cuando una sesión lleve más de X minutos bloqueando a otra (V$SESSION.BLOCKING_SESSION) y un límite de inactividad (IDLE_TIME o MAX_IDLE_BLOCKER_TIME) para sesiones que retienen bloqueos.

## INC-602 · La aplicación no conecta: ORA-12514 (servicio parado)
- Detección: 19:10 UTC · ticket INC-602 (prioridad crítica) del equipo de matrículas: ninguna instancia de la aplicación conecta, error ORA-12514.
- Impacto: toda la aplicación de matrículas sin acceso a la base, desde que se paró el servicio hasta las 19:10:54. La base y la PDB seguían abiertas: freepdb1 funcionaba.
- Diagnóstico: 08-diagnostico.sql, sección 6: `academia_app` existe pero ARRANCADO = NO. `lsnrctl status` anunciaba freepdb1 pero no academia_app. Al conectar como la aplicación con app.sh: ORA-12514 «Service academia_app is not registered with the listener». El error lo da el listener, no la base, así que no había que reiniciar nada.
- Causa raíz: el servicio academia_app se paró (DBMS_SERVICE.STOP_SERVICE) y, sin servicio arrancado, la PDB no lo registra en el listener. No había ninguna alerta que detectara un servicio definido pero parado.
- Intervención: `EXEC DBMS_SERVICE.START_SERVICE('academia_app')` y `ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;`. Es lo mínimo: arranca solo ese servicio, sin reiniciar la base ni el listener. SAVE STATE guarda el estado con el servicio arrancado para que sobreviva a un reinicio.
- Validación: a las 19:10:54, `lsnrctl status` mostraba `Service "academia_app" ... READY` y, por el camino del consumidor (app.sh por academia_app), la conexión devolvió servicio = academia_app y usuario = APP_ACADEMIA.
- Acción preventiva: una comprobación periódica que compare los servicios definidos con V$ACTIVE_SERVICES y avise si alguno está parado. Que parar un servicio de producción pase por un procedimiento con aviso, y hacer SAVE STATE cada vez que se cambia el estado de los servicios.

## INC-603 · La aplicación no entra: ORA-28000 (cuenta bloqueada a mano)
- Detección: 19:11 UTC · ticket INC-603 del equipo de matrículas tras el despliegue: ORA-28000 sin haber cambiado la contraseña. Nota del turno: hoy se ejecutó el script trimestral de bajas.
- Impacto: la aplicación no pudo iniciar sesión desde las 19:11:17 hasta las 19:11:38.
- Diagnóstico: 08-diagnostico.sql, sección 7: APP_ACADEMIA en LOCKED (no LOCKED(TIMED)), con lock_date 19:11:17. Perfil DEFAULT: FAILED_LOGIN_ATTEMPTS 10 y PASSWORD_LOCK_TIME 1. Si fueran intentos fallidos, saldría LOCKED(TIMED). En UNIFIED_AUDIT_TRAIL, a las 19:11:17, SYS ejecuta `ALTER USER app_academia ACCOUNT LOCK`: el bloqueo fue manual, no por contraseña.
- Causa raíz: el script trimestral de bajas bloquea cuentas sin distinguir entre cuentas de personas y cuentas de aplicación, así que bloqueó APP_ACADEMIA como si fuera un usuario dado de baja.
- Intervención: `ALTER USER app_academia ACCOUNT UNLOCK;`. Es lo mínimo: no cambia la contraseña (la aplicación no ha cambiado nada), ni el perfil, ni los privilegios.
- Validación: la cuenta queda OPEN y, por el camino del consumidor (app.sh por academia_app), la conexión devolvió academia_app / APP_ACADEMIA a las 19:11:38. El diagnóstico final sale con la sección 7 vacía y todos los servicios en SI.
- Acción preventiva: que el script de bajas excluya las cuentas de aplicación (por ejemplo, con un perfil propio para aplicaciones o una lista de exclusión) y que registre qué cuentas bloquea. Añadir una alerta sobre cuentas de aplicación que no estén OPEN.

No se usó `08-guardia.sh limpiar` en ningún incidente.
