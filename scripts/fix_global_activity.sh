#!/bin/bash
#
# Script para configurar y activar estadísticas globales de actividad de usuarios
# Ejecutar en ceres.globalchat.org como root
#

set -e

echo "=== CONFIGURACIÓN DE ACTIVIDAD GLOBAL DE USUARIOS ==="
echo

# Función MySQL
run_mysql() {
    mysql -u stats -pstats123 globalchat -e "$1" 2>/dev/null || echo "Error en MySQL"
}

# 1. Verificar estado actual
echo "1. Verificando estado actual de stats_chanstats..."
CURRENT_RECORDS=$(run_mysql "SELECT COUNT(*) FROM stats_chanstats;" | tail -1 | grep -o '[0-9]*' | head -1 2>/dev/null || echo "0")
echo "   Registros actuales: ${CURRENT_RECORDS:-0}"

if [ "${CURRENT_RECORDS:-0}" -eq 0 ]; then
    echo "   ❌ Tabla vacía - necesita configuración"
else
    echo "   ✅ Hay algunos datos, verificando tipos..."
    run_mysql "SELECT type, COUNT(*) FROM stats_chanstats GROUP BY type;"
fi

echo

# 2. Verificar y corregir configuración de chanstats.conf
echo "2. Configurando chanstats.conf..."
CHANSTATS_CONF="/media/globalchat/servicios/bots/anope/conf/chanstats.conf"

if [ -f "$CHANSTATS_CONF" ]; then
    # Backup
    cp "$CHANSTATS_CONF" "${CHANSTATS_CONF}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "   ✅ Backup creado"
    
    # Verificar configuración actual
    echo "   Configuración actual:"
    grep -E "(engine|prefix)" "$CHANSTATS_CONF" | head -5
    
    # Corregir engine si es necesario
    if grep -q 'engine = "mysql"' "$CHANSTATS_CONF"; then
        echo "   🔧 Corrigiendo engine a mysql/main..."
        sed -i 's/engine = "mysql"/engine = "mysql\/main"/' "$CHANSTATS_CONF"
    fi
    
    # Corregir prefix si es necesario  
    if grep -q 'prefix = "anope_"' "$CHANSTATS_CONF"; then
        echo "   🔧 Corrigiendo prefix a stats_..."
        sed -i 's/prefix = "anope_"/prefix = "stats_"/' "$CHANSTATS_CONF"
    fi
    
    echo "   Nueva configuración:"
    grep -E "(engine|prefix)" "$CHANSTATS_CONF" | head -5
    
else
    echo "   ❌ No se encuentra chanstats.conf"
    exit 1
fi

echo

# 3. Verificar que el módulo esté cargado en modules.conf
echo "3. Verificando módulo m_chanstats en modules.conf..."
MODULES_CONF="/media/globalchat/servicios/bots/anope/conf/modules.conf"

if [ -f "$MODULES_CONF" ]; then
    if grep -q "m_chanstats" "$MODULES_CONF"; then
        echo "   ✅ Módulo m_chanstats encontrado en modules.conf"
    else
        echo "   ⚠️  Módulo m_chanstats no encontrado, añadiendo..."
        echo 'module { name = "m_chanstats" }' >> "$MODULES_CONF"
    fi
else
    echo "   ❌ No se encuentra modules.conf"
fi

echo

# 4. Crear/verificar vista anope_chanstats para MagIRC
echo "4. Configurando vista anope_chanstats para MagIRC..."

# Verificar si existe
VIEW_EXISTS=$(run_mysql "SHOW TABLES LIKE 'anope_chanstats';" | grep -c "anope_chanstats" || echo "0")

if [ "$VIEW_EXISTS" -eq 0 ]; then
    echo "   🔧 Creando vista anope_chanstats..."
    run_mysql "CREATE ALGORITHM=UNDEFINED DEFINER=stats@localhost SQL SECURITY DEFINER VIEW anope_chanstats AS SELECT * FROM stats_chanstats;"
    echo "   ✅ Vista creada"
else
    echo "   ✅ Vista anope_chanstats ya existe"
fi

echo

# 5. Verificar estructura de la tabla stats_chanstats
echo "5. Verificando estructura de stats_chanstats..."
run_mysql "SHOW CREATE TABLE stats_chanstats\G" | head -20

echo

# 6. Reiniciar Anope para aplicar cambios
echo "6. Reiniciando Anope para aplicar configuración..."

