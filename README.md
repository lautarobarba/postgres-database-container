# PostgreSQL Database Container

## Configuración

El proyecto **no crea ninguna base de datos ni usuario de aplicación por defecto**. La única configuración es el puerto y la contraseña del superusuario `postgres`.

```bash
$ cp .env.example .env
$ nano .env
```

| Variable               | Descripción                                 |
| ---------------------- | ------------------------------------------- |
| `DB_PORT`              | Puerto del host donde se expone PostgreSQL. |
| `DB_POSTGRES_PASSWORD` | Contraseña del superusuario `postgres`.     |

> `DB_POSTGRES_PASSWORD` sólo se aplica la **primera vez** que se levanta el contenedor (cuando **/database/data** está vacío). Cambiarla después en el _.env_ no modifica la contraseña real de `postgres`; para eso ver [Resetear la contraseña de postgres](#resetear-la-contraseña-de-postgres).

## Iniciar

```bash
$ docker compose up -d
```

_Quitando la opción *-d* se ven los logs del contenedor._

## Detener

```bash
$ # Si estan corriendo con logs visibles
$ #     detener con Ctr+C
$ docker compose down
```

# Database (PostgreSQL 18)

Toda la base de datos queda guardada en **/database/data** (desde PostgreSQL 18 los archivos quedan dentro de **/database/data/18/docker**).

Al crear la instancia se configura (con `POSTGRES_INITDB_ARGS` en _compose.yaml_) codificación `UTF8` y ordenamiento en español con ICU (`es-AR`), así que todas las bases nuevas lo heredan. Esto sólo se aplica la primera vez, cuando **/database/data** está vacío.

## Conectarse como postgres

El superusuario `postgres` es **sólo para administrar** este servicio (crear bases de datos, usuarios, backups). Ninguna aplicación debería conectarse con `postgres`.

```bash
$ docker compose exec -it postgres_db psql -U postgres
```

_Desde dentro del contenedor no pide contraseña (conexión local por socket). Desde fuera del contenedor siempre se pide._

Todos los comandos SQL de las secciones siguientes se ejecutan desde esta consola (`postgres=#`).

> La base `postgres` que aparece al conectarse es la base de mantenimiento interna de PostgreSQL (igual que `template0` y `template1`). **No usarla para aplicaciones.**

## Agregar una base de datos para un nuevo proyecto

Cada proyecto/aplicación que use este PostgreSQL tiene que tener **su propia base de datos y su propio usuario**, dueño de esa base de datos. Repetir estos pasos por cada proyecto nuevo.

Reemplazar `mi_proyecto_db`, `mi_proyecto_user` y `una_password_segura` por los valores del proyecto.

### 1. Crear el usuario

```sql
postgres=# CREATE USER mi_proyecto_user WITH PASSWORD 'una_password_segura';
```

### 2. Crear la base de datos con ese usuario como dueño

```sql
postgres=# CREATE DATABASE mi_proyecto_db OWNER mi_proyecto_user;
```

_Al ser dueño de la base (y por lo tanto del esquema `public`), el usuario puede crear, modificar y borrar tablas sin permisos adicionales._

### 3. Impedir que otros usuarios se conecten a esa base

Por defecto PostgreSQL permite que **cualquier usuario** se conecte a cualquier base (aunque no pueda leer las tablas). Para aislar los proyectos entre sí:

```sql
postgres=# REVOKE CONNECT, TEMPORARY ON DATABASE mi_proyecto_db FROM PUBLIC;
```

_El dueño (`mi_proyecto_user`) se sigue pudiendo conectar. Si otro usuario necesita acceso a esta base, dárselo explícitamente con `GRANT CONNECT ON DATABASE mi_proyecto_db TO otro_user;`._

### 4. Verificar

```sql
postgres=# \l mi_proyecto_db
```

Probar la conexión con el nuevo usuario:

```bash
$ docker compose exec -it postgres_db psql -h localhost -U mi_proyecto_user -d mi_proyecto_db
Contraseña para usuario mi_proyecto_user: # una_password_segura
```

Desde la aplicación (o desde el host) los datos de conexión quedan:

| Dato          | Valor                                     |
| ------------- | ----------------------------------------- |
| Host          | IP del servidor (`127.0.0.1` si es local) |
| Puerto        | `DB_PORT` del _.env_                      |
| Base de datos | `mi_proyecto_db`                          |
| Usuario       | `mi_proyecto_user`                        |
| Contraseña    | `una_password_segura`                     |

> Las contraseñas usan `scram-sha-256` (el soporte de `md5` está deprecado desde PostgreSQL 18). Si una aplicación no conecta, verificar que su driver/cliente PostgreSQL esté actualizado.

## Ver bases de datos, usuarios y permisos

```sql
postgres=# \l                 -- bases de datos (con dueño y permisos de acceso)
postgres=# \du                -- usuarios
postgres=# \c mi_proyecto_db  -- conectarse a una base para ver sus tablas y permisos
mi_proyecto_db=# \dp          -- permisos de las tablas
```

Más consultas (quién se puede conectar a cada base, cómo leer los permisos, tamaños, dar/quitar permisos, conexiones activas, etc.) en **[CHEATSHEET.md](CHEATSHEET.md)**.

## Resetear o actualizar la contraseña de un usuario

Conectado como `postgres`:

```sql
postgres=# ALTER USER mi_proyecto_user WITH PASSWORD 'nueva_password';
```

Recordar actualizar la contraseña en la configuración de la aplicación que use ese usuario.

## Eliminar una base de datos y su usuario

**¡Cuidado! Esto borra los datos definitivamente.** Hacer un backup antes.

```sql
postgres=# DROP DATABASE mi_proyecto_db WITH (FORCE);
postgres=# DROP USER mi_proyecto_user;
```

_`WITH (FORCE)` desconecta a las sesiones abiertas contra esa base antes de borrarla._

## Resetear la contraseña de postgres

Como dentro del contenedor la conexión local no pide contraseña, se puede cambiar aunque se haya perdido:

```bash
$ docker compose exec -it postgres_db psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'nueva_password_postgres';"
$ # Actualizar DB_POSTGRES_PASSWORD en el .env para tenerla registrada
$ nano .env
```

## Backups

Los backups se hacen **por base de datos** con el usuario `postgres`, más un archivo aparte con los usuarios (roles) y sus contraseñas. Los archivos se guardan en **/backups**.

Para backups automáticos (a otro servidor con rsync o a AWS S3 Glacier Deep Archive), cómo descargarlos y cómo restaurarlos en una instancia nueva, ver **[BACKUPS.md](BACKUPS.md)**.

### Backup manual

Reemplazar `mi_proyecto_db` por la base de datos a respaldar.

```bash
$ docker compose exec -T postgres_db pg_dump -U postgres --clean --if-exists mi_proyecto_db | gzip > mi_proyecto_db-$(date +%Y%m%d-%H%M).sql.gz
```

### Restaurar backup

Ver [Restaurar en una instancia nueva](BACKUPS.md#restaurar-en-una-instancia-nueva).

## Actualizar desde una versión anterior de PostgreSQL

Los archivos de datos **no son compatibles entre versiones mayores** (por ejemplo 13 → 18): PostgreSQL 18 no puede arrancar con una carpeta **/database/data** creada por PostgreSQL 13. Hay que exportar todo con la versión vieja e importarlo en la nueva.

```bash
$ # 1. Con el contenedor VIEJO todavía corriendo, exportar todo (bases, usuarios y permisos)
$ docker compose exec -T postgres_db pg_dumpall -U $(grep DB_USER .env | cut -d= -f2) | gzip > pg_dumpall-$(date +%Y%m%d-%H%M).sql.gz

$ # 2. Detener y apartar los datos viejos (no borrarlos hasta verificar la migración)
$ docker compose down
$ sudo mv database database.old

$ # 3. Actualizar el proyecto (git pull) y crear el .env nuevo
$ cp .env.example .env
$ nano .env

$ # 4. Levantar PostgreSQL 18
$ docker compose up -d

$ # 5. Importar. El sed quita el locale viejo (es_ES.utf8, que la imagen nueva no tiene)
$ #    de los CREATE DATABASE, así las bases usan el ordenamiento ICU es-AR de la instancia nueva
$ gunzip -c pg_dumpall-AAAAMMDD-HHMM.sql.gz \
    | sed -E "/^CREATE DATABASE /s/ (LOCALE_PROVIDER|LOCALE|LC_COLLATE|LC_CTYPE|ICU_LOCALE|BUILTIN_LOCALE) = '?[^ ;']*'?//g" \
    | docker compose exec -T postgres_db psql -U postgres -d postgres
```

_El superusuario de la instalación vieja (`DB_USER`, ej: `demo_db`) y la base que se creaba por defecto (`DB_NAME`) quedan importados en la nueva. Revisar con `\du` y `\l`: si ya no se usan, borrarlos o quitarle `SUPERUSER` a ese usuario (`ALTER USER demo_db NOSUPERUSER;`)._

Verificar las bases y usuarios (`\l`, `\du`) y que las aplicaciones conecten. Recién después borrar **database.old** y el archivo de `pg_dumpall`.
