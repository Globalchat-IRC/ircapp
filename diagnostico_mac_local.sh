#!/bin/bash

# Diagnóstico de problemas SSH desde este Mac

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TOWER_IP="192.168.1.42"
TOWER_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔍  DIAGNÓSTICO MAC LOCAL                            ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Verificar VPN
echo -e "${BLUE}${BOLD}1. Verificando VPN:${NC}"
if pgrep -f "expressvpnd\|vpn" >/dev/null; then
    VPN_PROC=$(ps aux | grep -i "vpn" | grep -v grep | head -1 | awk '{print $11}')
    echo -e "${YELLOW}⚠${NC}  VPN detectado: ${CYAN}$VPN_PROC${NC}"
    echo -e "   ${YELLOW}Esto puede estar bloqueando conexiones locales${NC}\n"
    echo -e "${CYAN}Solución:${NC}"
    echo -e "  • Desconectar VPN temporalmente y probar"
    echo -e "  • O configurar VPN para permitir tráfico local\n"
else
    echo -e "${GREEN}✓${NC} No hay VPN activa\n"
fi

# 2. Verificar proxy
echo -e "${BLUE}${BOLD}2. Verificando configuración de proxy:${NC}"
PROXY_CONFIG=$(scutil --proxy 2>/dev/null | grep -E "ProxyAutoConfigEnable|HTTPProxy|SOCKSProxy" | head -3)
if echo "$PROXY_CONFIG" | grep -q "1"; then
    echo -e "${YELLOW}⚠${NC}  Proxy configurado:"
    echo "$PROXY_CONFIG" | while read line; do
        echo -e "   ${CYAN}$line${NC}"
    done
    echo -e "\n${YELLOW}Esto puede interferir con conexiones locales${NC}\n"
    echo -e "${CYAN}Solución:${NC}"
    echo -e "  • Deshabilitar proxy para conexiones locales"
    echo -e "  • Preferencias del Sistema → Red → Avanzado → Proxy\n"
else
    echo -e "${GREEN}✓${NC} Sin proxy configurado\n"
fi

# 3. Verificar firewall
echo -e "${BLUE}${BOLD}3. Verificando firewall del Mac:${NC}"
FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "No accesible sin sudo")
echo -e "   Estado: ${CYAN}$FW_STATE${NC}\n"
echo -e "${CYAN}Para verificar manualmente:${NC}"
echo -e "  Preferencias del Sistema → Seguridad y Privacidad → Firewall\n"

# 4. Comparar conexiones SSH
echo -e "${BLUE}${BOLD}4. Comparando conexiones SSH:${NC}"
echo -e "   ${GREEN}✓${NC} Conexiones activas a ceres.globalchat.org:62500 funcionan"
echo -e "   ${RED}✗${NC} Conexión a tower ($TOWER_IP:$TOWER_PORT) falla\n"
echo -e "${YELLOW}Esto sugiere que el problema es específico de tower, no del puerto${NC}\n"

# 5. Verificar configuración SSH local
echo -e "${BLUE}${BOLD}5. Verificando configuración SSH local:${NC}"
if [ -f ~/.ssh/config ]; then
    TOWER_CONFIG=$(grep -A 5 "Host.*tower\|192.168.1.42" ~/.ssh/config | head -10)
    if [ -n "$TOWER_CONFIG" ]; then
        echo -e "   Configuración encontrada:"
        echo "$TOWER_CONFIG" | while read line; do
            echo -e "   ${CYAN}$line${NC}"
        done
        echo ""
    fi
fi

# 6. Probar conexión directa sin configuración
echo -e "${BLUE}${BOLD}6. Probando conexión directa:${NC}"
echo -e "   ${CYAN}ssh -F /dev/null -v -p $TOWER_PORT root@$TOWER_IP${NC}\n"
SSH_TEST=$(ssh -F /dev/null -o ConnectTimeout=3 -v -p "$TOWER_PORT" root@"$TOWER_IP" "echo OK" 2>&1 | tail -5)
echo "$SSH_TEST" | while read line; do
    if echo "$line" | grep -q "refused\|timeout\|denied"; then
        echo -e "   ${RED}✗${NC} $line"
    else
        echo -e "   ${CYAN}→${NC} $line"
    fi
done
echo ""

# 7. Verificar si es problema de DNS/resolución
echo -e "${BLUE}${BOLD}7. Verificando resolución de nombres:${NC}"
if ping -c 1 "$TOWER_IP" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Ping a $TOWER_IP funciona"
    TRACEROUTE=$(traceroute -m 3 "$TOWER_IP" 2>&1 | tail -2)
    echo -e "   ${CYAN}$TRACEROUTE${NC}\n"
else
    echo -e "${RED}✗${NC} No hay conectividad básica\n"
fi

# 8. Recomendaciones específicas
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     💡  SOLUCIONES RECOMENDADAS                           ║${NC}"
echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════╣${NC}"

if pgrep -f "expressvpnd\|vpn" >/dev/null; then
    echo -e "${CYAN}${BOLD}║${NC} ${YELLOW}1. DESCONECTAR VPN${NC}"
    echo -e "${CYAN}${BOLD}║${NC}    ExpressVPN está activo y puede estar bloqueando"
    echo -e "${CYAN}${BOLD}║${NC}    conexiones locales. Desconéctalo y prueba.\n"
fi

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}2. VERIFICAR FIREWALL DEL MAC${NC}"
echo -e "${CYAN}${BOLD}║${NC}    Preferencias del Sistema → Seguridad → Firewall"
echo -e "${CYAN}${BOLD}║${NC}    Asegúrate de que SSH/terminal tenga permisos\n"

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}3. PROBAR CON IP DIRECTA${NC}"
echo -e "${CYAN}${BOLD}║${NC}    ssh -p $TOWER_PORT root@$TOWER_IP\n"

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}4. VERIFICAR PROXY${NC}"
echo -e "${CYAN}${BOLD}║${NC}    Si tienes proxy configurado, desactívalo para"
echo -e "${CYAN}${BOLD}║${NC}    conexiones locales\n"

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}5. REINICIAR SERVICIOS DE RED${NC}"
echo -e "${CYAN}${BOLD}║${NC}    sudo ifconfig en0 down && sudo ifconfig en0 up\n"

echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
