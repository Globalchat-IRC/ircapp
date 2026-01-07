#!/bin/bash

# Script para corregir el MIME type del Service Worker en Apache2

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🔧 Corrigiendo configuración de Apache2 para Service Worker${NC}"

ssh ceres.globalchat.org "sudo bash -c 'cat >> /etc/apache2/sites-available/mobilev1.globalchat.org-le-ssl.conf << \"APACHE_EOF\"

    # Service Worker - MIME type correcto
    <FilesMatch \"flutter_service_worker\.js\">
        Header set Content-Type \"application/javascript\"
    </FilesMatch>
    
    # Asegurar que el Service Worker se sirva correctamente
    <LocationMatch \"^/flutter_service_worker\.js\">
        Header set Content-Type \"application/javascript\"
        Header set Service-Worker-Allowed \"/\"
    </LocationMatch>
APACHE_EOF
'"

echo -e "${YELLOW}🔍 Verificando configuración...${NC}"
ssh ceres.globalchat.org "sudo apache2ctl configtest"

echo -e "${YELLOW}🔄 Recargando Apache2...${NC}"
ssh ceres.globalchat.org "sudo systemctl reload apache2"

echo -e "${GREEN}✅ Configuración actualizada!${NC}"


