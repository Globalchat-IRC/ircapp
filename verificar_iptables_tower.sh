#!/bin/bash

# Script para ejecutar EN TOWER y verificar/desbloquear iptables
# Ejecutar: sudo bash verificar_iptables_tower.sh

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
echo -e "${CYAN}${BOLD}║     🔍  VERIFICACIÓN IPTABLES EN TOWER                    ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

# 1. Verificar si iptables está activo
echo -e "${BLUE}${BOLD}1. Estado de iptables:${NC}"
if command -v iptables >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} iptables está instalado"
    
    # Verificar reglas
    RULE_COUNT=$(iptables -L -n | wc -l)
    echo -e "   Total de reglas: ${CYAN}$RULE_COUNT${NC}\n"
else
    echo -e "${RED}✗${NC} iptables no está instalado\n"
    exit 1
fi

# 2. Buscar reglas que bloqueen la IP del Mac
echo -e "${BLUE}${BOLD}2. Buscando reglas que bloqueen $MAC_IP:${NC}"
BLOCKED_RULES=$(iptables -L INPUT -n -v | grep "$MAC_IP" || echo "")

if [ -n "$BLOCKED_RULES" ]; then
    echo -e "${RED}✗${NC} Se encontraron reglas que afectan a $MAC_IP:\n"
    echo -e "${YELLOW}Reglas encontradas:${NC}"
    iptables -L INPUT -n -v | grep "$MAC_IP"
    echo ""
    
    # Buscar específicamente DROP o REJECT
    DROP_RULES=$(iptables -L INPUT -n | grep "$MAC_IP" | grep -i "drop\|reject" || echo "")
    if [ -n "$DROP_RULES" ]; then
        echo -e "${RED}${BOLD}⚠️  REGLAS DE BLOQUEO ENCONTRADAS:${NC}\n"
        iptables -L INPUT -n --line-numbers | grep "$MAC_IP"
        echo ""
        
        echo -e "${YELLOW}${BOLD}Para desbloquear, ejecuta:${NC}"
        echo -e "${GREEN}sudo iptables -D INPUT -s $MAC_IP -j DROP${NC}"
        echo -e "${GREEN}sudo iptables -D INPUT -s $MAC_IP -j REJECT${NC}"
        echo ""
        echo -e "${CYAN}O elimina por número de línea:${NC}"
        echo -e "${GREEN}sudo iptables -D INPUT <NUMERO_LINEA>${NC}"
        echo ""
    fi
else
    echo -e "${GREEN}✓${NC} No se encontraron reglas específicas para $MAC_IP\n"
fi

# 3. Ver todas las reglas de INPUT
echo -e "${BLUE}${BOLD}3. Todas las reglas de INPUT (primeras 20):${NC}"
iptables -L INPUT -n --line-numbers | head -25
echo ""

# 4. Ver reglas relacionadas con SSH
echo -e "${BLUE}${BOLD}4. Reglas relacionadas con SSH (puerto $SSH_PORT):${NC}"
SSH_RULES=$(iptables -L INPUT -n --line-numbers | grep -E ":$SSH_PORT|ssh" || echo "")
if [ -n "$SSH_RULES" ]; then
    echo "$SSH_RULES"
else
    echo -e "${YELLOW}No hay reglas específicas para SSH en puerto $SSH_PORT${NC}"
fi
echo ""

# 5. Verificar si hay políticas por defecto que bloqueen
echo -e "${BLUE}${BOLD}5. Políticas por defecto:${NC}"
DEFAULT_POLICY=$(iptables -L INPUT | head -1 | awk '{print $4}')
echo -e "   Política INPUT: ${CYAN}$DEFAULT_POLICY${NC}"
if [ "$DEFAULT_POLICY" = "DROP" ] || [ "$DEFAULT_POLICY" = "REJECT" ]; then
    echo -e "${YELLOW}⚠${NC}  La política por defecto es $DEFAULT_POLICY (bloquea todo por defecto)"
    echo -e "${CYAN}Necesitas reglas específicas que permitan tu IP${NC}\n"
else
    echo -e "${GREEN}✓${NC} Política por defecto permite conexiones\n"
fi

# 6. Verificar reglas de OUTPUT (por si acaso)
echo -e "${BLUE}${BOLD}6. Verificando OUTPUT (por si hay bloqueo de salida):${NC}"
OUTPUT_BLOCKED=$(iptables -L OUTPUT -n | grep "$MAC_IP" | grep -i "drop\|reject" || echo "")
if [ -n "$OUTPUT_BLOCKED" ]; then
    echo -e "${RED}✗${NC} Hay reglas que bloquean salida hacia $MAC_IP:"
    iptables -L OUTPUT -n | grep "$MAC_IP"
    echo ""
else
    echo -e "${GREEN}✓${NC} No hay bloqueo de salida hacia $MAC_IP\n"
fi

# 7. Resumen y comandos de desbloqueo
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║     💡  COMANDOS PARA DESBLOQUEAR                        ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 1: Eliminar reglas específicas de bloqueo${NC}"
echo -e "${GREEN}sudo iptables -D INPUT -s $MAC_IP -j DROP${NC}"
echo -e "${GREEN}sudo iptables -D INPUT -s $MAC_IP -j REJECT${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 2: Permitir explícitamente tu IP${NC}"
echo -e "${GREEN}sudo iptables -I INPUT -s $MAC_IP -j ACCEPT${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 3: Permitir puerto SSH desde tu IP${NC}"
echo -e "${GREEN}sudo iptables -I INPUT -p tcp -s $MAC_IP --dport $SSH_PORT -j ACCEPT${NC}\n"

echo -e "${YELLOW}${BOLD}Opción 4: Ver reglas con números de línea (para eliminar específicas)${NC}"
echo -e "${GREEN}sudo iptables -L INPUT -n --line-numbers${NC}"
echo -e "${CYAN}Luego elimina con: sudo iptables -D INPUT <NUMERO>${NC}\n"

echo -e "${YELLOW}${BOLD}Para guardar cambios permanentemente (si usas iptables-persistent):${NC}"
echo -e "${GREEN}sudo netfilter-persistent save${NC}"
echo -e "${CYAN}O:${NC}"
echo -e "${GREEN}sudo iptables-save > /etc/iptables/rules.v4${NC}\n"

echo -e "${CYAN}${BOLD}Después de desbloquear, verifica desde tu Mac:${NC}"
echo -e "${BLUE}ssh -p $SSH_PORT root@192.168.1.42 'echo OK'${NC}\n"
