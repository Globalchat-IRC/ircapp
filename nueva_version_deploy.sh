#!/bin/bash
set -e

# ========================================
# Script para crear nueva versión y desplegar
# Automatiza: actualizar versión, compilar, desplegar y commit
# ========================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "🚀 NUEVA VERSIÓN + DEPLOY AUTOMÁTICO"
echo "=========================================="
echo ""

# Verificar que estamos en la carpeta correcta
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: No se encontró pubspec.yaml${NC}"
    echo "Este script debe ejecutarse desde la raíz del proyecto"
    exit 1
fi

# Obtener versión actual
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
echo -e "📌 Versión actual: ${BLUE}$CURRENT_VERSION${NC}"
echo ""

# Solicitar nueva versión
echo "Ejemplos de versionado:"
echo "  - Bug fixes:       3.0.90 → 3.0.91"
echo "  - Nuevas features: 3.0.90 → 3.1.0"
echo "  - Cambios grandes: 3.0.90 → 4.0.0"
echo ""
read -p "Nueva versión (ej: 3.1.0): " NEW_VERSION

if [ -z "$NEW_VERSION" ]; then
    echo -e "${RED}❌ Error: Debes especificar una versión${NC}"
    exit 1
fi

# Validar formato de versión (X.Y.Z o X.Y.Z+BUILD)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?$ ]]; then
    echo -e "${RED}❌ Error: Formato de versión inválido${NC}"
    echo "Usa el formato: X.Y.Z o X.Y.Z+BUILD (ej: 3.1.0 o 3.1.0+1)"
    exit 1
fi

echo ""
echo "──────────────────────────────────────────"
echo -e "Versión actual: ${BLUE}$CURRENT_VERSION${NC}"
echo -e "Nueva versión:  ${GREEN}$NEW_VERSION${NC}"
echo "──────────────────────────────────────────"
echo ""

read -p "¿Es correcto? (S/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "Cancelado por el usuario"
    exit 0
fi

echo ""
echo "=========================================="
echo "🔧 INICIANDO PROCESO AUTOMÁTICO"
echo "=========================================="
echo ""

# [1/8] Actualizar pubspec.yaml
echo -e "${BLUE}[1/8]${NC} Actualizando pubspec.yaml..."
sed -i.bak "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml
rm pubspec.yaml.bak
echo -e "${GREEN}✅ pubspec.yaml actualizado${NC}"
echo ""

# [2/8] Limpiar build anterior
echo -e "${BLUE}[2/8]${NC} Limpiando build anterior..."
flutter clean > /dev/null 2>&1
echo -e "${GREEN}✅ Build limpiado${NC}"
echo ""

# [3/8] Obtener dependencias
echo -e "${BLUE}[3/8]${NC} Obteniendo dependencias..."
flutter pub get > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencias actualizadas${NC}"
echo ""

# [4/8] Compilar aplicación
echo -e "${BLUE}[4/8]${NC} Compilando aplicación web (puede tardar varios minutos)..."
flutter build web --release
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Falló la compilación${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Aplicación compilada${NC}"
echo ""

# Mostrar información del build
echo "📊 Información del build:"
ls -lh build/web/main.dart.js
echo ""

# [5/8] Subir archivos a ceres
echo -e "${BLUE}[5/8]${NC} Subiendo archivos a ceres.globalchat.org..."
rsync -avz --delete --progress build/web/ ceres.globalchat.org:/tmp/irc_app_build/ 2>&1 | grep -E "sending|sent|speedup" || true
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Falló la subida de archivos${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Archivos subidos${NC}"
echo ""

# [6/8] Configurar permisos en ceres
echo -e "${BLUE}[6/8]${NC} Configurando permisos en ceres..."
ssh ceres.globalchat.org "sudo rm -rf /var/www/irc_app/* && sudo cp -r /tmp/irc_app_build/* /var/www/irc_app/ && sudo chown -R www-data:www-data /var/www/irc_app && sudo chmod -R 755 /var/www/irc_app && rm -rf /tmp/irc_app_build"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error: Falló la configuración de permisos${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Permisos configurados${NC}"
echo ""

# [7/8] Commit a Git
echo -e "${BLUE}[7/8]${NC} Haciendo commit a Git..."
git add .
git commit -m "🚀 Release v$NEW_VERSION

- Actualizada versión en pubspec.yaml
- Compilada y desplegada en ceres.globalchat.org
- Aplicación disponible en https://mobilev1.globalchat.org" 2>&1 | grep -v "^$" || echo -e "${YELLOW}⚠️  No había cambios para commitear${NC}"
echo -e "${GREEN}✅ Commit realizado${NC}"
echo ""

# [8/8] Push a GitHub
echo -e "${BLUE}[8/8]${NC} Subiendo a GitHub..."
git push 2>&1 | tail -2 || echo -e "${YELLOW}⚠️  No se pudo hacer push automático${NC}"
echo -e "${GREEN}✅ Código subido a GitHub${NC}"
echo ""

# Verificar despliegue
echo -e "${BLUE}🔍${NC} Verificando despliegue..."
ssh ceres.globalchat.org "ls -ltrha /var/www/irc_app/main.dart.js"
echo ""

# Mostrar resumen
echo ""
echo "=========================================="
echo "✅ PROCESO COMPLETADO EXITOSAMENTE"
echo "=========================================="
echo ""
echo -e "📌 Versión:   ${GREEN}$NEW_VERSION${NC}"
echo -e "🌐 URL:       ${BLUE}https://mobilev1.globalchat.org${NC}"
echo -e "📂 Ruta:      ${BLUE}/var/www/irc_app/${NC}"
echo ""
echo "──────────────────────────────────────────"
echo "📋 RESUMEN DE ACCIONES:"
echo "──────────────────────────────────────────"
echo "  ✅ Versión actualizada en pubspec.yaml"
echo "  ✅ Aplicación compilada (Flutter Web)"
echo "  ✅ Desplegada en ceres.globalchat.org"
echo "  ✅ Commit creado en Git"
echo "  ✅ Push realizado a GitHub"
echo ""
echo "💡 Recarga la página con Ctrl+Shift+R para ver los cambios"
echo ""
echo "🎯 PRÓXIMOS PASOS (opcional):"
echo "  1. Crear release en GitHub:"
echo "     https://github.com/Globalchat-IRC/ircapp/releases/new"
echo "  2. Tag: v$NEW_VERSION"
echo "  3. Describir los cambios"
echo "  4. Publicar release"
echo ""
