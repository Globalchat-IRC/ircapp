#!/bin/bash

# Script para ejecutar EN TOWER para configurar el servicio SSH
# Copia este script a tower y ejecútalo con: sudo bash configurar_ssh_en_tower.sh

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                            ║${NC}"
echo -e "${CYAN}${BOLD}║     🔧  CONFIGURACIÓN SSH EN TOWER                        ║${NC}"
echo -e "${CYAN}${BOLD}║                                                            ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗${NC} Este script debe ejecutarse como root (usa sudo)\n"
    exit 1
fi

# 1. Detectar sistema operativo
echo -e "${BLUE}${BOLD}1. Detectando sistema operativo...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    echo -e "${GREEN}✓${NC} Sistema: ${CYAN}$PRETTY_NAME${NC}\n"
else
    echo -e "${YELLOW}⚠${NC}  No se pudo detectar el sistema operativo\n"
    OS="unknown"
fi

# 2. Verificar estado actual del servicio SSH
echo -e "${BLUE}${BOLD}2. Verificando estado del servicio SSH...${NC}"

# Detectar qué servicio SSH está instalado
SSH_SERVICE=""
if systemctl list-unit-files | grep -q "sshd.service"; then
    SSH_SERVICE="sshd"
elif systemctl list-unit-files | grep -q "ssh.service"; then
    SSH_SERVICE="ssh"
elif service --status-all 2>&1 | grep -q ssh; then
    SSH_SERVICE="ssh"
else
    echo -e "${YELLOW}⚠${NC}  No se encontró servicio SSH instalado\n"
    SSH_SERVICE="none"
fi

if [ "$SSH_SERVICE" != "none" ]; then
    if systemctl is-active --quiet $SSH_SERVICE 2>/dev/null || service $SSH_SERVICE status >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Servicio SSH está corriendo\n"
        SSH_RUNNING=true
    else
        echo -e "${RED}✗${NC} Servicio SSH NO está corriendo\n"
        SSH_RUNNING=false
    fi
    
    # Verificar en qué puerto está escuchando
    echo -e "${BLUE}${BOLD}3. Verificando puertos SSH...${NC}"
    SSHD_PORTS=$(netstat -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | cut -d: -f2 | sort -u)
    if [ -z "$SSHD_PORTS" ]; then
        SSHD_PORTS=$(ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}' | cut -d: -f2 | sort -u)
    fi
    
    if [ -n "$SSHD_PORTS" ]; then
        echo -e "${GREEN}✓${NC} SSH está escuchando en puerto(s): ${CYAN}$SSHD_PORTS${NC}\n"
    else
        echo -e "${YELLOW}⚠${NC}  No se detectó SSH escuchando en ningún puerto\n"
    fi
fi

# 4. Verificar configuración SSH
echo -e "${BLUE}${BOLD}4. Verificando configuración SSH...${NC}"
SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
    SSH_PORT=$(grep "^Port" "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' | head -1)
    if [ -z "$SSH_PORT" ]; then
        SSH_PORT="22"  # Puerto por defecto
    fi
    echo -e "${GREEN}✓${NC} Archivo de configuración encontrado"
    echo -e "   Puerto configurado: ${CYAN}$SSH_PORT${NC}\n"
else
    echo -e "${RED}✗${NC} Archivo de configuración SSH no encontrado\n"
fi

# 5. Verificar firewall
echo -e "${BLUE}${BOLD}5. Verificando firewall...${NC}"
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(ufw status | head -1)
    echo -e "${GREEN}✓${NC} UFW detectado: ${CYAN}$UFW_STATUS${NC}"
    if echo "$UFW_STATUS" | grep -qi "active"; then
        UFW_SSH=$(ufw status | grep -i ssh || echo "SSH no encontrado en reglas")
        echo -e "   Reglas SSH: ${CYAN}$UFW_SSH${NC}\n"
    fi
elif command -v firewall-cmd >/dev/null 2>&1; then
    if systemctl is-active --quiet firewalld; then
        echo -e "${GREEN}✓${NC} Firewalld está activo\n"
        firewall-cmd --list-all | grep -E "(ports|services)" || true
    else
        echo -e "${YELLOW}⚠${NC}  Firewalld no está activo\n"
    fi
else
    echo -e "${YELLOW}⚠${NC}  No se detectó firewall configurado\n"
fi

# 6. Acciones recomendadas
echo -e "${BLUE}${BOLD}6. Acciones recomendadas:${NC}\n"

if [ "$SSH_RUNNING" = false ]; then
    echo -e "${YELLOW}⚠${NC}  El servicio SSH no está corriendo.\n"
    echo -e "${CYAN}Para iniciarlo:${NC}"
    if [ "$SSH_SERVICE" = "sshd" ]; then
        echo -e "  ${GREEN}sudo systemctl start sshd${NC}"
        echo -e "  ${GREEN}sudo systemctl enable sshd${NC}  # Para iniciar automáticamente\n"
    elif [ "$SSH_SERVICE" = "ssh" ]; then
        echo -e "  ${GREEN}sudo systemctl start ssh${NC}"
        echo -e "  ${GREEN}sudo systemctl enable ssh${NC}  # Para iniciar automáticamente\n"
    else
        echo -e "  ${GREEN}sudo service ssh start${NC}\n"
    fi
fi

# Verificar si necesita configurar puerto 62500
if [ "$SSH_PORT" != "62500" ]; then
    echo -e "${YELLOW}⚠${NC}  SSH está configurado en puerto $SSH_PORT, pero necesitas el 62500.\n"
    echo -e "${CYAN}Para cambiar al puerto 62500:${NC}"
    echo -e "  1. Editar ${CYAN}/etc/ssh/sshd_config${NC}:"
    echo -e "     ${GREEN}sudo nano /etc/ssh/sshd_config${NC}"
    echo -e "  2. Cambiar o agregar la línea:"
    echo -e "     ${CYAN}Port 62500${NC}"
    echo -e "  3. Reiniciar el servicio:"
    if [ "$SSH_SERVICE" = "sshd" ]; then
        echo -e "     ${GREEN}sudo systemctl restart sshd${NC}\n"
    else
        echo -e "     ${GREEN}sudo systemctl restart ssh${NC}\n"
    fi
fi

# Configurar firewall
echo -e "${CYAN}Para permitir SSH en el firewall:${NC}"
if command -v ufw >/dev/null 2>&1; then
    echo -e "  ${GREEN}sudo ufw allow 62500/tcp${NC}"
    echo -e "  ${GREEN}sudo ufw allow 22/tcp${NC}  # Puerto estándar también\n"
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo -e "  ${GREEN}sudo firewall-cmd --permanent --add-port=62500/tcp${NC}"
    echo -e "  ${GREEN}sudo firewall-cmd --reload${NC}\n"
fi

# 7. Resumen final
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     📋  RESUMEN                                          ║${NC}"
echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║${NC} Servicio SSH: ${SSH_RUNNING:-unknown}"
echo -e "${CYAN}${BOLD}║${NC} Puerto configurado: $SSH_PORT"
echo -e "${CYAN}${BOLD}║${NC} Puerto(s) escuchando: ${SSHD_PORTS:-ninguno}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}${BOLD}✅ Diagnóstico completado${NC}\n"
echo -e "${YELLOW}Sigue las recomendaciones arriba para configurar SSH correctamente.${NC}\n"
