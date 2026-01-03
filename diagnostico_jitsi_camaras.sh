#!/bin/bash
# Script de diagnostico para problemas de camaras en Jitsi Meet
# Ejecutar en el servidor caliope como root

echo "=========================================="
echo "DIAGNOSTICO DE CAMARAS JITSI MEET"
echo "=========================================="
echo ""

# 1. Verificar archivos de configuracion principales
echo "1. REVISANDO ARCHIVOS DE CONFIGURACION..."
echo ""

DOMAIN="video.globalchat.org"
CONFIG_FILE="/etc/jitsi/meet/${DOMAIN}-config.js"
INTERFACE_CONFIG="/etc/jitsi/meet/${DOMAIN}-interface_config.js"

if [ -f "$CONFIG_FILE" ]; then
    echo "Archivo de configuracion encontrado: $CONFIG_FILE"
    echo ""
    echo "--- Configuraciones relacionadas con video ---"
    echo "Buscando todas las opciones de video..."
    grep -i "video\|camera\|startWithVideo\|defaultLocalVideo\|disableVideo\|videoQuality" "$CONFIG_FILE" || echo "No se encontraron configuraciones especificas de video"
    echo ""
    echo "--- Verificando configuraciones especificas ---"
    if grep -q "startWithVideoMuted" "$CONFIG_FILE"; then
        echo "startWithVideoMuted encontrado:"
        grep "startWithVideoMuted" "$CONFIG_FILE"
    else
        echo "startWithVideoMuted: NO encontrado (se usara valor por defecto)"
    fi
    if grep -q "defaultLocalVideoMuted" "$CONFIG_FILE"; then
        echo "defaultLocalVideoMuted encontrado:"
        grep "defaultLocalVideoMuted" "$CONFIG_FILE"
    else
        echo "defaultLocalVideoMuted: NO encontrado (no existe en esta version/configuracion)"
    fi
    if grep -q "disableVideo" "$CONFIG_FILE"; then
        echo "disableVideo encontrado:"
        grep "disableVideo" "$CONFIG_FILE"
    else
        echo "disableVideo: NO encontrado (video esta habilitado)"
    fi
    echo ""
else
    echo "No se encontro: $CONFIG_FILE"
fi

if [ -f "$INTERFACE_CONFIG" ]; then
    echo "Archivo de interfaz encontrado: $INTERFACE_CONFIG"
    echo ""
    echo "--- Configuraciones de interfaz relacionadas con video ---"
    grep -i "video\|camera\|TOOLBAR" "$INTERFACE_CONFIG" || echo "No se encontraron configuraciones especificas"
    echo ""
else
    echo "No se encontro: $INTERFACE_CONFIG"
fi

# 2. Verificar servicios de Jitsi
echo "2. REVISANDO SERVICIOS DE JITSI..."
echo ""
systemctl status jitsi-videobridge2 --no-pager -l | head -20
echo ""
systemctl status jicofo --no-pager -l | head -20
echo ""

# 3. Verificar logs recientes
echo "3. REVISANDO LOGS RECIENTES (ultimas 20 lineas)..."
echo ""
if [ -f "/var/log/jitsi/jicofo.log" ]; then
    echo "--- Jicofo logs ---"
    tail -20 /var/log/jitsi/jicofo.log | grep -i "video\|camera\|error" || echo "No hay errores relacionados con video en los logs recientes"
    echo ""
fi

if [ -f "/var/log/jitsi/jvb.log" ]; then
    echo "--- JVB (Video Bridge) logs ---"
    tail -20 /var/log/jitsi/jvb.log | grep -i "video\|camera\|error" || echo "No hay errores relacionados con video en los logs recientes"
    echo ""
fi

# 4. Verificar configuracion de TURN/STUN (importante para video)
echo "4. REVISANDO CONFIGURACION TURN/STUN..."
echo ""
if [ -f "$CONFIG_FILE" ]; then
    echo "--- Configuracion de ICE servers ---"
    grep -A 10 -i "iceServers\|stun\|turn" "$CONFIG_FILE" || echo "No se encontro configuracion de ICE servers"
    echo ""
fi

# 5. Verificar puertos y firewall
echo "5. REVISANDO PUERTOS Y CONECTIVIDAD..."
echo ""
echo "Puertos Jitsi abiertos:"
netstat -tuln | grep -E "8080|4443|10000" || echo "No se encontraron puertos Jitsi abiertos"
echo ""

# 6. Verificar configuracion de Prosody
echo "6. REVISANDO CONFIGURACION DE PROSODY..."
echo ""
PROSODY_CONFIG="/etc/prosody/conf.avail/${DOMAIN}.cfg.lua"
if [ -f "$PROSODY_CONFIG" ]; then
    echo "Archivo Prosody encontrado"
    echo "--- Modulos habilitados ---"
    grep -i "modules_enabled\|Component" "$PROSODY_CONFIG" | head -10
    echo ""
else
    echo "No se encontro: $PROSODY_CONFIG"
fi

# 7. Recomendaciones
echo "=========================================="
echo "RECOMENDACIONES PARA SOLUCIONAR PROBLEMAS:"
echo "=========================================="
echo ""
echo "1. Verificar en config.js las siguientes opciones:"
echo "   - startWithVideoMuted: debe ser false (o no existir)"
echo "   - disableVideo: debe ser false (o no existir)"
echo "   - defaultLocalVideoMuted: puede no existir (es opcional)"
echo ""
echo "2. Si startWithVideoMuted no existe, agregarlo como:"
echo "   startWithVideoMuted: false,"
echo ""
echo "3. Verificar permisos de camara en el navegador"
echo ""
echo "4. Verificar que TURN/STUN este configurado correctamente"
echo ""
echo "5. Revisar logs completos:"
echo "   tail -f /var/log/jitsi/jicofo.log"
echo "   tail -f /var/log/jitsi/jvb.log"
echo ""

exit 0
