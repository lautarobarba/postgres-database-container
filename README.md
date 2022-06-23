# PostgreSQL Database Container

## Dependencias

- Docker

## Configuración

```bash
$ cp .env.example .env
$ nano .env
```

## Iniciar

```bash
$ docker compose up -d prod
```

_Quitando la opción *-d* se ven los logs del contenedor._

## Detener

```bash
$ # Si estan corriendo con logs visibles
$ #     detener con Ctr+C
$ docker compose down
```

## Database (PostgreSQL)

Toda la base de datos queda guardada en **/database/data**

Para conectarse a una terminal del contenedor (sólo para debug)

**CONTAINER_NAME**: está en el archivo _.env_

```bash
$ docker container exec -it CONTAINER_NAME bash
```

## Backups

Se creó un volumen para guardar los **backups**

### Realizar backup

Para hacer el backup tenemos que entrar a una shell del contenedor y generar el archivo de backup en la carpeta donde esta montado el volumen.
Usar los datos configurados previamente en .env

**CONTAINER_NAME**: está en el archivo _.env_

```bash
$ docker container exec -it CONTAINER_NAME bash
root@container:$ pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > backups/${POSTGRES_DB}$(date "+%Y%m%d-%H_%M").sql
root@container:$ exit
```

### Restaurar backup

Para restaurar el backup tenemos que entrar a una shell del contenedor y restaurar el backup que se encuentra en el volumen montado.

1. Hay que asegurarse de tener el backup en la carpeta **/backups**.

**CONTAINER_NAME**: está en el archivo _.env_

```bash
$ docker container exec -it CONTAINER_NAME bash
root@container:$ psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -f backup/NOMBRE_BACKUP.sql
root@container:$ exit
```
