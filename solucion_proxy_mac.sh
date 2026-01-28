#!/bin/bash

# Solución para problemas de proxy en Mac que bloquean conexiones locales

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔧  SOLUCIÓN PROXY MAC                               ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}${BOLD}Problema detectado:${NC}"
echo -e "Proxy WPAD configurado puede estar bloqueando conexiones locales\n"

echo -e "${BLUE}${BOLD}Soluciones:${NC}\n"

echo -e "${GREEN}1. DESHABILITAR PROXY PARA CONEXIONES LOCALES (Recomendado)${NC}"
echo -e "   ${CYAN}Preferencias del Sistema → Red → Wi-Fi → Avanzado → Proxy${NC}"
echo -e "   Desmarcar: ${YELLOW}Descubrir servidores proxy automáticamente${NC}\n"

echo -e "${GREEN}2. AGREGAR EXCEPCIÓN PARA RED LOCAL${NC}"
echo -e "   En la misma ventana de Proxy, agregar a ${CYAN}Ignorar estos dominios y hosts:${NC}"
echo -e "   ${YELLOW}192.168.*${NC}"
echo -e "   ${YELLOW}*.local${NC}"
echo -e "   ${YELLOW}localhost${NC}\n"

echo -e "${GREEN}3. USAR SSH SIN PROXY (Temporal)${NC}"
echo -e "   ${CYAN}http_proxy='' https_proxy='' ssh -p 62500 root@192.168.1.42${NC}\n"

echo -e "${GREEN}4. CONFIGURAR SSH PARA IGNORAR PROXY${NC}"
echo -e "   Agregar a ${CYAN}~/.ssh/config${NC}:"
echo -e "   ${YELLOW}Host 192.168.*${NC}"
echo -e "   ${YELLOW}    ProxyCommand none${NC}\n"

echo -e "${CYAN}${BOLD}¿Quieres que configure SSH para ignorar proxy automáticamente?${NC}"
read -p "(s/n): " CONFIGURAR

if [[ "$CONFIGURAR" =~ ^[sS] ]]; then
    SSH_CONFIG="$HOME/.ssh/config"
    
    # Backup
    if [ -f "$SSH_CONFIG" ]; then
        cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓${NC} Backup creado\n"
    fi
    
    # Verificar si ya existe configuración para red local
    if ! grep -q "Host 192.168.\*" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" << 'EOF'

# Ignorar proxy para conexiones de red local
Host 192.168.*
    ProxyCommand none
    NoProxyFor *.local,192.168.*,localhost

EOF
        echo -e "${GREEN}✓${NC} Configuración agregada a ~/.ssh/config\n"
        echo -e "${CYAN}Ahora prueba:${NC}"
        echo -e "  ${GREEN}ssh -p 62500 root@192.168.1.42${NC}\n"
    else
        echo -e "${YELLOW}⚠${NC}  Ya existe configuración para red local\n"
    fi
fi

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     ✅  CONFIGURACIÓN COMPLETADA                         ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
