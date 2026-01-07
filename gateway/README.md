# WebSocket Gateway para IRC

Este servidor actúa como proxy/gateway entre clientes WebSocket (aplicación web) y servidores IRC (TCP) del cluster GlobalChat.

## Funcionalidad

- Recibe conexiones WebSocket desde clientes web
- Se conecta internamente a cualquier servidor IRC del cluster (ceres, apolo, creta, caliope)
- Reenvía mensajes bidireccionalmente entre WebSocket y TCP
- Soporta múltiples conexiones simultáneas

## Instalación

```bash
cd gateway
npm install
```

## Configuración

### Variables de entorno

- `PORT`: Puerto donde escucha el gateway (default: 4443)

### Servidores permitidos

Editar `websocket-gateway.js` y modificar el array `ALLOWED_SERVERS`:

```javascript
const ALLOWED_SERVERS = [
  'ceres.globalchat.org',
  'apolo.globalchat.org',
  'creta.globalchat.org',
  'caliope.globalchat.org',
  'localhost',
  '127.0.0.1',
];
```

### Puertos permitidos

Editar `ALLOWED_PORTS`:

```javascript
const ALLOWED_PORTS = [6667, 6697];
```

## Uso

### Desarrollo

```bash
npm run dev
```

### Producción

```bash
npm start
```

O con PM2:

```bash
pm2 start websocket-gateway.js --name irc-gateway
pm2 save
```

## Protocolo

### Handshake (primer mensaje)

El cliente debe enviar un mensaje JSON con el servidor destino:

```json
{
  "host": "apolo.globalchat.org",
  "port": 6667,
  "useSSL": false
}
```

O formato legacy (texto plano):

```
apolo.globalchat.org:6667
```

### Mensajes IRC

Después del handshake, todos los mensajes se reenvían directamente al servidor IRC.

### Respuestas del Gateway

El gateway puede enviar mensajes de control en formato JSON:

```json
{
  "type": "handshake_ok",
  "host": "apolo.globalchat.org",
  "port": 6667
}
```

```json
{
  "type": "handshake_error",
  "error": "Servidor no permitido"
}
```

```json
{
  "type": "irc_error",
  "error": "Connection refused"
}
```

```json
{
  "type": "irc_closed"
}
```

## Seguridad

- Whitelist de servidores permitidos
- Whitelist de puertos permitidos
- Timeout de conexión (10 segundos)
- Timeout de handshake (5 segundos)
- Validación de entrada

## Despliegue en Ceres

### Método automático (recomendado)

```bash
cd gateway
./deploy.sh
```

### Método manual

1. Copiar archivos a ceres:

```bash
scp -r gateway/ ceres.globalchat.org:/opt/irc-gateway/
```

2. Instalar dependencias:

```bash
ssh ceres.globalchat.org
cd /opt/irc-gateway
npm install --production
```

3. Configurar como servicio systemd:

```bash
sudo nano /etc/systemd/system/irc-gateway.service
```

```ini
[Unit]
Description=IRC WebSocket Gateway
After=network.target

[Service]
Type=simple
User=globalchat
WorkingDirectory=/opt/irc-gateway
ExecStart=/usr/bin/node websocket-gateway.js
Restart=always
RestartSec=10
Environment=PORT=4443

[Install]
WantedBy=multi-user.target
```

4. Iniciar servicio:

```bash
sudo systemctl daemon-reload
sudo systemctl enable irc-gateway
sudo systemctl start irc-gateway
sudo systemctl status irc-gateway
```

5. Verificar logs:

```bash
sudo journalctl -u irc-gateway -f
```

## Firewall

Asegurarse de que el puerto 4443 esté abierto:

```bash
sudo ufw allow 4443/tcp
```

## Monitoreo

El gateway registra todas las conexiones y errores en la consola. Para producción, considerar usar un logger como `winston` o `pino`.

