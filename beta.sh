#!/bin/bash
# ===================================================
# CONFIGURACIÃ“N DJANGO PARA WINDOWS Y UBUNTU
# Compatible con Git Bash (Windows) y Ubuntu Server
# ===================================================

# Detectar sistema operativo
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
    VENV_ACTIVATE="venv/Scripts/activate"
    PYTHON_CMD="python"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="ubuntu"
    VENV_ACTIVATE="venv/bin/activate"
    PYTHON_CMD="python3"
else
    echo "âŒ Sistema operativo no soportado"
    exit 1
fi

echo "í´ Sistema detectado: $OS"
echo "í³ EstÃ¡s en: $(pwd)"

# 1. VERIFICAR HERRAMIENTAS NECESARIAS
echo "í´§ Verificando herramientas necesarias..."

if ! command -v $PYTHON_CMD &> /dev/null; then
    echo "âŒ Python no encontrado"
    if [[ "$OS" == "ubuntu" ]]; then
        echo "í²¡ Instala con: sudo apt update && sudo apt install python3 python3-pip python3-venv"
    fi
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "âŒ Git no encontrado"
    if [[ "$OS" == "ubuntu" ]]; then
        echo "í²¡ Instala con: sudo apt install git"
    fi
    exit 1
fi

echo "âœ… Herramientas verificadas"

# 2. CREAR ESTRUCTURA DE CARPETAS
echo "í·‚ï¸ Creando estructura de carpetas..."
mkdir -p {app,config/{nginx,gunicorn,systemd},logs/{nginx,django,gunicorn},static,media,backups,scripts,requirements,docs}

echo "âœ… Estructura creada:"
if command -v tree &> /dev/null; then
    tree . -L 2
else
    ls -la
fi

# 3. CREAR ENTORNO VIRTUAL
echo "í° Creando entorno virtual..."
$PYTHON_CMD -m venv venv

# 4. ACTIVAR ENTORNO VIRTUAL
echo "í´„ Activando entorno virtual..."
source $VENV_ACTIVATE

# Verificar activaciÃ³n
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "âœ… Entorno virtual activo: $VIRTUAL_ENV"
    echo "âœ… Python en uso: $(which python)"
    echo "âœ… VersiÃ³n: $(python --version)"
else
    echo "âŒ Error al activar entorno virtual"
    exit 1
fi

# 5. ACTUALIZAR PIP
echo "í³¦ Actualizando pip..."
python -m pip install --upgrade pip

# 6. INSTALAR DEPENDENCIAS
echo "í³š Instalando dependencias..."
pip install django gunicorn psycopg2-binary python-decouple pillow whitenoise

# Dependencias adicionales para Ubuntu
if [[ "$OS" == "ubuntu" ]]; then
    pip install supervisor
fi

# 7. GUARDAR DEPENDENCIAS
echo "í²¾ Guardando dependencias..."
pip freeze > requirements/base.txt

# Crear requirements especÃ­ficos
cat > requirements/production.txt << 'EOF'
-r base.txt
supervisor
nginx
EOF

cat > requirements/development.txt << 'EOF'
-r base.txt
django-debug-toolbar
pytest-django
black
flake8
EOF

# 8. CREAR PROYECTO DJANGO
echo "íº€ Creando proyecto Django..."
cd app
django-admin startproject core .

# Configurar settings bÃ¡sicos
echo "âš™ï¸ Configurando settings.py..."
cat > core/settings.py << 'EOF'
from pathlib import Path
from decouple import config
import os

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY', default='django-insecure-change-in-production')
DEBUG = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='localhost,127.0.0.1').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'whitenoise.runserver_nostatic',
    'django.contrib.staticfiles',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'core.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DATABASE_NAME', default='mi_proyecto_db'),
        'USER': config('DATABASE_USER', default='mi_usuario'),
        'PASSWORD': config('DATABASE_PASSWORD', default='mi_password'),
        'HOST': config('DATABASE_HOST', default='localhost'),
        'PORT': config('DATABASE_PORT', default='5432'),
    }
}

# Fallback a SQLite para desarrollo
if config('USE_SQLITE', default=False, cast=bool):
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'es-es'
TIME_ZONE = 'America/Guayaquil'
USE_I18N = True
USE_TZ = True

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR.parent / 'static'
STATICFILES_DIRS = [BASE_DIR / 'staticfiles']

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR.parent / 'media'

