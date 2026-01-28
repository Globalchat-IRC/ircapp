#!/bin/bash

# Diagnóstico completo para tower sin iptables/ufw

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

MAC_IP="192.168.1.48"
SSH_PORT="62500"

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔍  DIAGNÓSTICO COMPLETO TOWER                       ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Verificar si SSH está corriendo
echo -e "${BLUE}${BOLD}1. Estado del servicio SSH:${NC}"
if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Servicio SSH está corriendo\n"
else
    echo -e "${RED}✗${NC} Servicio SSH NO está corriendo\n"
    echo -e "${YELLOW}Iniciar con:${NC}"
    echo -e "  ${GREEN}sudo systemctl start ssh${NC}  o  ${GREEN}sudo systemctl start sshd${NC}\n"
fi

# 2. Verificar en qué puerto está escuchando SSH
echo -e "${BLUE}${BOLD}2. Puertos donde SSH está escuchando:${NC}"
SSH_PORTS=$(netstat -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | cut -d: -f2 | sort -u)
if [ -z "$SSH_PORTS" ]; then
    SSH_PORTS=$(ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | cut -d: -f2 | sort -u)
fi
if [ -z "$SSH_PORTS" ]; then
    SSH_PORTS=$(lsof -i -P -n 2>/dev/null | grep sshd | grep LISTEN | awk '{print $9}' | cut -d: -f2 | sort -u)
fi

if [ -n "$SSH_PORTS" ]; then
    echo -e "${GREEN}✓${NC} SSH está escuchando en puerto(s): ${CYAN}$SSH_PORTS${NC}"
    if echo "$SSH_PORTS" | grep -q "$SSH_PORT"; then
        echo -e "${GREEN}✓${NC} Puerto $SSH_PORT está activo\n"
    else
        echo -e "${RED}✗${NC} Puerto $SSH_PORT NO está en la lista\n"
        echo -e "${YELLOW}SSH está escuchando en otros puertos, no en $SSH_PORT${NC}\n"
    fi
else
    echo -e "${RED}✗${NC} No se pudo detectar en qué puerto está escuchando SSH\n"
fi

# 3. Verificar configuración SSH
echo -e "${BLUE}${BOLD}3. Configuración SSH (/etc/ssh/sshd_config):${NC}"
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
    CONFIG_PORT=$(grep "^Port" "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ -z "$CONFIG_PORT" ]; then
        CONFIG_PORT="22 (por defecto)"
    fi
    echo -e "   Puerto configurado: ${CYAN}$CONFIG_PORT${NC}"
    
    # Verificar ListenAddress
    LISTEN_ADDR=$(grep "^ListenAddress" "$SSH_CONFIG" 2>/dev/null || echo "Todos (0.0.0.0)")
    echo -e "   Escuchando en: ${CYAN}$LISTEN_ADDR${NC}"
    
    # Verificar restricciones
    DENY_USERS=$(grep "^DenyUsers" "$SSH_CONFIG" 2>/dev/null || echo "Ninguno")
    DENY_HOSTS=$(grep "^DenyHosts" "$SSH_CONFIG" 2>/dev/null || echo "Ninguno")
    ALLOW_USERS=$(grep "^AllowUsers" "$SSH_CONFIG" 2>/dev/null || echo "Ninguno")
    
    echo -e "   DenyUsers: ${CYAN}$DENY_USERS${NC}"
    echo -e "   AllowUsers: ${CYAN}$ALLOW_USERS${NC}"
    echo ""
    
    if [ "$CONFIG_PORT" != "$SSH_PORT" ] && [ "$CONFIG_PORT" != "22 (por defecto)" ]; then
        echo -e "${YELLOW}⚠${NC}  SSH configurado en puerto $CONFIG_PORT, pero necesitas $SSH_PORT\n"
        echo -e "${CYAN}Para cambiar:${NC}"
        echo -e "  1. Editar: ${GREEN}sudo nano $SSH_CONFIG${NC}"
        echo -e "  2. Cambiar: ${GREEN}Port $SSH_PORT${NC}"
        echo -e "  3. Reiniciar: ${GREEN}sudo systemctl restart ssh${NC}\n"
    fi
else
    echo -e "${RED}✗${NC} Archivo de configuración no encontrado\n"
fi

# 4. Verificar hosts.deny y hosts.allow
echo -e "${BLUE}${BOLD}4. Verificando hosts.deny y hosts.allow:${NC}"
if [ -f /etc/hosts.deny ]; then
    if grep -q "$MAC_IP\|sshd.*$MAC_IP\|ALL.*$MAC_IP" /etc/hosts.deny 2>/dev/null; then
        echo -e "${RED}✗${NC} IP $MAC_IP está BLOQUEADA en /etc/hosts.deny"
        grep -E "$MAC_IP|sshd" /etc/hosts.deny | head -3
        echo -e "\n${YELLOW}Para desbloquear:${NC}"
        echo -e "  ${GREEN}sudo sed -i '/$MAC_IP/d' /etc/hosts.deny${NC}\n"
    else
        echo -e "${GREEN}✓${NC} IP $MAC_IP NO está bloqueada en hosts.deny\n"
    fi
else
    echo -e "${GREEN}✓${NC} /etc/hosts.deny no existe\n"
fi

if [ -f /etc/hosts.allow ]; then
    ALLOW_RULE=$(grep -E "$MAC_IP|sshd.*ALL" /etc/hosts.allow 2>/dev/null || echo "Ninguna")
    echo -e "   Reglas en hosts.allow: ${CYAN}$ALLOW_RULE${NC}\n"
fi

# 5. Verificar otros firewalls
echo -e "${BLUE}${BOLD}5. Verificando otros sistemas de firewall:${NC}"
if command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC}  Firewalld está activo"
        firewall-cmd --list-all | grep -E "ports|services" | head -5
        echo -e "\n${CYAN}Para permitir puerto:${NC}"
        echo -e "  ${GREEN}sudo firewall-cmd --permanent --add-port=$SSH_PORT/tcp${NC}"
        echo -e "  ${GREEN}sudo firewall-cmd --reload${NC}\n"
    else
        echo -e "${GREEN}✓${NC} Firewalld no está activo\n"
    fi
