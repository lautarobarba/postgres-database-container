# PostgreSQL Database Container

PostgreSQL with Docker

# Dependencias

- Docker

# Ejecución

Copiar el archivo .env.example o renombrarlo a .env

```bash
$ cp .env.example .env
```

Editar el contenido de env

```bash
$ nano .env
```

Opcional: Cambiar puerto del host y/o nombre del contenedor

```bash
$ nano docker-compose.yml
$ # En la seccion container_name puede se puede cambiar el nombre del contenedor
$ # En la seccion ports se puede cambiar el puerto del host:
$ # 	PUERTO_HOST:5432
```

Iniciar los contenedores para producción (logs ocultos)

```bash
$ docker-compose up -d
```

Iniciar los contenedores para desarrollo (logs visibles)

```bash
$ docker-compose up
```

## Detener ejecución

```bash
$ # Si estan corriendo para desarrollo
$ #     detener con Ctr+C
$ docker-compose down
```

### Notas

Antes de ejecutar asegurarse de tener docker corriendo

```bash
$ sudo systemctl status docker.service
# O el administrador de servicios que corresponda para el sistema
```

Si no esta _active (running)_ iniciarlo

```bash
$ sudo systemctl start docker.service
$ sudo systemctl enable docker.service
# O el administrador de servicios que corresponda para el sistema
```

## Database (PostgreSQL)

Toda la base de datos queda guardada en **/database/data**

Para conectarse a una terminal del contenedor (sólo para debug)

**NOMBRE_CONTENEDOR**: está en el archivo _docker-compose linea_ **container_name**

```bash
$ docker container exec -it NOMBRE_CONTENEDOR bash
```

## Backups

Se creó un volumen para guardar los **backups**

### Realizar backup

Para hacer el backup tenemos que entrar a una shell del contenedor y generar el archivo de backup en la carpeta donde esta montado el volumen.
Usar los datos configurados previamente en .env

**NOMBRE_CONTENEDOR**: está en el archivo _docker-compose linea_ **container_name**
**POSTGRES_USER**: está en el archivo _.env_
**POSTGRES_DB**: está en el archivo _.env_

```bash
$ docker container exec -it NOMBRE_CONTENEDOR bash
root# pg_dump -U POSTGRES_USER POSTGRES_DB > backups/$(date "+%Y%m%d-%H:%M").sql
root# exit
```

### Restaurar backup

Para restaurar el backup tenemos que entrar a una shell del contenedor y restaurar el backup que se encuentra en el volumen montado.
1° Hay que asegurarse de tener el backup en la carpeta local backups
2° Detener el contenedor de docker si esta corriendo
3° Eliminar la carpeta database que tiene la base de datos actual
4° Volver a iniciar el contenedor

**NOMBRE_CONTENEDOR**: está en el archivo _docker-compose linea_ **container_name**
**POSTGRES_USER**: está en el archivo _.env_
**NOMBRE_DEL_BACKUP**: archivo ubicado en _backups_

```bash
$ docker-compose down
$ sudo rm -r database
$ docker-compose up -d
$ docker container exec -it NOMBRE_CONTENEDOR bash
root# cd backups
root# psql -U POSTGRES_USER
usuario_postgres=# \conninfo
usuario_postgres=# \i **NOMBRE_DEL_BACKUP.sql**
usuario_postgres=# \q
root# exit
```
