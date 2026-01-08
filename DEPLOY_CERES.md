# 🚀 Guía de Despliegue en Ceres

## Preparación para Instalación en ceres.globalchat.org

Esta guía describe cómo desplegar la aplicación IRC Web v3.0.0 en el servidor ceres.

---

## 📋 Requisitos Previos

1. **Acceso SSH a ceres.globalchat.org**
2. **Node.js y npm** (para servir la aplicación)
3. **Nginx o Apache** (opcional, para servir estático)
4. **Certificado SSL** (para HTTPS)

---

## 🔧 Opción 1: Despliegue Estático (Recomendado)

### Paso 1: Compilar la Aplicación

```bash
cd /Users/fnaveira/mobile/irc_app
flutter build web --release
```

Los archivos compilados estarán en `build/web/`

### Paso 2: Subir Archivos a Ceres

```bash
# Desde tu máquina local
scp -r build/web/* usuario@ceres.globalchat.org:/var/www/irc_app/
```

### Paso 3: Configurar Nginx

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

### Paso 4: Reiniciar Nginx

```bash
sudo systemctl restart nginx
```

---

## 🔧 Opción 2: Servidor Node.js (Desarrollo/Testing)

### Paso 1: Instalar Dependencias

```bash
# En ceres
cd /var/www/irc_app
npm install -g http-server
```

### Paso 2: Ejecutar Servidor

```bash
# Servir en puerto 8080
http-server build/web -p 8080 -c-1

# O con HTTPS
http-server build/web -p 8080 -S -C /path/to/cert.pem -K /path/to/key.pem
```

---

## 🌐 Configuración de WebSocket para IRC

### Opción A: Proxy WebSocket → TCP

Si ceres no tiene soporte WebSocket nativo para IRC, necesitarás un proxy:

```javascript
// websocket-proxy.js
const WebSocket = require('ws');
const net = require('net');

const wss = new WebSocket.Server({ port: 8081 });

wss.on('connection', (ws) => {
  const tcpSocket = net.createConnection(6667, 'ceres.globalchat.org');
  
  ws.on('message', (data) => {
    tcpSocket.write(data);
  });
  
  tcpSocket.on('data', (data) => {
    ws.send(data.toString());
  });
  
  ws.on('close', () => {
    tcpSocket.end();
  });
  
  tcpSocket.on('close', () => {
    ws.close();
  });
});
```

### Opción B: Configurar UnrealIRCd con WebSocket

Si tienes acceso a la configuración de UnrealIRCd, puedes habilitar WebSocket:

```conf
loadmodule "websocket";
websocket {
    port 6668;
    sslport 6697;
};
```

---

## 📝 Variables de Entorno

Crear archivo `.env` en el servidor (si es necesario):

```bash
IRC_HOST=ceres.globalchat.org
IRC_PORT=6667
IRC_SSL_PORT=6697
WEBSOCKET_PROXY_URL=wss://ceres.globalchat.org:8081
```

---

## 🔄 Actualización

Para actualizar la aplicación:

```bash
# 1. Compilar nueva versión
flutter build web --release

# 2. Subir archivos
scp -r build/web/* usuario@ceres.globalchat.org:/var/www/irc_app/

# 3. Reiniciar servidor (si es necesario)
sudo systemctl restart nginx
```

---

## 🐛 Troubleshooting

### Problema: CORS Errors
**Solución**: Configurar headers CORS en Nginx:
```nginx
add_header Access-Control-Allow-Origin "*";
add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
```

### Problema: WebSocket no conecta
**Solución**: Verificar que el proxy WebSocket esté corriendo y accesible.

### Problema: Assets no cargan
**Solución**: Verificar rutas en `index.html` y configuración de base href.

---

## 📊 Monitoreo

```bash
# Ver logs de Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Ver procesos
ps aux | grep http-server
```

---

## ✅ Checklist de Despliegue

- [ ] Aplicación compilada (`flutter build web`)
- [ ] Archivos subidos a ceres
- [ ] Nginx configurado
- [ ] SSL/TLS configurado
- [ ] WebSocket proxy configurado (si necesario)
- [ ] Dominio apuntando a ceres
- [ ] Pruebas de conexión IRC
- [ ] Pruebas de radio
- [ ] Pruebas en diferentes navegadores

---

**Nota**: Asegúrate de que ceres tenga los puertos necesarios abiertos (80, 443, 6667, 6697, 8081 para WebSocket).