elif command -v nft >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  NFTables detectado"
    sudo nft list ruleset 2>/dev/null | grep -E "$SSH_PORT|$MAC_IP" | head -5 || echo "Sin reglas específicas"
    echo ""
elif command -v pfctl >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  PF (Packet Filter) detectado"
    sudo pfctl -s rules 2>/dev/null | grep -E "$SSH_PORT|$MAC_IP" | head -5 || echo "Sin reglas específicas"
    echo ""
else
    echo -e "${GREEN}✓${NC} No se detectaron otros firewalls\n"
fi

# 6. Verificar logs SSH
echo -e "${BLUE}${BOLD}6. Últimos intentos de conexión desde $MAC_IP:${NC}"
LOG_FILE=""
if [ -f /var/log/auth.log ]; then
    LOG_FILE="/var/log/auth.log"
elif [ -f /var/log/secure ]; then
    LOG_FILE="/var/log/secure"
elif [ -f /var/log/messages ]; then
    LOG_FILE="/var/log/messages"
fi

if [ -n "$LOG_FILE" ]; then
    RECENT_LOGS=$(sudo grep "$MAC_IP" "$LOG_FILE" 2>/dev/null | tail -5 || echo "")
    if [ -n "$RECENT_LOGS" ]; then
        echo "$RECENT_LOGS" | while read line; do
            if echo "$line" | grep -qi "refused\|denied\|failed\|invalid"; then
                echo -e "   ${RED}✗${NC} $line"
            else
                echo -e "   ${CYAN}→${NC} $line"
            fi
        done
        echo ""
    else
        echo -e "${YELLOW}⚠${NC}  No se encontraron logs recientes para $MAC_IP\n"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No se pudo encontrar archivo de logs\n"
fi

# 7. Verificar si el puerto está realmente abierto desde dentro
echo -e "${BLUE}${BOLD}7. Verificando puerto desde dentro de tower:${NC}"
if command -v nc >/dev/null 2>&1; then
    if nc -zv localhost "$SSH_PORT" 2>&1 | grep -q "succeeded\|open"; then
        echo -e "${GREEN}✓${NC} Puerto $SSH_PORT está abierto localmente\n"
    else
        echo -e "${RED}✗${NC} Puerto $SSH_PORT NO está abierto localmente\n"
        echo -e "${YELLOW}Esto confirma que SSH no está escuchando en ese puerto${NC}\n"
    fi
else
    echo -e "${YELLOW}⚠${NC}  netcat no disponible para prueba\n"
fi

# 8. Resumen y solución
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     💡  SOLUCIÓN RECOMENDADA                             ║${NC}"
echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════╣${NC}"

if [ "$CONFIG_PORT" != "$SSH_PORT" ] && [ -n "$CONFIG_PORT" ]; then
    echo -e "${CYAN}${BOLD}║${NC} ${GREEN}1. CONFIGURAR SSH EN PUERTO $SSH_PORT${NC}"
    echo -e "${CYAN}${BOLD}║${NC}    sudo nano /etc/ssh/sshd_config"
    echo -e "${CYAN}${BOLD}║${NC}    Agregar/cambiar: Port $SSH_PORT"
    echo -e "${CYAN}${BOLD}║${NC}    sudo systemctl restart ssh\n"
fi

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}2. VERIFICAR QUE SSH ESTÉ CORRIENDO${NC}"
echo -e "${CYAN}${BOLD}║${NC}    sudo systemctl status ssh"
echo -e "${CYAN}${BOLD}║${NC}    sudo systemctl start ssh\n"

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}3. VERIFICAR HOSTS.DENY${NC}"
echo -e "${CYAN}${BOLD}║${NC}    sudo grep $MAC_IP /etc/hosts.deny"
echo -e "${CYAN}${BOLD}║${NC}    Si está bloqueada: sudo sed -i '/$MAC_IP/d' /etc/hosts.deny\n"

echo -e "${CYAN}${BOLD}║${NC} ${GREEN}4. VERIFICAR EN QUÉ PUERTO ESTÁ ESCUCHANDO${NC}"
echo -e "${CYAN}${BOLD}║${NC}    sudo netstat -tlnp | grep ssh"
echo -e "${CYAN}${BOLD}║${NC}    sudo ss -tlnp | grep ssh\n"

echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
