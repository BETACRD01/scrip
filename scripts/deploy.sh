#!/bin/bash
# Script de despliegue para Ubuntu Server - Puerto 80

echo "� Iniciando despliegue en puerto 80..."

# Verificar que estamos en el directorio correcto
if [[ ! -f "app/manage.py" ]]; then
    echo "❌ Error: No se encuentra manage.py. Ejecuta desde el directorio raíz del proyecto."
    exit 1
fi

# Activar entorno virtual
source venv/bin/activate

# Actualizar código
echo "� Actualizando código..."
git pull origin main

# Instalar dependencias
echo "� Instalando dependencias..."
pip install -r requirements/base.txt

# Navegar a la carpeta de la app
cd app

# Ejecutar migraciones
echo "�️ Ejecutando migraciones..."
python manage.py migrate

# Recopilar archivos estáticos
echo "� Recopilando archivos estáticos..."
python manage.py collectstatic --noinput

# Crear directorios de logs si no existen
echo "� Configurando logs..."
mkdir -p ../logs/{django,gunicorn,nginx}

# Volver al directorio raíz
cd ..

# Configurar permisos
echo "� Configurando permisos..."
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 logs/
sudo chmod -R 775 media/

# Reiniciar servicios
echo "� Reiniciando servicios..."
sudo systemctl restart django
sudo systemctl restart nginx

# Verificar estado de servicios
echo "✅ Verificando servicios..."
if sudo systemctl is-active --quiet django; then
    echo "✅ Servicio Django: ACTIVO"
else
    echo "❌ Servicio Django: ERROR"
    sudo systemctl status django
fi

if sudo systemctl is-active --quiet nginx; then
    echo "✅ Servicio Nginx: ACTIVO"
else
    echo "❌ Servicio Nginx: ERROR"
    sudo systemctl status nginx
fi

# Probar conexión en puerto 80
echo "� Probando conexión puerto 80..."
if curl -s --max-time 10 -I http://localhost | grep -q "HTTP"; then
    echo "✅ Servidor respondiendo en puerto 80"
else
    echo "❌ Error: Servidor no responde en puerto 80"
    echo "� Verifica los logs:"
    echo "   - Django: sudo journalctl -u django --no-pager -n 20"
    echo "   - Nginx: sudo tail -20 /var/log/nginx/error.log"
fi

echo ""
echo "� Despliegue completado"
echo "� Tu aplicación está disponible en:"
echo "   - http://localhost"
echo "   - http://$(hostname -I | awk '{print $1}')"
