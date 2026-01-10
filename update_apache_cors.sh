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
    Header always set Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization, Referer, Range, User-Agent, Cache-Control, Pragma"
    Header always set Access-Control-Allow-Credentials "true"
    Header always set Access-Control-Max-Age "86400"
    Header always set Access-Control-Expose-Headers "Content-Length, Content-Range, Accept-Ranges, Content-Type"
    
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
            
            # SPA routing - redirect all requests to index.html
            # PERO excluir archivos estáticos y archivos que existen físicamente
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            # Excluir rutas estáticas conocidas
            RewriteCond %{REQUEST_URI} !^/icons/
            RewriteCond %{REQUEST_URI} !^/assets/
            RewriteCond %{REQUEST_URI} !^/canvaskit/
            RewriteCond %{REQUEST_URI} !^/flutter_service_worker\.js$
            RewriteCond %{REQUEST_URI} !^/manifest\.json$
            RewriteCond %{REQUEST_URI} !^/favicon\.png$
            RewriteCond %{REQUEST_URI} !^/radio-proxy/
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
    
    # Regla de proxy para listen2myradio.com usando ProxyPass directo
    # La URL será: /radio-proxy/uk21freenew.listen2myradio.com/live.mp3?params
    # Usar RewriteRule con [P] para proxy dinámico
    # IMPORTANTE: El RewriteRule debe estar ANTES del LocationMatch para que funcione correctamente
    RewriteEngine On
    RewriteCond %{REQUEST_URI} ^/radio-proxy/([^/]+)/(.*)$
    RewriteCond %{REQUEST_METHOD} !OPTIONS
    RewriteRule ^/radio-proxy/([^/]+)/(.*)$ https://$1/$2 [P,L]
    ProxyPassReverse /radio-proxy/ https://uk21freenew.listen2myradio.com/
    
    <LocationMatch "^/radio-proxy/">
        # Headers CORS completos para el proxy (solo añadir, no sobrescribir)
        Header always append Access-Control-Allow-Origin "*"
        Header always append Access-Control-Allow-Methods "GET, OPTIONS, HEAD, POST"
        Header always append Access-Control-Allow-Headers "Range, Content-Type, Accept, Origin, User-Agent, Referer, X-Requested-With, Authorization, Cache-Control, Pragma"
        Header always append Access-Control-Expose-Headers "Content-Length, Content-Range, Accept-Ranges, Content-Type, Content-Encoding, Transfer-Encoding"
        Header always append Access-Control-Allow-Credentials "true"
        Header always append Access-Control-Max-Age "86400"
        
        # Headers específicos para listen2myradio.com (enviar al servidor)
        RequestHeader set User-Agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" env=LISTEN2MYRADIO
        RequestHeader set Referer "https://listen2myradio.com/" env=LISTEN2MYRADIO
        RequestHeader set Origin "https://listen2myradio.com" env=LISTEN2MYRADIO
        RequestHeader set Accept "audio/webm,audio/ogg,audio/*;q=0.9,application/ogg;q=0.7,video/*;q=0.6,*/*;q=0.5" env=LISTEN2MYRADIO
        RequestHeader set Accept-Encoding "identity" env=LISTEN2MYRADIO
        RequestHeader set Accept-Language "en-US,en;q=0.9" env=LISTEN2MYRADIO
        SetEnvIf Request_URI "^/radio-proxy/.*listen2myradio\.com.*" LISTEN2MYRADIO
        
        # NO sobrescribir Content-Type del servidor - dejar que el servidor lo establezca
        # NO establecer Cache-Control, Pragma, Expires - dejar que el servidor los establezca
        
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

