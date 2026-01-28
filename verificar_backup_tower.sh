#!/bin/bash

# Script para verificar el backup en tower

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     🔍  VERIFICACIÓN BACKUP EN TOWER                     ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}${BOLD}Verificando como usuario root...${NC}\n"

# Verificar como root
ssh -p 62500 root@192.168.1.42 << 'EOF'
echo "Usuario actual: $(whoami)"
echo "Directorio home: $HOME"
echo ""
echo "📁 Contenido de ~/backups/photos_db/:"
if [ -d ~/backups/photos_db ]; then
    ls -lah ~/backups/photos_db/
    echo ""
    echo "📊 Información del archivo:"
    if [ -f ~/backups/photos_db/Photos.sqlite ]; then
        ls -lh ~/backups/photos_db/Photos.sqlite
        echo ""
        echo "Ruta completa: $(realpath ~/backups/photos_db/Photos.sqlite)"
        echo "Tamaño: $(du -h ~/backups/photos_db/Photos.sqlite | cut -f1)"
    else
        echo "✗ Archivo Photos.sqlite no encontrado"
    fi
else
    echo "✗ Directorio ~/backups/photos_db/ no existe"
fi
echo ""
echo "🔍 Buscando en todo el sistema:"
find /root -name "Photos.sqlite" 2>/dev/null | head -5
EOF

echo ""
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     💡  INSTRUCCIONES PARA ACCEDER                       ║${NC}"
echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}${BOLD}║${NC} El archivo está en: ${GREEN}/root/backups/photos_db/Photos.sqlite${NC}"
echo -e "${CYAN}${BOLD}║${NC}"
echo -e "${CYAN}${BOLD}║${NC} Para verlo, conecta como root:"
echo -e "${CYAN}${BOLD}║${NC}   ${GREEN}ssh -p 62500 root@192.168.1.42${NC}"
echo -e "${CYAN}${BOLD}║${NC}"
echo -e "${CYAN}${BOLD}║${NC} Luego ejecuta:"
echo -e "${CYAN}${BOLD}║${NC}   ${GREEN}ls -lh ~/backups/photos_db/${NC}"
echo -e "${CYAN}${BOLD}║${NC}   ${GREEN}ls -lh /root/backups/photos_db/${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
