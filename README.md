# PostgreSQL Database Container

Contenedor Docker con PostgreSQL listo para usar, con volúmenes persistentes y soporte para backups automáticos.

## Quick Start

```bash
# 1. Configurar variables de entorno
cp .env.example .env
nano .env

# 2. Iniciar el contenedor
docker compose up -d
```

## Configuración

Edita el archivo `.env` con tus preferencias:

| Variable            | Descripción                | Valor por defecto |
| ------------------- | -------------------------- | ----------------- |
| `POSTGRES_DB`       | Nombre de la base de datos | `postgres`        |
| `POSTGRES_USER`     | Usuario administrador      | `postgres`        |
| `POSTGRES_PASSWORD` | Contraseña del usuario     | (configurar)      |
| `POSTGRES_PORT`     | Puerto expuesto            | `5432`            |

## Uso

### Conectar a PostgreSQL

```bash
docker compose exec -it postgres_db psql -U $POSTGRES_USER -d $POSTGRES_DB
```

### Ver logs

```bash
docker compose logs -f postgres_db
```

### Detener

```bash
docker compose down
```

## Backups

### Realizar backup manual

```bash
docker compose exec -it postgres_db bash
pg_dump -U $POSTGRES_USER $POSTGRES_DB > /backups/$POSTGRES_DB$(date "+%Y%m%d-%H_%M").sql
```

### Restaurar backup

```bash
docker compose exec -i postgres_db psql -U $POSTGRES_USER -d $POSTGRES_DB < backups/archivo_backup.sql
```

### Backups automáticos (CRON)

Ver [backup_cron.sh.example](backup_cron.sh.example) para configurar backups automáticos a un servidor remoto.

## Estructura

```
.
├── .env.example      # Plantilla de configuración
├── docker-compose.yml
├── backup_cron.sh.example
└── backups/         # Volumen para backups (se crea automáticamente)
```
