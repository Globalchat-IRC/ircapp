# 📤 Despliegue Manual en Ceres

Si el script automático falla por problemas de autenticación SSH, puedes desplegar manualmente:

## Opción 1: Usando rsync (Recomendado)

```bash
cd /Users/fnaveira/mobile/irc_app

# Crear directorio en ceres
ssh globalchat@ceres.globalchat.org "mkdir -p /var/www/irc_app"

# Subir archivos
rsync -avz --progress --delete build/web/ globalchat@ceres.globalchat.org:/var/www/irc_app/

# Configurar permisos (necesitarás sudo)
ssh globalchat@ceres.globalchat.org "sudo chown -R www-data:www-data /var/www/irc_app && sudo chmod -R 755 /var/www/irc_app"
```

## Opción 2: Usando SCP

```bash
cd /Users/fnaveira/mobile/irc_app

# Crear directorio
ssh globalchat@ceres.globalchat.org "mkdir -p /var/www/irc_app"

# Subir archivos
scp -r build/web/* globalchat@ceres.globalchat.org:/var/www/irc_app/

# Configurar permisos
ssh globalchat@ceres.globalchat.org "sudo chown -R www-data:www-data /var/www/irc_app"
```

## Opción 3: Subir archivos comprimidos

```bash
cd /Users/fnaveira/mobile/irc_app

# Comprimir
tar -czf irc_app_web.tar.gz -C build web/

# Subir
scp irc_app_web.tar.gz globalchat@ceres.globalchat.org:/tmp/

# En ceres, descomprimir
ssh globalchat@ceres.globalchat.org "cd /var/www && sudo mkdir -p irc_app && sudo tar -xzf /tmp/irc_app_web.tar.gz -C irc_app --strip-components=1 && sudo chown -R www-data:www-data irc_app && rm /tmp/irc_app_web.tar.gz"
```

## Verificar Despliegue

```bash
# Verificar que los archivos estén ahí
ssh globalchat@ceres.globalchat.org "ls -la /var/www/irc_app/"

# Verificar permisos
ssh globalchat@ceres.globalchat.org "ls -la /var/www/irc_app/ | head -10"
```

## Configurar Nginx

Después de subir los archivos, configura Nginx:

```bash
ssh globalchat@ceres.globalchat.org
sudo nano /etc/nginx/sites-available/irc_app
```

Pegar esta configuración:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name irc.globalchat.org;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    root /var/www/irc_app;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

Habilitar y recargar:

```bash
sudo ln -s /etc/nginx/sites-available/irc_app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```


