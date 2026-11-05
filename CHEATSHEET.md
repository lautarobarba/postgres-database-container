# Cheatsheet: bases de datos, usuarios y permisos

Consultas útiles para ver qué bases de datos hay, qué usuarios existen y qué puede hacer cada uno. Todas se ejecutan conectado como `postgres` (ver [Conectarse como postgres](README.md#conectarse-como-postgres)):

```bash
$ docker compose exec -it postgres_db psql -U postgres
```

Reemplazar `mi_proyecto_db` y `mi_proyecto_user` por los valores reales.

## Comandos básicos de psql

Los comandos que empiezan con `\` son de `psql` (no son SQL) y no llevan `;` al final.

| Comando              | Descripción                                                          |
| -------------------- | -------------------------------------------------------------------- |
| `\?`                 | Ayuda de los comandos `\` de psql.                                   |
| `\h GRANT`           | Ayuda de la sintaxis de un comando SQL.                              |
| `\c mi_proyecto_db`  | Cambiar a otra base de datos.                                        |
| `\conninfo`          | Ver a qué base y con qué usuario estoy conectado.                    |
| `\x auto`            | Mostrar las filas en vertical cuando no entran en pantalla.          |
| `\q`                 | Salir.                                                               |

> En PostgreSQL cada conexión es a **una** base de datos. Las tablas, esquemas y sus permisos sólo se ven conectado a esa base (`\c mi_proyecto_db`). Usuarios y bases de datos, en cambio, se ven desde cualquier base.

## Bases de datos

Listar todas las bases de datos (con dueño, codificación y permisos de acceso):

```sql
postgres=# \l
```

_`postgres`, `template0` y `template1` son bases de datos internas de PostgreSQL._

Lo mismo agregando el tamaño de cada base:

```sql
postgres=# \l+
```

Bases de datos de proyectos con su dueño y tamaño, de la más grande a la más chica:

```sql
postgres=# SELECT datname AS db,
                  pg_get_userbyid(datdba) AS dueño,
                  pg_size_pretty(pg_database_size(datname)) AS tamaño
           FROM pg_database
           WHERE NOT datistemplate AND datname <> 'postgres'
           ORDER BY pg_database_size(datname) DESC;
```

Dentro de una base de datos (primero `\c mi_proyecto_db`):

```sql
mi_proyecto_db=# \dn          -- esquemas
mi_proyecto_db=# \dt          -- tablas del esquema public
mi_proyecto_db=# \dt *.*      -- tablas de todos los esquemas (incluye las internas)
mi_proyecto_db=# \dt+         -- tablas con su tamaño
```

Las 20 tablas más grandes de la base actual:

```sql
mi_proyecto_db=# SELECT schemaname AS esquema, relname AS tabla,
                        pg_size_pretty(pg_total_relation_size(relid)) AS tamaño,
                        n_live_tup AS filas_aprox
                 FROM pg_stat_user_tables
                 ORDER BY pg_total_relation_size(relid) DESC
                 LIMIT 20;
```

## Usuarios

Listar los usuarios y sus atributos:

```sql
postgres=# \du
```

_Los roles que empiezan con `pg_` son roles internos de PostgreSQL y no se muestran con `\du` (con `\duS` sí)._

Lo mismo como consulta, con más detalle:

```sql
postgres=# SELECT rolname AS usuario, rolcanlogin AS puede_conectarse, rolsuper AS superusuario,
                  rolcreatedb AS crea_db, rolcreaterole AS crea_roles,
                  rolconnlimit AS limite_conexiones, rolvaliduntil AS vence
           FROM pg_roles
           WHERE rolname NOT LIKE 'pg\_%'
           ORDER BY rolname;
```

> En PostgreSQL usuarios y grupos son lo mismo: **roles**. Un "usuario" es un rol con `LOGIN`. Un rol puede ser miembro de otro y heredar sus permisos.

Qué roles tiene asignados cada usuario (membresías):

```sql
postgres=# SELECT m.rolname AS usuario, r.rolname AS es_miembro_de
           FROM pg_auth_members am
           JOIN pg_roles r ON r.oid = am.roleid
           JOIN pg_roles m ON m.oid = am.member
           WHERE m.rolname NOT LIKE 'pg\_%'
           ORDER BY 1, 2;
```

_Prestar atención a `pg_read_all_data` y `pg_write_all_data`: dan lectura/escritura sobre **todas** las tablas de **todas** las bases._

Ver con qué usuario estoy conectado:

```sql
postgres=# SELECT current_user, current_database();
```

## Permisos

Los permisos en PostgreSQL van por capas. Para leer una tabla, un usuario necesita las tres:

1. **Base de datos**: `CONNECT` (poder conectarse).
2. **Esquema**: `USAGE` (poder ver lo que hay en el esquema). En `public` todos los usuarios lo tienen por defecto; en otros esquemas hay que darlo.
3. **Tabla**: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, etc.

El **dueño** de un objeto (base, esquema, tabla) tiene todos los permisos sobre él sin necesidad de `GRANT`. Los **superusuarios** saltean todos los controles.

### Cómo leer la columna "Access privileges"

`\l`, `\dn+` y `\dp` muestran los permisos en formato `usuario=permisos/quien_los_dio`:

```
=c/postgres              → PUBLIC (todos los usuarios) tiene CONNECT, otorgado por postgres
postgres=CTc/postgres    → postgres tiene CREATE, TEMPORARY y CONNECT
app=arwd/dueño           → app tiene SELECT (r), INSERT (a), UPDATE (w) y DELETE (d)
```

| Letra | Permiso    | Letra | Permiso    |
| ----- | ---------- | ----- | ---------- |
| `r`   | SELECT     | `D`   | TRUNCATE   |
| `a`   | INSERT     | `x`   | REFERENCES |
| `w`   | UPDATE     | `t`   | TRIGGER    |
| `d`   | DELETE     | `U`   | USAGE      |
| `C`   | CREATE     | `c`   | CONNECT    |
| `T`   | TEMPORARY  | `X`   | EXECUTE    |
| `m`   | MAINTAIN   |       |            |

_Si la columna está **vacía** significa que tiene los permisos por defecto: el dueño todo, y para una base de datos, **cualquier usuario puede conectarse** (por eso en el README se hace `REVOKE CONNECT ... FROM PUBLIC`)._

### Quién se puede conectar a cada base de datos

```sql
postgres=# SELECT d.datname AS db, r.rolname AS usuario,
                  r.rolsuper AS superusuario,
                  pg_get_userbyid(d.datdba) = r.rolname AS dueño
           FROM pg_database d
           CROSS JOIN pg_roles r
           WHERE NOT d.datistemplate
             AND r.rolcanlogin
             AND has_database_privilege(r.oid, d.oid, 'CONNECT')
           ORDER BY d.datname, r.rolname;
```

### Superusuarios y permisos globales

Usuarios que pueden hacer cualquier cosa en todo el servidor. Normalmente sólo debería aparecer `postgres`:

```sql
postgres=# SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolbypassrls
           FROM pg_roles
           WHERE rolname NOT LIKE 'pg\_%'
             AND (rolsuper OR rolcreaterole OR rolcreatedb OR rolbypassrls);
```

### Permisos dentro de una base de datos

Conectado a la base (`\c mi_proyecto_db`):

```sql
mi_proyecto_db=# \dn+         -- esquemas, su dueño y permisos
mi_proyecto_db=# \dp          -- permisos de tablas, vistas y secuencias (igual que \z)
mi_proyecto_db=# \ddp         -- permisos por defecto para las tablas que se creen a futuro
```

Resumen de permisos por usuario sobre las tablas de la base actual:

```sql
mi_proyecto_db=# SELECT grantee AS usuario, table_schema AS esquema,
                        string_agg(DISTINCT privilege_type, ', ') AS permisos,
                        COUNT(DISTINCT table_name) AS tablas
                 FROM information_schema.table_privileges
                 WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
                 GROUP BY grantee, table_schema
                 ORDER BY grantee, table_schema;
```

Dueño de cada tabla de la base actual:

```sql
mi_proyecto_db=# SELECT schemaname AS esquema, tablename AS tabla, tableowner AS dueño
                 FROM pg_tables
                 WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
                 ORDER BY 1, 2;
```

## Dar y quitar permisos

### Todos los permisos (usuario dueño del proyecto)

La forma recomendada es que el usuario sea **dueño** de la base (ver [Agregar una base de datos para un nuevo proyecto](README.md#agregar-una-base-de-datos-para-un-nuevo-proyecto)). Para cambiar el dueño de una base existente:

```sql
postgres=# ALTER DATABASE mi_proyecto_db OWNER TO mi_proyecto_user;
postgres=# \c mi_proyecto_db
mi_proyecto_db=# REASSIGN OWNED BY usuario_anterior TO mi_proyecto_user;  -- tablas, secuencias, etc.
```

_El esquema `public` pertenece a `pg_database_owner` (el dueño de la base, sea quien sea), así que cambia solo. `ALTER DATABASE ... OWNER` en cambio no cambia el dueño de las tablas que ya existen; para eso es el `REASSIGN OWNED`. **No usar `REASSIGN OWNED BY postgres`**: intentaría pasar también los objetos internos del sistema._

### Lectura y escritura de datos para otro usuario

Sin poder crear, modificar ni borrar tablas. Reemplazar `otro_user`:

```sql
postgres=# GRANT CONNECT ON DATABASE mi_proyecto_db TO otro_user;
postgres=# \c mi_proyecto_db
mi_proyecto_db=# GRANT USAGE ON SCHEMA public TO otro_user;
mi_proyecto_db=# GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO otro_user;
mi_proyecto_db=# GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO otro_user;
mi_proyecto_db=# -- Para que también aplique a las tablas que mi_proyecto_user cree en el futuro:
mi_proyecto_db=# ALTER DEFAULT PRIVILEGES FOR ROLE mi_proyecto_user IN SCHEMA public
                     GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO otro_user;
mi_proyecto_db=# ALTER DEFAULT PRIVILEGES FOR ROLE mi_proyecto_user IN SCHEMA public
                     GRANT USAGE, SELECT ON SEQUENCES TO otro_user;
```

_`GRANT ... ON ALL TABLES` sólo afecta a las tablas que existen **ahora**. Sin el `ALTER DEFAULT PRIVILEGES`, las tablas nuevas (por ejemplo, creadas por una migración) no van a ser accesibles para `otro_user`._

### Sólo lectura (por ejemplo para reportes o una herramienta de BI)

```sql
postgres=# CREATE USER mi_proyecto_readonly WITH PASSWORD 'una_password_segura';
postgres=# GRANT CONNECT ON DATABASE mi_proyecto_db TO mi_proyecto_readonly;
postgres=# \c mi_proyecto_db
mi_proyecto_db=# GRANT USAGE ON SCHEMA public TO mi_proyecto_readonly;
mi_proyecto_db=# GRANT SELECT ON ALL TABLES IN SCHEMA public TO mi_proyecto_readonly;
mi_proyecto_db=# ALTER DEFAULT PRIVILEGES FOR ROLE mi_proyecto_user IN SCHEMA public
                     GRANT SELECT ON TABLES TO mi_proyecto_readonly;
```

> Existe el rol `pg_read_all_data` (`GRANT pg_read_all_data TO usuario;`), pero da lectura sobre **todas las bases** del servidor. Para un solo proyecto usar los `GRANT` de arriba.

### Quitar permisos

```sql
mi_proyecto_db=# REVOKE INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM otro_user;
mi_proyecto_db=# REVOKE ALL ON ALL TABLES IN SCHEMA public FROM otro_user;
mi_proyecto_db=# ALTER DEFAULT PRIVILEGES FOR ROLE mi_proyecto_user IN SCHEMA public
                     REVOKE ALL ON TABLES FROM otro_user;
mi_proyecto_db=# \c postgres
postgres=# REVOKE CONNECT ON DATABASE mi_proyecto_db FROM otro_user;
```

_`GRANT` y `REVOKE` aplican inmediatamente, incluso en las conexiones ya abiertas._

### Borrar un usuario que tiene permisos u objetos

`DROP USER` falla con `role "..." cannot be dropped because some objects depend on it` si el usuario tiene permisos u objetos en alguna base. Primero hay que limpiarlo **en cada base** donde tenga algo:

```sql
postgres=# \c mi_proyecto_db
mi_proyecto_db=# REASSIGN OWNED BY otro_user TO mi_proyecto_user;  -- si es dueño de algo
mi_proyecto_db=# DROP OWNED BY otro_user;                          -- quita sus permisos
mi_proyecto_db=# \c postgres
postgres=# DROP USER otro_user;
```

### Bloquear / desbloquear un usuario sin borrarlo

```sql
postgres=# ALTER USER mi_proyecto_user NOLOGIN;
postgres=# ALTER USER mi_proyecto_user LOGIN;
```

_`NOLOGIN` impide conexiones nuevas; las abiertas siguen hasta que se cierren (ver [Conexiones activas](#conexiones-activas))._

Limitar la cantidad de conexiones simultáneas de un usuario:

```sql
postgres=# ALTER USER mi_proyecto_user CONNECTION LIMIT 20;  -- -1 = sin límite
```

## Conexiones activas

Quién está conectado ahora, desde dónde y a qué base de datos:

```sql
postgres=# SELECT pid, usename AS usuario, datname AS db, client_addr AS ip,
                  application_name AS app, state,
                  now() - query_start AS duracion, left(query, 60) AS consulta
           FROM pg_stat_activity
           WHERE backend_type = 'client backend'
           ORDER BY datname, usename;
```

Cantidad de conexiones por base y usuario:

```sql
postgres=# SELECT datname AS db, usename AS usuario, COUNT(*) AS conexiones
           FROM pg_stat_activity
           WHERE backend_type = 'client backend'
           GROUP BY 1, 2
           ORDER BY 3 DESC;
```

Cortar una consulta o una conexión (usar el `pid` de la consulta anterior):

```sql
postgres=# SELECT pg_cancel_backend(12345);     -- cancela la consulta en curso, la conexión sigue
postgres=# SELECT pg_terminate_backend(12345);  -- cierra la conexión
```

## Ejecutar consultas sin entrar a la consola

Útil para chequeos rápidos o scripts. Dentro del contenedor no pide contraseña:

```bash
$ docker compose exec postgres_db psql -U postgres -c '\l'
$ docker compose exec postgres_db psql -U postgres -c '\du'
$ docker compose exec postgres_db psql -U postgres -d mi_proyecto_db -c '\dp'
$ docker compose exec postgres_db psql -U postgres -c 'SELECT usename, datname, count(*) FROM pg_stat_activity GROUP BY 1, 2;'
```
