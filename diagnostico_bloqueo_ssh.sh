#!/bin/bash

# Script para diagnosticar y recuperar el bloqueo SSH en tower

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

DEST_HOST="root@192.168.1.42"
SSH_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔍  DIAGNÓSTICO DE BLOQUEO SSH                       ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}1. Verificando conectividad básica...${NC}"
if ping -c 2 192.168.1.42 >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} El servidor responde a ping"
else
    echo -e "${RED}✗${NC} El servidor NO responde a ping"
    exit 1
fi

echo -e "\n${BLUE}2. Verificando puerto SSH...${NC}"
if nc -z -v -w 2 192.168.1.42 $SSH_PORT 2>&1 | grep -q "succeeded"; then
    echo -e "${GREEN}✓${NC} Puerto $SSH_PORT está abierto"
else
    echo -e "${RED}✗${NC} Puerto $SSH_PORT está cerrado o bloqueado"
fi

echo -e "\n${BLUE}3. Intentando conexión SSH...${NC}"
if ssh -p $SSH_PORT -o ConnectTimeout=5 -o BatchMode=yes "$DEST_HOST" "echo 'OK'" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Conexión SSH exitosa"
    echo -e "\n${GREEN}${BOLD}✅ El servidor NO está bloqueado. Puedes continuar.${NC}\n"
    exit 0
else
    echo -e "${RED}✗${NC} Conexión SSH rechazada o bloqueada"
fi

echo -e "\n${YELLOW}${BOLD}⚠️  EL SERVIDOR ESTÁ BLOQUEADO${NC}\n"

echo -e "${CYAN}${BOLD}POSIBLES CAUSAS:${NC}\n"
echo -e "1. ${BOLD}fail2ban${NC} - Bloquea IPs después de intentos fallidos"
echo -e "2. ${BOLD}MaxStartups${NC} - Límite de conexiones simultáneas alcanzado"
echo -e "3. ${BOLD}Firewall (ufw/iptables)${NC} - Regla que bloquea tu IP"
echo -e "4. ${BOLD}SSH rate limiting${NC} - Protección contra ataques"
echo -e "5. ${BOLD}Servidor SSH sobrecargado${NC} - Demasiadas conexiones activas\n"

echo -e "${CYAN}${BOLD}SOLUCIONES (ejecutar EN TOWER):${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 1: Verificar y desbloquear fail2ban${NC}"
echo -e "${BLUE}ssh -p 22 root@192.168.1.42${NC}  # Si tienes acceso por otro puerto"
echo -e "${BLUE}# Luego en tower:${NC}"
echo -e "  ${GREEN}sudo fail2ban-client status sshd${NC}"
echo -e "  ${GREEN}sudo fail2ban-client unban 192.168.1.42${NC}  # Tu IP Mac"
echo -e "  ${GREEN}sudo fail2ban-client set sshd unbanip 192.168.1.42${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 2: Verificar y reiniciar SSH${NC}"
echo -e "${BLUE}# En tower:${NC}"
echo -e "  ${GREEN}sudo systemctl status ssh${NC}"
echo -e "  ${GREEN}sudo systemctl restart ssh${NC}"
echo -e "  ${GREEN}sudo systemctl status ssh${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 3: Verificar firewall${NC}"
echo -e "${BLUE}# En tower:${NC}"
echo -e "  ${GREEN}sudo ufw status${NC}  # Si usa ufw"
echo -e "  ${GREEN}sudo iptables -L -n | grep 192.168.1${NC}  # Ver reglas"
echo -e "  ${GREEN}sudo iptables -D INPUT -s 192.168.1.42 -j DROP${NC}  # Si hay bloqueo\n"

echo -e "${YELLOW}${BOLD}Opción 4: Verificar conexiones SSH activas${NC}"
echo -e "${BLUE}# En tower:${NC}"
echo -e "  ${GREEN}sudo netstat -tnpa | grep :$SSH_PORT | grep ESTABLISHED | wc -l${NC}"
echo -e "  ${GREEN}sudo ss -tnp | grep :$SSH_PORT${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 5: Configurar SSH para evitar bloqueos futuros${NC}"
echo -e "${BLUE}# En tower:${NC}"
echo -e "  ${GREEN}sudo nano /etc/ssh/sshd_config${NC}"
echo -e "  ${CYAN}# Agregar/modificar:${NC}"
echo -e "  ${CYAN}MaxStartups 20:50:100${NC}"
echo -e "  ${CYAN}ClientAliveInterval 60${NC}"
echo -e "  ${CYAN}ClientAliveCountMax 5${NC}"
echo -e "  ${CYAN}TCPKeepAlive yes${NC}"
echo -e "  ${GREEN}sudo systemctl restart ssh${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 6: Esperar (bloqueo temporal)${NC}"
echo -e "  ${BLUE}Los bloqueos temporales suelen durar 10-30 minutos${NC}"
echo -e "  ${BLUE}Espera y vuelve a intentar${NC}\n"

echo -e "${CYAN}${BOLD}COMANDO RÁPIDO (si tienes acceso físico o por otro método):${NC}\n"
echo -e "${GREEN}ssh -p 22 root@192.168.1.42 'sudo systemctl restart ssh && sudo fail2ban-client unban 192.168.1.42 2>/dev/null || echo \"fail2ban no instalado\"'${NC}\n"

echo -e "${YELLOW}${BOLD}Para verificar tu IP actual:${NC}"
echo -e "${BLUE}ifconfig | grep 'inet ' | grep -v 127.0.0.1${NC}\n"