# WhiteNoise
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': BASE_DIR.parent / 'logs' / 'django' / 'django.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
EOF

cd ..

# 9. CREAR ARCHIVOS DE CONFIGURACIÃ“N
echo "í³ Creando archivos de configuraciÃ³n..."

# Archivo .env para desarrollo
cat > .env << 'EOF'
DEBUG=True
SECRET_KEY=django-insecure-cambia-esta-clave-en-produccion-12345
USE_SQLITE=True
DATABASE_NAME=mi_proyecto_db
DATABASE_USER=mi_usuario
DATABASE_PASSWORD=mi_password
DATABASE_HOST=localhost
DATABASE_PORT=5432
ALLOWED_HOSTS=localhost,127.0.0.1
EOF

# Archivo .env.production para Ubuntu Server
cat > .env.production << 'EOF'
DEBUG=False
SECRET_KEY=tu-clave-secreta-super-segura-aqui
USE_SQLITE=False
DATABASE_NAME=mi_proyecto_db
DATABASE_USER=mi_usuario
DATABASE_PASSWORD=mi_password_seguro
DATABASE_HOST=localhost
DATABASE_PORT=5432
ALLOWED_HOSTS=*
STATIC_URL=/static/
MEDIA_URL=/media/
EOF

# 10. CONFIGURACIÃ“N NGINX (Ubuntu) - Puerto 80
cat > config/nginx/django.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;  # Acepta cualquier dominio/IP
    
    client_max_body_size 100M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    location = /favicon.ico { 
        access_log off; 
        log_not_found off; 
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /static/ {
        alias /path/to/your/project/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # CompresiÃ³n
        gzip on;
        gzip_types text/css application/javascript image/svg+xml;
    }
    
    location /media/ {
        alias /path/to/your/project/media/;
        expires 30d;
        add_header Cache-Control "public";
    }
    
    # Bloquear acceso a archivos sensibles
    location ~ /\.(ht|env|git) {
        deny all;
        return 404;
    }
    
    location / {
        proxy_pass http://unix:/path/to/your/project/gunicorn.sock;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Health check endpoint
    location /health/ {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# 11. CONFIGURACIÃ“N GUNICORN
cat > config/gunicorn/gunicorn.conf.py << 'EOF'
import multiprocessing

bind = "unix:/path/to/your/project/gunicorn.sock"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2

# Logging
accesslog = "/path/to/your/project/logs/gunicorn/access.log"
errorlog = "/path/to/your/project/logs/gunicorn/error.log"
loglevel = "info"

# Process naming
proc_name = "django_app"

# Server mechanics
daemon = False
pidfile = "/path/to/your/project/gunicorn.pid"
user = "www-data"
group = "www-data"
tmp_upload_dir = None

# Security
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190
EOF

# 12. SERVICIO SYSTEMD (Ubuntu)
cat > config/systemd/django.service << 'EOF'
[Unit]
Description=Django Gunicorn daemon
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/path/to/your/project/app
Environment="PATH=/path/to/your/project/venv/bin"
ExecStart=/path/to/your/project/venv/bin/gunicorn --config /path/to/your/project/config/gunicorn/gunicorn.conf.py core.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# 13. SCRIPTS DE DESPLIEGUE
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
# Script de despliegue para Ubuntu Server - Puerto 80

echo "íº€ Iniciando despliegue en puerto 80..."

# Verificar que estamos en el directorio correcto
if [[ ! -f "app/manage.py" ]]; then
    echo "âŒ Error: No se encuentra manage.py. Ejecuta desde el directorio raÃ­z del proyecto."
    exit 1
fi

# Activar entorno virtual
source venv/bin/activate

# Actualizar cÃ³digo
echo "í³¥ Actualizando cÃ³digo..."
git pull origin main

# Instalar dependencias
echo "í³¦ Instalando dependencias..."
pip install -r requirements/base.txt

# Navegar a la carpeta de la app
cd app

# Ejecutar migraciones
echo "í·ƒï¸ Ejecutando migraciones..."
python manage.py migrate

# Recopilar archivos estÃ¡ticos
echo "í³ Recopilando archivos estÃ¡ticos..."
python manage.py collectstatic --noinput

# Crear directorios de logs si no existen
echo "í³ Configurando logs..."
mkdir -p ../logs/{django,gunicorn,nginx}

# Volver al directorio raÃ­z
cd ..

# Configurar permisos
echo "í´ Configurando permisos..."
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 logs/
sudo chmod -R 775 media/

# Reiniciar servicios
echo "í´„ Reiniciando servicios..."
sudo systemctl restart django
sudo systemctl restart nginx

# Verificar estado de servicios
echo "âœ… Verificando servicios..."
if sudo systemctl is-active --quiet django; then
    echo "âœ… Servicio Django: ACTIVO"
else
    echo "âŒ Servicio Django: ERROR"
    sudo systemctl status django
fi

if sudo systemctl is-active --quiet nginx; then
    echo "âœ… Servicio Nginx: ACTIVO"
else
    echo "âŒ Servicio Nginx: ERROR"
    sudo systemctl status nginx
fi

# Probar conexiÃ³n en puerto 80
echo "í¼ Probando conexiÃ³n puerto 80..."
if curl -s --max-time 10 -I http://localhost | grep -q "HTTP"; then
    echo "âœ… Servidor respondiendo en puerto 80"
else
    echo "âŒ Error: Servidor no responde en puerto 80"
    echo "í²¡ Verifica los logs:"
    echo "   - Django: sudo journalctl -u django --no-pager -n 20"
    echo "   - Nginx: sudo tail -20 /var/log/nginx/error.log"
fi

echo ""
echo "í¾‰ Despliegue completado"
echo "í¼ Tu aplicaciÃ³n estÃ¡ disponible en:"
echo "   - http://localhost"
echo "   - http://$(hostname -I | awk '{print $1}')"
EOF

cat > scripts/backup.sh << 'EOF'
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
EOF

chmod +x scripts/*.sh

# 14. CREAR .GITIGNORE
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
ENV/
env/
.venv

# Django
*.log
local_settings.py
db.sqlite3
media/
staticfiles/
static/

# Environment variables
.env
.env.production

# IDEs
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Backups
backups/

# Temporary files
*.tmp
*.temp
gunicorn.pid
gunicorn.sock
EOF

# 15. CREAR README
cat > README.md << 'EOF'
# Mi Proyecto Django

## ConfiguraciÃ³n Local (Windows/Linux)

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

4. **IMPORTANTE - Actualizar rutas en archivos de configuraciÃ³n:**
```bash
# Obtener ruta actual del proyecto
PROJECT_PATH=$(pwd)
echo $PROJECT_PATH

# Actualizar configuraciÃ³n nginx
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/nginx/django.conf

# Actualizar configuraciÃ³n gunicorn
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/gunicorn/gunicorn.conf.py

# Actualizar servicio systemd
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/systemd/django.service
```

5. Configurar servicios en puerto 80:
```bash
# Copiar configuraciÃ³n nginx
sudo cp config/nginx/django.conf /etc/nginx/sites-available/django
sudo rm -f /etc/nginx/sites-enabled/default  # Remover sitio por defecto
sudo ln -s /etc/nginx/sites-available/django /etc/nginx/sites-enabled/

# Verificar configuraciÃ³n nginx
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

# Probar conexiÃ³n
curl -I http://localhost
curl -I http://tu-ip-servidor
```

## Comandos Ãštiles

- **Backup**: `bash scripts/backup.sh`
- **Ver logs**: `tail -f logs/gunicorn/error.log`
- **Reiniciar servicio**: `sudo systemctl restart django`
EOF

echo ""
echo "í¾‰ Â¡CONFIGURACIÃ“N COMPLETADA!"
echo ""
echo "í³‹ PRÃ“XIMOS PASOS:"
echo ""
if [[ "$OS" == "windows" ]]; then
    echo "1. cd app"
    echo "2. python manage.py migrate"
    echo "3. python manage.py createsuperuser"
    echo "4. python manage.py runserver"
    echo ""
    echo "í¼ Tu servidor estarÃ¡ en: http://127.0.0.1:8000"
else
    echo "1. Edita .env con tus configuraciones"
    echo "2. cd app && python manage.py migrate"
    echo "3. python manage.py createsuperuser"
    echo "4. bash ../scripts/deploy.sh"
    echo ""
    echo "í³– Lee el README.md para mÃ¡s detalles"
fi

echo ""
echo "í³ Estructura creada:"
if command -v tree &> /dev/null; then
    tree . -I 'venv|__pycache__'
else
    find . -name 'venv' -prune -o -name '__pycache__' -prune -o -type d -print | sort
fi
