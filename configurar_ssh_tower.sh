#!/bin/bash

# Script para configurar acceso SSH a tower

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
echo -e "${CYAN}${BOLD}║     🔧  CONFIGURACIÓN SSH PARA TOWER  🔐                  ║${NC}"
echo -e "${CYAN}${BOLD}║                                                            ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Verificar si tower está en la red
echo -e "${BLUE}${BOLD}1. Verificando conectividad con tower...${NC}"
if ping -c 1 -W 2 tower >/dev/null 2>&1; then
    TOWER_IP=$(ping -c 1 tower 2>/dev/null | grep -oE '\([0-9.]+\)' | tr -d '()')
    echo -e "${GREEN}✓${NC} Tower está accesible en la red: ${CYAN}$TOWER_IP${NC}\n"
else
    echo -e "${RED}✗${NC} No se puede alcanzar 'tower' en la red\n"
    echo -e "${YELLOW}¿Conoces la IP o hostname de tower?${NC}"
    read -p "Ingresa IP o hostname (o Enter para salir): " TOWER_HOST
    if [ -z "$TOWER_HOST" ]; then
        exit 1
    fi
    TOWER_IP="$TOWER_HOST"
fi

# 2. Verificar puertos SSH comunes
echo -e "${BLUE}${BOLD}2. Verificando puerto SSH...${NC}"
SSH_PORT=22
if nc -z -w 2 "$TOWER_IP" 22 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Puerto 22 está abierto\n"
elif nc -z -w 2 "$TOWER_IP" 2222 2>/dev/null; then
    SSH_PORT=2222
    echo -e "${GREEN}✓${NC} Puerto 2222 está abierto (usando este)\n"
else
    echo -e "${YELLOW}⚠${NC}  No se detectó SSH en puertos comunes (22, 2222)\n"
    read -p "¿Qué puerto SSH usa tower? (Enter para 22): " CUSTOM_PORT
    if [ -n "$CUSTOM_PORT" ]; then
        SSH_PORT="$CUSTOM_PORT"
    fi
fi

# 3. Verificar configuración SSH actual
echo -e "${BLUE}${BOLD}3. Verificando configuración SSH...${NC}"
SSH_CONFIG="$HOME/.ssh/config"
SSH_DIR="$HOME/.ssh"

if [ ! -d "$SSH_DIR" ]; then
    echo -e "${YELLOW}Creando directorio .ssh...${NC}"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

# Verificar si ya existe configuración para tower
if grep -q "^Host.*tower" "$SSH_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}⚠${NC}  Ya existe configuración para 'tower' en ~/.ssh/config"
    echo -e "   Configuración actual:"
    grep -A 10 "^Host.*tower" "$SSH_CONFIG" | head -10
    echo ""
    read -p "¿Sobrescribir? (s/n): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[sS] ]]; then
        echo -e "${YELLOW}Operación cancelada${NC}\n"
        exit 0
    fi
    # Eliminar configuración antigua
    sed -i.bak '/^Host.*tower/,/^$/d' "$SSH_CONFIG" 2>/dev/null || true
fi

# 4. Solicitar información de usuario
echo -e "${BLUE}${BOLD}4. Configuración de usuario...${NC}"
read -p "¿Qué usuario usar en tower? (Enter para usar tu usuario actual '$USER'): " TOWER_USER
if [ -z "$TOWER_USER" ]; then
    TOWER_USER="$USER"
fi
echo -e "${GREEN}✓${NC} Usuario: ${CYAN}$TOWER_USER${NC}\n"

# 5. Generar o verificar clave SSH
echo -e "${BLUE}${BOLD}5. Verificando clave SSH...${NC}"
if [ ! -f "$SSH_DIR/id_rsa.pub" ] && [ ! -f "$SSH_DIR/id_ed25519.pub" ]; then
    echo -e "${YELLOW}No se encontró clave SSH pública${NC}"
    read -p "¿Generar nueva clave SSH? (s/n): " GEN_KEY
    if [[ "$GEN_KEY" =~ ^[sS] ]]; then
        ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -C "tower-$(date +%Y%m%d)"
        echo -e "${GREEN}✓${NC} Clave SSH generada\n"
    fi