if systemctl is-active anope >/dev/null 2>&1; then
    echo "   Usando systemctl..."
    systemctl restart anope
    sleep 5
    
    if systemctl is-active anope >/dev/null 2>&1; then
        echo "   ✅ Anope reiniciado con systemctl"
    else
        echo "   ❌ Error reiniciando con systemctl"
    fi
    
elif [ -f /media/globalchat/servicios/bots/anope/bin/anoperc ]; then
    echo "   Usando anoperc..."
    cd /media/globalchat/servicios/bots/anope/
    ./bin/anoperc restart
    sleep 5
    
    if pgrep anope >/dev/null; then
        echo "   ✅ Anope reiniciado con anoperc"
    else
        echo "   ❌ Error reiniciando con anoperc"
    fi
else
    echo "   ⚠️  No se pudo encontrar método de reinicio"
fi

echo

# 7. Monitorear logs para errores
echo "7. Verificando logs de Anope..."
ANOPE_LOG="/media/globalchat/servicios/bots/anope/logs/anope.log"

if [ -f "$ANOPE_LOG" ]; then
    echo "   Últimas líneas del log:"
    tail -10 "$ANOPE_LOG" | grep -v "^$"
    
    echo "   Errores relacionados con chanstats:"
    grep -i "chanstats\|error" "$ANOPE_LOG" | tail -5 || echo "   No se encontraron errores recientes"
fi

echo

# 8. Esperar y verificar generación de estadísticas
echo "8. Esperando generación de nuevas estadísticas..."
echo "   (Esto puede tomar unos minutos dependiendo de la actividad del canal)"

for i in {1..6}; do
    echo "   Verificación $i/6..."
    sleep 30
    
    NEW_RECORDS=$(run_mysql "SELECT COUNT(*) FROM stats_chanstats;" | tail -1 | grep -o '[0-9]*' | head -1 2>/dev/null || echo "0")
    echo "   Registros actuales: ${NEW_RECORDS:-0}"
    
    if [ "${NEW_RECORDS:-0}" -gt "${CURRENT_RECORDS:-0}" ]; then
        echo "   ✅ ¡Nuevas estadísticas detectadas!"
        break
    fi
done

echo

# 9. Verificación final
echo "9. Verificación final de datos..."

echo "   Tipos de estadísticas disponibles:"
run_mysql "SELECT type, COUNT(*) as records FROM stats_chanstats GROUP BY type ORDER BY type;"

echo "   Top 5 usuarios más activos:"
run_mysql "SELECT nick, SUM(letters) as total_letters, SUM(words) as total_words, SUM(line) as total_lines FROM stats_chanstats WHERE type = 'total' GROUP BY nick ORDER BY total_letters DESC LIMIT 5;"

echo "   Actividad de hoy:"
run_mysql "SELECT nick, SUM(letters) as daily_letters FROM stats_chanstats WHERE type = 'daily' GROUP BY nick ORDER BY daily_letters DESC LIMIT 5;"

echo
echo "=== RESULTADO ==="

FINAL_RECORDS=$(run_mysql "SELECT COUNT(*) FROM stats_chanstats;" | tail -1 | grep -o '[0-9]*' | head -1 2>/dev/null || echo "0")

if [ "${FINAL_RECORDS:-0}" -gt 0 ]; then
    echo "✅ ÉXITO: Estadísticas globales configuradas correctamente"
    echo "   📊 Registros en stats_chanstats: ${FINAL_RECORDS}"
    echo "   🔗 Vista anope_chanstats lista para MagIRC"
    echo ""
    echo "🌐 SIGUIENTE PASO:"
    echo "   Actualiza la página 'Usuarios - Actividad global' en MagIRC"
    echo "   URL: https://ceres.globalchat.org/estadisticas/?"
else
    echo "⚠️  Las estadísticas aún se están generando..."
    echo "   Causas posibles:"
    echo "   • Poca actividad en canales monitoreados"
    echo "   • Configuración de canales específicos en chanstats.conf"
    echo "   • Necesita más tiempo para acumular datos"
    echo ""
    echo "📝 Para monitorear:"
    echo "   tail -f /media/globalchat/servicios/bots/anope/logs/anope.log"
    echo "   mysql -u stats -pstats123 globalchat -e 'SELECT COUNT(*) FROM stats_chanstats;'"
fi