#!/bin/bash

# Script de instalación completa para Django Stack en Ubuntu Server
# Ubuntu 24.04.2 LTS + Nginx + PostgreSQL + Gunicorn + Django

echo "=== Actualizando sistema ==="
sudo apt update && sudo apt upgrade -y

echo "=== Instalando dependencias del sistema ==="
sudo apt install -y python3 python3-pip python3-venv python3-dev
sudo apt install -y postgresql postgresql-contrib
sudo apt install -y nginx
sudo apt install -y git curl build-essential

echo "=== Configurando PostgreSQL ==="
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Crear usuario y base de datos PostgreSQL
sudo -u postgres psql << EOF
CREATE DATABASE django_db;
CREATE USER django_user WITH PASSWORD 'tu_password_seguro';
ALTER ROLE django_user SET client_encoding TO 'utf8';
ALTER ROLE django_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE django_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE django_db TO django_user;
\q
EOF

echo "=== Creando usuario del sistema para la aplicación ==="
sudo adduser --system --group --home /home/django django

echo "=== Configurando entorno virtual Python ==="
sudo -u django python3 -m venv /home/django/venv
sudo -u django /home/django/venv/bin/pip install --upgrade pip

echo "=== Instalando dependencias Python ==="
sudo -u django /home/django/venv/bin/pip install Django
sudo -u django /home/django/venv/bin/pip install gunicorn
sudo -u django /home/django/venv/bin/pip install psycopg2-binary
sudo -u django /home/django/venv/bin/pip install python-decouple

echo "=== Creando proyecto Django ==="
cd /home/django
sudo -u django /home/django/venv/bin/django-admin startproject myproject .

echo "=== Configurando Django settings.py ==="
sudo -u django tee /home/django/myproject/settings.py > /dev/null << 'EOF'
import os
from pathlib import Path
from decouple import config

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY', default='tu-clave-secreta-aqui')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = ['localhost', '127.0.0.1', 'tu-dominio.com']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'myproject.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
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

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'django_db',
        'USER': 'django_user',
        'PASSWORD': 'tu_password_seguro',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}

STATIC_URL = '/static/'
STATIC_ROOT = '/home/django/static/'

MEDIA_URL = '/media/'
MEDIA_ROOT = '/home/django/media/'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF

echo "=== Creando archivo .env ==="
sudo -u django tee /home/django/.env > /dev/null << 'EOF'
SECRET_KEY=tu-clave-secreta-muy-larga-y-aleatoria-aqui
DEBUG=False
EOF

echo "=== Aplicando migraciones ==="
cd /home/django
sudo -u django /home/django/venv/bin/python manage.py migrate
sudo -u django /home/django/venv/bin/python manage.py collectstatic --noinput

echo "=== Creando superusuario Django ==="
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | sudo -u django /home/django/venv/bin/python manage.py shell

echo "=== Configurando Gunicorn ==="
sudo tee /etc/systemd/system/gunicorn.service > /dev/null << 'EOF'
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
Type=notify
User=django
Group=django
RuntimeDirectory=gunicorn
WorkingDirectory=/home/django
ExecStart=/home/django/venv/bin/gunicorn \
          --access-logfile - \
          --workers 3 \
          --bind unix:/run/gunicorn/gunicorn.sock \
          myproject.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/gunicorn.socket > /dev/null << 'EOF'
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn/gunicorn.sock
SocketUser=www-data
SocketMode=660

[Install]
WantedBy=sockets.target
EOF

echo "=== Configurando Nginx ==="
sudo tee /etc/nginx/sites-available/django > /dev/null << 'EOF'
server {
    listen 80;
    server_name localhost tu-dominio.com;

    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        root /home/django;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        root /home/django;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn/gunicorn.sock;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

echo "=== Activando configuración Nginx ==="
sudo ln -sf /etc/nginx/sites-available/django /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "=== Iniciando servicios ==="
sudo systemctl daemon-reload
sudo systemctl start gunicorn.socket
sudo systemctl enable gunicorn.socket
sudo systemctl start gunicorn
sudo systemctl enable gunicorn
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "=== Configurando firewall ==="
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "=== Configurando permisos ==="
sudo chown -R django:django /home/django
sudo chmod -R 755 /home/django

echo "=== Verificando estado de servicios ==="
echo "Estado de Gunicorn:"
sudo systemctl status gunicorn --no-pager -l

echo "Estado de Nginx:"
sudo systemctl status nginx --no-pager -l

echo "Estado de PostgreSQL:"
sudo systemctl status postgresql --no-pager -l

echo "=== Instalación completada ==="
echo "Tu aplicación Django está corriendo en http://localhost"
echo "Panel de administración: http://localhost/admin"
echo "Usuario admin: admin / Contraseña: admin123"
echo ""
echo "Comandos útiles:"
echo "- Ver logs de Gunicorn: sudo journalctl -u gunicorn"
echo "- Reiniciar Gunicorn: sudo systemctl restart gunicorn"
echo "- Ver logs de Nginx: sudo tail -f /var/log/nginx/error.log"
echo "- Conectar a PostgreSQL: sudo -u postgres psql django_db"