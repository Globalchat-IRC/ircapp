#!/bin/bash

# Script para ejecutar EN TOWER para desbloquear SSH
# Copiar a tower y ejecutar: sudo bash desbloquear_ssh_tower.sh

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

MAC_IP="192.168.1.48"  # IP de tu Mac
SSH_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔓  DESBLOQUEAR SSH PARA MAC                          ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Desbloquear en fail2ban
echo -e "${BLUE}${BOLD}1. Desbloqueando en fail2ban...${NC}"
if command -v fail2ban-client >/dev/null 2>&1; then
    if fail2ban-client status sshd >/dev/null 2>&1; then
        echo -e "${YELLOW}Verificando IPs bloqueadas...${NC}"
        BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Banned IP list" | grep -o "$MAC_IP" || echo "")
        if [ -n "$BANNED" ]; then
            echo -e "${RED}✗${NC} IP $MAC_IP está bloqueada en fail2ban"
            fail2ban-client set sshd unbanip "$MAC_IP" 2>/dev/null && \
                echo -e "${GREEN}✓${NC} IP $MAC_IP desbloqueada en fail2ban" || \
                echo -e "${YELLOW}⚠${NC}  No se pudo desbloquear automáticamente"
        else
            echo -e "${GREEN}✓${NC} IP $MAC_IP NO está bloqueada en fail2ban"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  fail2ban no tiene jail sshd activo"
    fi
else
    echo -e "${YELLOW}⚠${NC}  fail2ban no está instalado"
fi
echo ""

# 2. Verificar y limpiar hosts.deny
echo -e "${BLUE}${BOLD}2. Verificando /etc/hosts.deny...${NC}"
if grep -q "$MAC_IP" /etc/hosts.deny 2>/dev/null; then
    echo -e "${RED}✗${NC} IP $MAC_IP está bloqueada en hosts.deny"
    echo -e "${YELLOW}Líneas encontradas:${NC}"
    grep "$MAC_IP" /etc/hosts.deny
    echo -e "\n${GREEN}Desbloqueando...${NC}"
    sed -i "/$MAC_IP/d" /etc/hosts.deny 2>/dev/null && \
        echo -e "${GREEN}✓${NC} IP $MAC_IP eliminada de hosts.deny" || \
        echo -e "${RED}✗${NC} Error al eliminar (necesitas sudo)"
else
    echo -e "${GREEN}✓${NC} IP $MAC_IP NO está bloqueada en hosts.deny"
fi
echo ""

# 3. Verificar y limpiar iptables
echo -e "${BLUE}${BOLD}3. Verificando iptables...${NC}"
if command -v iptables >/dev/null 2>&1; then
    BLOCKED_RULES=$(iptables -L INPUT -n | grep "$MAC_IP" | grep -i "drop\|reject" || echo "")
    if [ -n "$BLOCKED_RULES" ]; then
        echo -e "${RED}✗${NC} IP $MAC_IP tiene reglas de bloqueo en iptables"
        echo -e "${YELLOW}Reglas encontradas:${NC}"
        iptables -L INPUT -n | grep "$MAC_IP"
        echo -e "\n${GREEN}Eliminando reglas...${NC}"
        iptables -D INPUT -s "$MAC_IP" -j DROP 2>/dev/null || true
        iptables -D INPUT -s "$MAC_IP" -j REJECT 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Reglas eliminadas (si existían)"
    else
        echo -e "${GREEN}✓${NC} IP $MAC_IP NO tiene reglas de bloqueo en iptables"
    fi
else
    echo -e "${YELLOW}⚠${NC}  iptables no está disponible"
fi
echo ""

# 4. Verificar conexiones SSH activas
echo -e "${BLUE}${BOLD}4. Verificando conexiones SSH activas...${NC}"
ACTIVE_CONNECTIONS=$(ss -tnp 2>/dev/null | grep ":$SSH_PORT" | grep ESTABLISHED | wc -l)
echo -e "   Conexiones activas en puerto $SSH_PORT: ${CYAN}$ACTIVE_CONNECTIONS${NC}"
if [ "$ACTIVE_CONNECTIONS" -gt 10 ]; then
    echo -e "${YELLOW}⚠${NC}  Muchas conexiones activas, puede estar sobrecargado"
fi
echo ""

# 5. Reiniciar SSH
echo -e "${BLUE}${BOLD}5. Reiniciando servicio SSH...${NC}"
if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
    sleep 2
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Servicio SSH reiniciado correctamente"
    else
        echo -e "${RED}✗${NC} Servicio SSH no está corriendo después del reinicio"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No se pudo reiniciar SSH (puede necesitar sudo)"
fi
echo ""

# 6. Verificar configuración MaxStartups
echo -e "${BLUE}${BOLD}6. Verificando configuración MaxStartups...${NC}"
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
    MAX_STARTUPS=$(grep -i "^MaxStartups" "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo "")
    if [ -z "$MAX_STARTUPS" ]; then
        echo -e "${YELLOW}⚠${NC}  MaxStartups no está configurado (por defecto: 10:30:100)"
        echo -e "${CYAN}Recomendación: Agregar 'MaxStartups 20:50:100' a $SSH_CONFIG${NC}"
    else
        echo -e "${GREEN}✓${NC} MaxStartups configurado: ${CYAN}$MAX_STARTUPS${NC}"
    fi
else
    echo -e "${RED}✗${NC} Archivo de configuración SSH no encontrado"
fi
echo ""

# Resumen
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     ✅  PROCESO COMPLETADO                                ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}IP desbloqueada:${NC} $MAC_IP"
echo -e "${GREEN}Puerto SSH:${NC} $SSH_PORT\n"

echo -e "${YELLOW}Prueba la conexión desde tu Mac:${NC}"
echo -e "${BLUE}ssh -p $SSH_PORT root@192.168.1.42${NC}\n"
