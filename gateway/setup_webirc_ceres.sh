#!/bin/bash
# Ejecutar EN CERES (ssh ceres) para activar WEBIRC y que el IRC vea la IP real de los usuarios.
# Uso: elegir un password secreto y ponerlo en WEBIRC_PASSWORD (y el mismo en UnrealIRCd).

set -e
REMOTE_PATH="${REMOTE_PATH:-/opt/irc-gateway}"
SERVICE_NAME="${SERVICE_NAME:-irc-gateway}"

echo "=== Configuración WEBIRC en ceres ==="
echo ""

if [ ! -d "$REMOTE_PATH" ]; then
  echo "❌ No existe $REMOTE_PATH. Despliega antes el gateway: desde gateway/ ejecuta ./deploy.sh"
  exit 1
fi

if [ -n "$WEBIRC_PASSWORD" ]; then
  echo "Creando $REMOTE_PATH/webirc.env con WEBIRC_PASSWORD..."
  echo "WEBIRC_PASSWORD=$WEBIRC_PASSWORD" > "$REMOTE_PATH/webirc.env"
  chmod 600 "$REMOTE_PATH/webirc.env"
  echo "✅ webirc.env creado."
else
  echo "Variable WEBIRC_PASSWORD no definida."
  echo ""
  echo "Opción 1 - Crear archivo manualmente:"
  echo "  sudo nano $REMOTE_PATH/webirc.env"
  echo "  (contenido: una línea) WEBIRC_PASSWORD=tu_password_secreto"
  echo "  sudo chmod 600 $REMOTE_PATH/webirc.env"
  echo ""
  echo "Opción 2 - Usar este script con el password:"
  echo "  WEBIRC_PASSWORD='mi_password_secreto' $0"
  echo ""
  read -p "Introduce el password WEBIRC (mismo que pondrás en UnrealIRCd): " -s pw
  echo ""
  if [ -z "$pw" ]; then
    echo "No se creó webirc.env. Ejecuta de nuevo o créalo a mano."
    exit 0
  fi
  echo "WEBIRC_PASSWORD=$pw" > "$REMOTE_PATH/webirc.env"
  chmod 600 "$REMOTE_PATH/webirc.env"
  echo "✅ webirc.env creado."
fi

echo ""
echo "Reiniciando servicio $SERVICE_NAME..."
sudo systemctl restart "$SERVICE_NAME"
sleep 1
sudo systemctl status "$SERVICE_NAME" --no-pager -l | head -20
echo ""
echo "=== Siguiente paso: en UnrealIRCd (apolo/caliope) añadir en unrealircd.conf ==="
echo ""
echo "webirc {"
echo "  mask 5.57.224.66;"
echo "  password \"EL_MISMO_PASSWORD_QUE_EN_webirc.env\";"
echo "};"
echo ""
echo "Luego en IRC: /rehash"
echo ""
