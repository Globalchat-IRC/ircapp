# 🚀 Instrucciones de Despliegue en Ceres

## Paso 1: Compilar la Aplicación

```bash
cd /Users/fnaveira/mobile/irc_app
flutter build web --release
```

Los archivos estarán en `build/web/`

## Paso 2: Subir Archivos a Ceres

### Opción A: Usando SCP (desde tu máquina)

```bash
# Crear directorio en ceres (si no existe)
ssh usuario@ceres.globalchat.org "mkdir -p /var/www/irc_app"

# Subir archivos
scp -r build/web/* usuario@ceres.globalchat.org:/var/www/irc_app/
```

### Opción B: Usando rsync (más eficiente)

```bash
rsync -avz --delete build/web/ usuario@ceres.globalchat.org:/var/www/irc_app/
```

## Paso 3: Configurar Nginx en Ceres

Conectarse a ceres:
```bash
ssh usuario@ceres.globalchat.org
```

Editar configuración de Nginx:
```bash
sudo nano /etc/nginx/sites-available/irc_app
```

Configuración sugerida:
```nginx
server {
    listen 80;
    listen [::]:80;
    server_name irc.globalchat.org;  # o el dominio que prefieras
    
    # Redirigir a HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name irc.globalchat.org;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    root /var/www/irc_app;
    index index.html;
    
    # Configuración para Flutter Web
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Headers de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
```

Habilitar sitio:
```bash
sudo ln -s /etc/nginx/sites-available/irc_app /etc/nginx/sites-enabled/
sudo nginx -t  # Verificar configuración
sudo systemctl reload nginx
```

## Paso 4: Verificar Despliegue

Abrir en navegador:
- http://irc.globalchat.org (debería redirigir a HTTPS)
- https://irc.globalchat.org

## Paso 5: Configurar WebSocket para IRC (si es necesario)

Si ceres no tiene soporte WebSocket nativo para IRC, necesitarás un proxy.

Ver `DEPLOY_CERES.md` para más detalles sobre el proxy WebSocket.

## 🔧 Troubleshooting

### Problema: Página en blanco
- Verificar que los archivos estén en `/var/www/irc_app/`
- Verificar permisos: `sudo chown -R www-data:www-data /var/www/irc_app`
- Verificar logs de Nginx: `sudo tail -f /var/log/nginx/error.log`

### Problema: Assets no cargan (404)
- Verificar que `base href` en `index.html` sea correcto
- Verificar configuración de `try_files` en Nginx

### Problema: CORS errors
- Verificar headers CORS en Nginx si es necesario

## 📝 Notas Importantes

1. **Base href**: Si la aplicación se sirve desde un subdirectorio, actualizar `base href` en `index.html`
2. **WebSocket**: La aplicación necesita WebSocket para conectarse a IRC. Verificar que ceres tenga soporte o configurar proxy.
3. **HTTPS**: Es recomendable usar HTTPS para WebSocket seguro (wss://)






