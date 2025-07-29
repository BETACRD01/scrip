#!/bin/bash
# Configuración específica para puerto 80 en Ubuntu Server

echo "� Configurando aplicación para puerto 80..."

# Verificar permisos de root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Este script debe ejecutarse como root (sudo)"
   echo "� Ejecuta: sudo bash scripts/setup_port80.sh"
   exit 1
fi

PROJECT_PATH=$(pwd)
echo "� Directorio del proyecto: $PROJECT_PATH"

# 1. Actualizar rutas en configuraciones
echo "⚙️ Actualizando rutas en configuraciones..."
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/nginx/django.conf
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/gunicorn/gunicorn.conf.py  
sed -i "s|/path/to/your/project|$PROJECT_PATH|g" config/systemd/django.service

# 2. Configurar Nginx para puerto 80
echo "� Configurando Nginx..."

# Detener nginx si está corriendo
systemctl stop nginx 2>/dev/null

# Remover configuración por defecto
rm -f /etc/nginx/sites-enabled/default

# Copiar nuestra configuración
cp config/nginx/django.conf /etc/nginx/sites-available/django
ln -sf /etc/nginx/sites-available/django /etc/nginx/sites-enabled/

# Verificar configuración nginx
nginx -t
if [[ $? -ne 0 ]]; then
    echo "❌ Error en configuración de Nginx"
    exit 1
fi

# 3. Configurar servicio systemd
echo "� Configurando servicio Django..."
cp config/systemd/django.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable django

# 4. Configurar permisos
echo "� Configurando permisos..."
chown -R www-data:www-data $PROJECT_PATH
chmod -R 755 $PROJECT_PATH
chmod -R 775 $PROJECT_PATH/logs/
chmod -R 775 $PROJECT_PATH/media/
chmod -R 775 $PROJECT_PATH/static/

# 5. Configurar firewall si existe
echo "�️ Configurando firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw --force enable
fi

# 6. Iniciar servicios
echo "� Iniciando servicios..."
systemctl start django
systemctl start nginx

# 7. Verificar servicios
echo "✅ Verificando servicios..."
sleep 3

if systemctl is-active --quiet django; then
    echo "✅ Django: FUNCIONANDO"
else
    echo "❌ Django: ERROR"
    journalctl -u django --no-pager -n 10
fi

if systemctl is-active --quiet nginx; then
    echo "✅ Nginx: FUNCIONANDO"  
else
    echo "❌ Nginx: ERROR"
    tail -10 /var/log/nginx/error.log
fi

# 8. Probar puerto 80
echo "� Probando puerto 80..."
sleep 2
if curl -s --max-time 5 -I http://localhost | grep -q "HTTP"; then
    echo "� ¡ÉXITO! Aplicación funcionando en puerto 80"
    echo ""
    echo "� Accede a tu aplicación en:"
    echo "   - http://localhost"
    echo "   - http://$(hostname -I | awk '{print $1}')"
else
    echo "❌ Error: No se puede acceder por puerto 80"
    echo ""
    echo "� Para debugging:"
    echo "   sudo journalctl -u django -f"
    echo "   sudo journalctl -u nginx -f"  
    echo "   sudo netstat -tlnp | grep :80"
fi

echo ""
echo "� Comandos útiles:"
echo "   - Ver logs Django: sudo journalctl -u django -f"
echo "   - Ver logs Nginx: sudo tail -f /var/log/nginx/error.log"
echo "   - Reiniciar Django: sudo systemctl restart django"
echo "   - Reiniciar Nginx: sudo systemctl restart nginx"
echo "   - Estado servicios: sudo systemctl status django nginx"
