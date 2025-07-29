# Mi Proyecto Django

## Configuración Local (Windows/Linux)

1. Clonar repositorio:
```bash
git clone <tu-repositorio>
cd <nombre-proyecto>
```

2. Ejecutar script de setup:
```bash
bash setup.sh
```

3. Activar entorno virtual:
```bash
# Windows (Git Bash)
source venv/Scripts/activate

# Ubuntu
source venv/bin/activate
```

4. Migrar base de datos:
```bash
cd app
python manage.py migrate
python manage.py createsuperuser
```

5. Ejecutar servidor:
```bash
python manage.py runserver
```

## Despliegue en Ubuntu Server - Puerto 80

1. Instalar dependencias del sistema:
```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv nginx postgresql postgresql-contrib
```

2. Configurar PostgreSQL:
```bash
sudo -u postgres createuser mi_usuario
sudo -u postgres createdb mi_proyecto_db
sudo -u postgres psql -c "ALTER USER mi_usuario PASSWORD 'mi_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mi_proyecto_db TO mi_usuario;"
```

3. Clonar y configurar proyecto:
```bash
git clone <tu-repositorio>
cd <nombre-proyecto>
cp .env.production .env
# Editar .env con tus valores reales
```

4. **IMPORTANTE - Actualizar rutas en archivos de configuración:**
```bash
# Obtener ruta actual del proyecto
PROJECT_PATH=$(pwd)
echo $PROJECT_PATH

# Actualizar configuración nginx
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/nginx/django.conf

# Actualizar configuración gunicorn
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/gunicorn/gunicorn.conf.py

# Actualizar servicio systemd
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/systemd/django.service
```

5. Configurar servicios en puerto 80:
```bash
# Copiar configuración nginx
sudo cp config/nginx/django.conf /etc/nginx/sites-available/django
sudo rm -f /etc/nginx/sites-enabled/default  # Remover sitio por defecto
sudo ln -s /etc/nginx/sites-available/django /etc/nginx/sites-enabled/

# Verificar configuración nginx
sudo nginx -t

# Configurar servicio Django
sudo cp config/systemd/django.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable django
```

6. Ejecutar despliegue:
```bash
bash scripts/deploy.sh
```

7. **Verificar que todo funciona en puerto 80:**
```bash
# Verificar servicios
sudo systemctl status django
sudo systemctl status nginx

# Ver logs si hay problemas
sudo journalctl -u django -f
sudo tail -f /var/log/nginx/error.log

# Probar conexión
curl -I http://localhost
curl -I http://tu-ip-servidor
```

## Comandos Útiles - Puerto 80

- **Setup completo puerto 80**: `sudo bash scripts/setup_port80.sh`
- **Despliegue**: `bash scripts/deploy.sh`
- **Backup**: `bash scripts/backup.sh`
- **Ver logs Django**: `sudo journalctl -u django -f`
- **Ver logs Nginx**: `sudo tail -f /var/log/nginx/error.log`
- **Reiniciar servicios**: `sudo systemctl restart django nginx`
- **Estado servicios**: `sudo systemctl status django nginx`
- **Ver puertos activos**: `sudo netstat -tlnp | grep :80`
- **Probar conexión**: `curl -I http://localhost`

## Resolución de Problemas Puerto 80

**Si no funciona en puerto 80:**

1. **Verificar que el puerto esté libre:**
```bash
sudo netstat -tlnp | grep :80
sudo fuser -k 80/tcp  # Liberar puerto si está ocupado
```

2. **Verificar permisos:**
```bash
sudo chown -R www-data:www-data /path/to/project
sudo chmod -R 755 /path/to/project
```

3. **Verificar configuración nginx:**
```bash
sudo nginx -t
sudo systemctl reload nginx
```

4. **Ver logs detallados:**
```bash
sudo journalctl -u django --no-pager -n 50
sudo journalctl -u nginx --no-pager -n 50
```
