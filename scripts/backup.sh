#!/bin/bash
# Script de backup para Ubuntu Server

BACKUP_DIR="../backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "í²¾ Creando backup..."

# Backup de base de datos
pg_dump mi_proyecto_db > $BACKUP_DIR/db_backup_$DATE.sql

# Backup de archivos media
tar -czf $BACKUP_DIR/media_backup_$DATE.tar.gz ../media/

echo "âœ… Backup completado: $DATE"
