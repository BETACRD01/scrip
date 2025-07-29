#!/bin/bash
# Script de despliegue para Ubuntu Server - Puerto 80

echo "Ì∫Ä Iniciando despliegue en puerto 80..."

# Verificar que estamos en el directorio correcto
if [[ ! -f "app/manage.py" ]]; then
    echo "‚ùå Error: No se encuentra manage.py. Ejecuta desde el directorio ra√≠z del proyecto."
    exit 1
fi

# Activar entorno virtual
source venv/bin/activate

# Actualizar c√≥digo
echo "Ì≥• Actualizando c√≥digo..."
git pull origin main

# Instalar dependencias
echo "Ì≥¶ Instalando dependencias..."
pip install -r requirements/base.txt

# Navegar a la carpeta de la app
cd app

# Ejecutar migraciones
echo "Ì∑ÉÔ∏è Ejecutando migraciones..."
python manage.py migrate

# Recopilar archivos est√°ticos
echo "Ì≥Å Recopilando archivos est√°ticos..."
python manage.py collectstatic --noinput

# Crear directorios de logs si no existen
echo "Ì≥ù Configurando logs..."
mkdir -p ../logs/{django,gunicorn,nginx}

# Volver al directorio ra√≠z
cd ..

# Configurar permisos
echo "Ì¥ê Configurando permisos..."
sudo chown -R www-data:www-data .
sudo chmod -R 755 .
sudo chmod -R 775 logs/
sudo chmod -R 775 media/

# Reiniciar servicios
echo "Ì¥Ñ Reiniciando servicios..."
sudo systemctl restart django
sudo systemctl restart nginx

# Verificar estado de servicios
echo "‚úÖ Verificando servicios..."
if sudo systemctl is-active --quiet django; then
    echo "‚úÖ Servicio Django: ACTIVO"
else
    echo "‚ùå Servicio Django: ERROR"
    sudo systemctl status django
fi

if sudo systemctl is-active --quiet nginx; then
    echo "‚úÖ Servicio Nginx: ACTIVO"
else
    echo "‚ùå Servicio Nginx: ERROR"
    sudo systemctl status nginx
fi

# Probar conexi√≥n en puerto 80
echo "Ìºê Probando conexi√≥n puerto 80..."
if curl -s --max-time 10 -I http://localhost | grep -q "HTTP"; then
    echo "‚úÖ Servidor respondiendo en puerto 80"
else
    echo "‚ùå Error: Servidor no responde en puerto 80"
    echo "Ì≤° Verifica los logs:"
    echo "   - Django: sudo journalctl -u django --no-pager -n 20"
    echo "   - Nginx: sudo tail -20 /var/log/nginx/error.log"
fi

echo ""
echo "Ìæâ Despliegue completado"
echo "Ìºê Tu aplicaci√≥n est√° disponible en:"
echo "   - http://localhost"
echo "   - http://$(hostname -I | awk '{print $1}')"