fi

# Encontrar clave pública
if [ -f "$SSH_DIR/id_ed25519.pub" ]; then
    PUB_KEY="$SSH_DIR/id_ed25519.pub"
elif [ -f "$SSH_DIR/id_rsa.pub" ]; then
    PUB_KEY="$SSH_DIR/id_rsa.pub"
else
    PUB_KEY=""
fi

if [ -n "$PUB_KEY" ]; then
    echo -e "${GREEN}✓${NC} Clave pública encontrada: ${CYAN}$PUB_KEY${NC}"
    echo -e "\n${YELLOW}Tu clave pública SSH:${NC}"
    cat "$PUB_KEY"
    echo ""
    read -p "¿Ya está esta clave en el servidor tower? (s/n): " KEY_COPIED
    if [[ ! "$KEY_COPIED" =~ ^[sS] ]]; then
        echo -e "\n${YELLOW}Para copiar la clave al servidor, ejecuta:${NC}"
        echo -e "${CYAN}ssh-copy-id -p $SSH_PORT $TOWER_USER@$TOWER_IP${NC}\n"
        echo -e "${YELLOW}O manualmente, agrega esta línea a ~/.ssh/authorized_keys en tower:${NC}"
        cat "$PUB_KEY"
        echo ""
        read -p "Presiona Enter cuando hayas copiado la clave..."
    fi
fi

# 6. Agregar configuración a ~/.ssh/config
echo -e "\n${BLUE}${BOLD}6. Agregando configuración a ~/.ssh/config...${NC}"

# Backup del config
if [ -f "$SSH_CONFIG" ]; then
    cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}✓${NC} Backup creado: ${CYAN}$SSH_CONFIG.backup.*${NC}"
fi

# Agregar configuración
cat >> "$SSH_CONFIG" << EOF

# Configuración para tower - $(date +%Y-%m-%d)
Host tower
    HostName $TOWER_IP
    User $TOWER_USER
    Port $SSH_PORT
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

chmod 600 "$SSH_CONFIG" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Configuración agregada a ~/.ssh/config\n"

# 7. Probar conexión
echo -e "${BLUE}${BOLD}7. Probando conexión SSH...${NC}"
echo -e "${YELLOW}Intentando conectar a tower...${NC}\n"

if ssh -o ConnectTimeout=5 -o BatchMode=yes tower "echo 'Conexión exitosa'" 2>/dev/null; then
    echo -e "\n${GREEN}${BOLD}✅ ¡Conexión SSH exitosa!${NC}\n"
    echo -e "${GREEN}Ahora puedes usar:${NC}"
    echo -e "  ${CYAN}ssh tower${NC}"
    echo -e "  ${CYAN}rsync archivo tower:/ruta/${NC}\n"
else
    echo -e "\n${YELLOW}⚠${NC}  La conexión automática falló, pero la configuración está lista.\n"
    echo -e "${YELLOW}Posibles causas:${NC}"
    echo -e "  • La clave SSH no está en el servidor"
    echo -e "  • El servidor SSH requiere autenticación por contraseña"
    echo -e "  • El firewall está bloqueando\n"
    echo -e "${YELLOW}Intenta conectar manualmente:${NC}"
    echo -e "  ${CYAN}ssh tower${NC}\n"
    echo -e "${YELLOW}Si necesitas copiar tu clave:${NC}"
    if [ -n "$PUB_KEY" ]; then
        echo -e "  ${CYAN}ssh-copy-id -p $SSH_PORT $TOWER_USER@$TOWER_IP${NC}\n"
    fi
fi

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                            ║${NC}"
echo -e "${CYAN}${BOLD}║     ✅  CONFIGURACIÓN COMPLETADA                          ║${NC}"
echo -e "${CYAN}${BOLD}║                                                            ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
