#!/bin/bash

# Script para configurar el subdominio ai.globalchat.org en Ceres
# Uso recomendado desde tu Mac (con acceso SSH a Ceres):
#   ssh root@ceres.globalchat.org 'bash -s' < configurar_ai_globalchat.sh
#
# O, si ya tienes un túnel/alias configurado:
#   ssh ceres 'bash -s' < configurar_ai_globalchat.sh

set -e

echo "🚀 Configurando ai.globalchat.org en este servidor..."

WEB_ROOT="/var/www/ai.globalchat.org"
VHOST_CONF="/etc/apache2/sites-available/ai.globalchat.org.conf"

echo "📂 Creando directorio ${WEB_ROOT}..."
mkdir -p "${WEB_ROOT}"
chown -R www-data:www-data "${WEB_ROOT}"
chmod -R 755 "${WEB_ROOT}"

if [ ! -f "${WEB_ROOT}/index.html" ]; then
  echo "📝 Creando página de prueba en ${WEB_ROOT}/index.html..."
  cat > "${WEB_ROOT}/index.html" << 'EOF'
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <title>AI GlobalChat</title>
  <style>
    body {
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #111;
      color: #eee;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }
    .card {
      background: #1c1c1c;
      padding: 24px 32px;
      border-radius: 12px;
      box-shadow: 0 12px 40px rgba(0,0,0,0.6);
      text-align: center;
    }
    h1 {
      margin-top: 0;
      color: #ffd54f;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>AI GlobalChat</h1>
    <p>Subdominio <strong>ai.globalchat.org</strong> funcionando.</p>
  </div>
</body>
</html>
EOF
fi

echo "🧾 Creando VirtualHost en ${VHOST_CONF}..."
cat > "${VHOST_CONF}" << 'EOF'
<VirtualHost *:80>
    ServerName ai.globalchat.org

    DocumentRoot /var/www/ai.globalchat.org

    <Directory /var/www/ai.globalchat.org>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/ai.globalchat.org-error.log
    CustomLog ${APACHE_LOG_DIR}/ai.globalchat.org-access.log combined
</VirtualHost>
EOF

echo "🔗 Habilitando sitio ai.globalchat.org..."
a2ensite ai.globalchat.org.conf

echo "🔄 Recargando Apache..."
systemctl reload apache2

echo ""
echo "✅ Configuración básica de ai.globalchat.org completada."
echo "   - Raíz web: ${WEB_ROOT}"
echo "   - VirtualHost: ${VHOST_CONF}"
echo ""
echo "💡 Si el DNS de ai.globalchat.org ya apunta a este servidor, puedes activar HTTPS con:"
echo "   certbot --apache -d ai.globalchat.org"

