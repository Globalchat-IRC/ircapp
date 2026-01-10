#!/bin/bash

# Script para actualizar la configuración de Apache2 con CORS
# para mobilev1.globalchat.org

set -e

echo "🔧 Configurando Apache2 con CORS para mobilev1.globalchat.org..."

# Verificar que estamos en el servidor correcto
if [ ! -d "/etc/apache2/sites-available" ]; then
    echo "❌ Error: Este script debe ejecutarse en el servidor con Apache2"
    exit 1
fi

# Crear configuración del VirtualHost con CORS
CONFIG_FILE="/etc/apache2/sites-available/mobilev1-globalchat-org.conf"

sudo tee "$CONFIG_FILE" > /dev/null <<'EOF'
<VirtualHost *:443>
    ServerName mobilev1.globalchat.org
    DocumentRoot /var/www/irc_app
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/mobilev1.globalchat.org/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/mobilev1.globalchat.org/privkey.pem
    
    # CORS Configuration - Permitir peticiones desde dominios de GlobalChat
    # Detectar origen basado en el header Origin o Referer
    SetEnvIf Origin "^https?://(www\.)?(webchat|mobilev1|irc|registro-chan|xmlrpc)\.globalchat\.org" CORS_ALLOWED=1
    SetEnvIf Referer "^https?://(www\.)?(webchat|mobilev1|irc|registro-chan|xmlrpc)\.globalchat\.org" CORS_ALLOWED=1
    
    # Headers CORS
    Header always set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS, HEAD"
    Header always set Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization, Referer"
    Header always set Access-Control-Allow-Credentials "true"
    Header always set Access-Control-Max-Age "3600"
    
    # Permitir origen basado en el header Origin si es de GlobalChat
    SetEnvIf Origin "^https?://(www\.)?(webchat|mobilev1|irc|registro-chan|xmlrpc)\.globalchat\.org" CORS_ORIGIN=$0
    Header always set Access-Control-Allow-Origin "%{CORS_ORIGIN}e" env=CORS_ORIGIN
    
    # Fallback: permitir todos los dominios de GlobalChat
    Header always set Access-Control-Allow-Origin "*"
    
    <Directory /var/www/irc_app>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
        
        # Manejar preflight OPTIONS requests
        <IfModule mod_rewrite.c>
            RewriteEngine On
            RewriteBase /
            
            # Responder a OPTIONS con 200 OK y headers CORS
            RewriteCond %{REQUEST_METHOD} OPTIONS
            RewriteRule ^(.*)$ $1 [R=200,L]
            
            # Excluir Service Worker y otros archivos estáticos del SPA routing
            RewriteCond %{REQUEST_URI} !^/flutter_service_worker\.js
            RewriteCond %{REQUEST_URI} !^/manifest\.json
            RewriteCond %{REQUEST_URI} !^/favicon\.png
            RewriteCond %{REQUEST_URI} !^/icons/
            RewriteCond %{REQUEST_URI} !^/assets/
            
            # SPA routing - redirect all requests to index.html
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteRule ^ index.html [L]
        </IfModule>
        
        # Service Worker - MIME type correcto
        <FilesMatch "flutter_service_worker\.js">
            Header set Content-Type "application/javascript"
            Header set Service-Worker-Allowed "/"
        </FilesMatch>
    </Directory>
    
    # Cache static assets
    <LocationMatch "\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$">
        ExpiresActive On
        ExpiresDefault "access plus 1 year"
    </LocationMatch>
    
    # Proxy para streaming de radio (evitar problemas CORS)
    ProxyPreserveHost Off
    ProxyRequests Off
    SSLProxyEngine On
    SSLProxyVerify none
    SSLProxyCheckPeerCN off
    SSLProxyCheckPeerName off
    
    # Regla de proxy para listen2myradio.com usando ProxyPass
    # La URL será: /radio-proxy/uk21freenew.listen2myradio.com/live.mp3?params
    <Proxy https://uk21freenew.listen2myradio.com/*>
        Order allow,deny
        Allow from all
    </Proxy>
    
    ProxyPass /radio-proxy/uk21freenew.listen2myradio.com/ https://uk21freenew.listen2myradio.com/
    ProxyPassReverse /radio-proxy/uk21freenew.listen2myradio.com/ https://uk21freenew.listen2myradio.com/
    
    <LocationMatch "^/radio-proxy/">
        # Headers CORS para el proxy
        Header always set Access-Control-Allow-Origin "*"
        Header always set Access-Control-Allow-Methods "GET, OPTIONS, HEAD"
        Header always set Access-Control-Allow-Headers "Range, Content-Type, Accept, Origin, User-Agent"
        Header always set Access-Control-Expose-Headers "Content-Length, Content-Range, Accept-Ranges"
        
        # Headers para streaming
        Header always set Cache-Control "no-cache, no-store, must-revalidate"
        Header always set Pragma "no-cache"
        Header always set Expires "0"
        
        # Manejar preflight OPTIONS
        RewriteEngine On
        RewriteCond %{REQUEST_METHOD} OPTIONS
        RewriteRule ^(.*)$ $1 [R=200,L]
    </LocationMatch>
</VirtualHost>

# HTTP to HTTPS redirect
<VirtualHost *:80>
    ServerName mobilev1.globalchat.org
    Redirect permanent / https://mobilev1.globalchat.org/
</VirtualHost>
EOF

echo "✅ Configuración creada en $CONFIG_FILE"

# Habilitar módulos necesarios
echo "🔧 Habilitando módulos de Apache2..."
sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod env
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_connect

# Habilitar el sitio
echo "🔧 Habilitando sitio..."
sudo a2ensite mobilev1-globalchat-org.conf

# Verificar configuración
echo "🔍 Verificando configuración de Apache2..."
sudo apache2ctl configtest

if [ $? -eq 0 ]; then
    echo "✅ Configuración válida. Recargando Apache2..."
    sudo systemctl reload apache2
    echo "✅ Apache2 recargado exitosamente"
    echo ""
    echo "🌐 CORS configurado para:"
    echo "   - webchat.globalchat.org"
    echo "   - mobilev1.globalchat.org"
    echo "   - irc.globalchat.org"
    echo "   - registro-chan.globalchat.org"
    echo "   - xmlrpc.globalchat.org"
    echo ""
    echo "✅ Soporte para método OPTIONS (preflight) habilitado"
else
    echo "❌ Error en la configuración de Apache2"
    exit 1
fi

