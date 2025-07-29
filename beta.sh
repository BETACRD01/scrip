#!/bin/bash

# Script instalación Django Stack - Puerto 8
# Ubuntu Server + Nginx + PostgreSQL + Gunicorn + Django

echo "=== Actualizando sistema ==="
sudo apt update && sudo apt upgrade -y

echo "=== Instalando dependencias ==="
sudo apt install -y python3 python3-pip python3-venv python3-dev postgresql postgresql-contrib nginx git curl build-essential

echo "=== Configurando PostgreSQL ==="
sudo systemctl start postgresql && sudo systemctl enable postgresql
sudo -u postgres createdb django_db
sudo -u postgres createuser django_user
sudo -u postgres psql -c "ALTER USER django_user WITH PASSWORD 'password123';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE django_db TO django_user;"

echo "=== Creando usuario sistema ==="
sudo adduser --system --group --home /home/django django

echo "=== Configurando entorno virtual ==="
sudo -u django python3 -m venv /home/django/venv
sudo -u django /home/django/venv/bin/pip install Django gunicorn psycopg2-binary

echo "=== Creando proyecto Django ==="
cd /home/django
sudo -u django /home/django/venv/bin/django-admin startproject myproject .

echo "=== Configurando Django settings ==="
sudo -u django tee /home/django/myproject/settings.py > /dev/null << 'EOF'
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = 'django-insecure-change-this-in-production'
DEBUG = True
ALLOWED_HOSTS = ['*']

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
        'PASSWORD': 'password123',
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

echo "=== Aplicando migraciones ==="
sudo -u django /home/django/venv/bin/python manage.py migrate
sudo -u django /home/django/venv/bin/python manage.py collectstatic --noinput

echo "=== Creando superusuario ==="
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | sudo -u django /home/django/venv/bin/python manage.py shell

echo "=== Configurando Gunicorn service ==="
sudo tee /etc/systemd/system/gunicorn.service > /dev/null << 'EOF'
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=django
Group=django
WorkingDirectory=/home/django
ExecStart=/home/django/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:8001 myproject.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Configurando Nginx - Puerto 8 ==="
sudo tee /etc/nginx/sites-available/django > /dev/null << 'EOF'
server {
    listen 8;
    server_name _;

    client_max_body_size 100M;

    location /static/ {
        alias /home/django/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /home/django/media/;
    }

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

echo "=== Activando sitio Nginx ==="
sudo ln -sf /etc/nginx/sites-available/django /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

echo "=== Probando configuración Nginx ==="
sudo nginx -t

echo "=== Iniciando servicios ==="
sudo systemctl daemon-reload
sudo systemctl start gunicorn && sudo systemctl enable gunicorn
sudo systemctl restart nginx && sudo systemctl enable nginx

echo "=== Configurando firewall ==="
sudo ufw allow 8/tcp
sudo ufw allow 22/tcp
sudo ufw --force enable

echo "=== Configurando permisos ==="
sudo chown -R django:django /home/django
sudo chmod -R 755 /home/django

echo "=== Verificando servicios ==="
echo "Estado Gunicorn:"
sudo systemctl status gunicorn --no-pager -l

echo "Estado Nginx:"
sudo systemctl status nginx --no-pager -l

echo "Estado PostgreSQL:"
sudo systemctl status postgresql --no-pager -l

echo "=== Instalación completada ==="
echo ""
echo "🚀 Tu aplicación Django está corriendo en:"
echo "   http://tu-ip:8"
echo "   http://localhost:8"
echo ""
echo "🔐 Panel admin:"
echo "   http://tu-ip:8/admin"
echo "   Usuario: admin"
echo "   Contraseña: admin123"
echo ""
echo "📋 Comandos útiles:"
echo "   sudo systemctl restart gunicorn"
echo "   sudo systemctl restart nginx"
echo "   sudo journalctl -u gunicorn -f"
echo "   sudo tail -f /var/log/nginx/error.log"
echo ""
echo "🔧 Configuración:"
echo "   Django: /home/django/"
echo "   Logs: sudo journalctl -u gunicorn"
echo "   Nginx config: /etc/nginx/sites-available/django"