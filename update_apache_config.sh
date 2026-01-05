#!/bin/bash

# Script para actualizar la configuración de Apache2 en ceres
# con el dominio mobile.globalchat.org

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔧 Actualizando configuración Apache2 para mobilev1.globalchat.org${NC}"

ssh ceres.globalchat.org "sudo bash -c 'cat > /etc/apache2/sites-available/mobilev1.globalchat.org.conf << \"APACHE_EOF\"
<VirtualHost *:80>
    ServerName mobilev1.globalchat.org
    DocumentRoot /var/www/irc_app
    
    <Directory /var/www/irc_app>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Rewrite para Flutter Web
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # Cache para assets estáticos
    <LocationMatch \"\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$\">
        ExpiresActive On
        ExpiresDefault \"access plus 1 year\"
        Header set Cache-Control \"public, immutable\"
    </LocationMatch>
    
    # Headers de seguridad
    Header always set X-Frame-Options \"SAMEORIGIN\"
    Header always set X-Content-Type-Options \"nosniff\"
    Header always set X-XSS-Protection \"1; mode=block\"
</VirtualHost>
APACHE_EOF
'"

echo -e "${YELLOW}📝 Habilitando sitio...${NC}"
ssh ceres.globalchat.org "sudo a2ensite mobilev1.globalchat.org.conf"

echo -e "${YELLOW}🔍 Verificando configuración...${NC}"
ssh ceres.globalchat.org "sudo apache2ctl configtest"

echo -e "${YELLOW}🔄 Recargando Apache2...${NC}"
ssh ceres.globalchat.org "sudo systemctl reload apache2"

echo -e "${GREEN}✅ Configuración actualizada!${NC}"
echo ""
echo -e "${YELLOW}📝 Próximos pasos:${NC}"
echo "   1. Verificar DNS: dig mobilev1.globalchat.org"
echo "   2. Probar: http://mobilev1.globalchat.org"
echo "   3. Configurar SSL: sudo certbot --apache -d mobilev1.globalchat.org"

