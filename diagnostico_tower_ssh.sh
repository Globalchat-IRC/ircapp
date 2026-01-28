#!/bin/bash

# Script de diagnóstico para conexión SSH a tower

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
echo -e "${CYAN}${BOLD}║     🔍  DIAGNÓSTICO SSH TOWER                            ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}${BOLD}1. Conectividad de red:${NC}"
if ping -c 1 -W 2 "$TOWER_IP" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Tower responde a ping ($TOWER_IP)\n"
else
    echo -e "${RED}✗${NC} Tower NO responde a ping\n"
    exit 1
fi

echo -e "${BLUE}${BOLD}2. Verificación de puerto SSH ($TOWER_PORT):${NC}"
if nc -zv -w 3 "$TOWER_IP" "$TOWER_PORT" 2>&1 | grep -q "succeeded\|open"; then
    echo -e "${GREEN}✓${NC} Puerto $TOWER_PORT está abierto\n"
    PORT_OPEN=true
else
    echo -e "${RED}✗${NC} Puerto $TOWER_PORT está cerrado o rechazando conexiones\n"
    PORT_OPEN=false
fi

echo -e "${BLUE}${BOLD}3. Intento de conexión SSH:${NC}"
if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no tower "echo 'OK'" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Conexión SSH exitosa\n"
    exit 0
else
    SSH_ERROR=$(ssh -v -o ConnectTimeout=5 -o BatchMode=yes tower "echo 'OK'" 2>&1 | grep -i "error\|refused\|timeout" | head -1)
    echo -e "${RED}✗${NC} Conexión SSH falló\n"
    echo -e "${YELLOW}Error:${NC} $SSH_ERROR\n"
fi

echo -e "${BLUE}${BOLD}4. Resumen y recomendaciones:${NC}\n"

if [ "$PORT_OPEN" = false ]; then
    echo -e "${YELLOW}⚠${NC}  El puerto $TOWER_PORT no está accesible.\n"
    echo -e "${YELLOW}Posibles causas:${NC}"
    echo -e "  • El servidor SSH no está corriendo en tower"
    echo -e "  • El firewall está bloqueando el puerto"
    echo -e "  • El servicio SSH está en otro puerto\n"
    echo -e "${YELLOW}Acciones recomendadas:${NC}"
    echo -e "  1. Conectarte físicamente a tower y verificar:"
    echo -e "     ${CYAN}sudo systemctl status ssh${NC}  (Linux)"
    echo -e "     ${CYAN}sudo service ssh status${NC}      (Linux/Debian)"
    echo -e "     ${CYAN}ps aux | grep sshd${NC}          (Verificar proceso)\n"
    echo -e "  2. Verificar el firewall:"
    echo -e "     ${CYAN}sudo ufw status${NC}              (Ubuntu/Debian)"
    echo -e "     ${CYAN}sudo firewall-cmd --list-all${NC} (CentOS/RHEL)\n"
    echo -e "  3. Verificar qué puertos están abiertos:"
    echo -e "     ${CYAN}sudo netstat -tlnp | grep ssh${NC}"
    echo -e "     ${CYAN}sudo ss -tlnp | grep ssh${NC}\n"
else
    echo -e "${GREEN}✓${NC} El puerto está abierto, pero la autenticación puede estar fallando.\n"
    echo -e "${YELLOW}Intenta conectar manualmente:${NC}"
    echo -e "  ${CYAN}ssh -p $TOWER_PORT tu_usuario@$TOWER_IP${NC}\n"
fi

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📋  DIAGNÓSTICO COMPLETADO                           ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
