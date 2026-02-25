#!/bin/bash
#
# Script para diagnosticar y reparar estadísticas de actividad IRC
# Ejecutar en el servidor ceres.globalchat.org como root
#

set -e

echo "=== Diagnóstico de Estadísticas de Actividad IRC ==="
echo

# Función para ejecutar MySQL
run_mysql() {
    mysql -u stats -pstats123 globalchat -e "$1" 2>/dev/null || echo "Error en consulta MySQL"
}

# 1. Verificar tabla stats_chanstats
echo "1. Verificando tabla stats_chanstats..."
CHANSTATS_COUNT=$(run_mysql "SELECT COUNT(*) FROM stats_chanstats;" | tail -1 | grep -o '[0-9]*' | head -1)
echo "   Registros en stats_chanstats: ${CHANSTATS_COUNT:-0}"

if [ "${CHANSTATS_COUNT:-0}" -eq 0 ]; then
    echo "   ⚠️  La tabla stats_chanstats está vacía"
    NEEDS_FIX=1
else
    echo "   ✅ La tabla tiene datos"
    echo "   Tipos de estadísticas:"
    run_mysql "SELECT DISTINCT type, COUNT(*) FROM stats_chanstats GROUP BY type;"
fi

echo

# 2. Verificar módulo m_chanstats en Anope
echo "2. Verificando módulo m_chanstats..."
if pgrep anope > /dev/null; then
    echo "   ✅ Anope está ejecutándose"
    
    # Verificar logs recientes
    if [ -f /media/globalchat/servicios/bots/anope/logs/anope.log ]; then
        CHANSTATS_ERRORS=$(grep -i "chanstats\|error" /media/globalchat/servicios/bots/anope/logs/anope.log | tail -5)
        if [ -n "$CHANSTATS_ERRORS" ]; then
            echo "   ⚠️  Errores recientes en logs:"
            echo "$CHANSTATS_ERRORS"
        else
            echo "   ✅ No se encontraron errores recientes"
        fi
    fi
else
    echo "   ❌ Anope no está ejecutándose"
    NEEDS_FIX=1
fi

echo

# 3. Verificar configuración chanstats.conf
echo "3. Verificando configuración chanstats.conf..."
if [ -f /media/globalchat/servicios/bots/anope/conf/chanstats.conf ]; then
    ENGINE=$(grep 'engine =' /media/globalchat/servicios/bots/anope/conf/chanstats.conf | head -1)
    PREFIX=$(grep 'prefix =' /media/globalchat/servicios/bots/anope/conf/chanstats.conf | head -1)
    
    echo "   Engine configurado: $ENGINE"
    echo "   Prefix configurado: $PREFIX"
    
    if echo "$ENGINE" | grep -q '"mysql/main"'; then
        echo "   ✅ Engine correcto (mysql/main)"
    else
        echo "   ⚠️  Engine incorrecto, debería ser mysql/main"
        NEEDS_FIX=1
    fi
    
    if echo "$PREFIX" | grep -q '"stats_"'; then
        echo "   ✅ Prefix correcto (stats_)"
    else
        echo "   ⚠️  Prefix incorrecto, debería ser stats_"
        NEEDS_FIX=1
    fi
else
    echo "   ❌ No se encuentra chanstats.conf"
    NEEDS_FIX=1
fi

echo

# 4. Verificar vista anope_chanstats para MagIRC
echo "4. Verificando vista anope_chanstats..."
VIEW_EXISTS=$(run_mysql "SHOW TABLES LIKE 'anope_chanstats';" | grep -c "anope_chanstats" || echo "0")
if [ "$VIEW_EXISTS" -eq 1 ]; then
    echo "   ✅ Vista anope_chanstats existe"
else
    echo "   ⚠️  Vista anope_chanstats no existe, creando..."
    run_mysql "CREATE ALGORITHM=UNDEFINED DEFINER=stats@localhost SQL SECURITY DEFINER VIEW anope_chanstats AS SELECT * FROM stats_chanstats;"
    echo "   ✅ Vista creada"
fi

echo

# 5. Aplicar correcciones si es necesario
if [ "${NEEDS_FIX:-0}" -eq 1 ]; then
    echo "5. Aplicando correcciones..."
    
    # Corregir chanstats.conf si es necesario
    if [ -f /media/globalchat/servicios/bots/anope/conf/chanstats.conf ]; then
        echo "   Corrigiendo chanstats.conf..."
        cp /media/globalchat/servicios/bots/anope/conf/chanstats.conf /media/globalchat/servicios/bots/anope/conf/chanstats.conf.backup
        sed -i 's/engine = "mysql"/engine = "mysql\/main"/' /media/globalchat/servicios/bots/anope/conf/chanstats.conf
        sed -i 's/prefix = "anope_"/prefix = "stats_"/' /media/globalchat/servicios/bots/anope/conf/chanstats.conf
        echo "   ✅ Configuración corregida"
    fi
    
    # Reiniciar Anope
    echo "   Reiniciando Anope..."
    if systemctl is-active anope > /dev/null 2>&1; then
        systemctl restart anope
        sleep 5
    elif [ -f /media/globalchat/servicios/bots/anope/bin/anoperc ]; then
        cd /media/globalchat/servicios/bots/anope/
        ./bin/anoperc restart
        sleep 5
    fi
    
    if pgrep anope > /dev/null; then
        echo "   ✅ Anope reiniciado correctamente"
    else
        echo "   ❌ Error al reiniciar Anope"
    fi
else
    echo "5. ✅ No se necesitan correcciones"
fi

echo
echo "=== Verificación final ==="

# Esperar un poco para que se generen estadísticas
echo "Esperando 30 segundos para nueva actividad..."
sleep 30

# Verificar nuevamente
NEW_COUNT=$(run_mysql "SELECT COUNT(*) FROM stats_chanstats;" | tail -1 | grep -o '[0-9]*' | head -1)
echo "Registros después del arreglo: ${NEW_COUNT:-0}"

if [ "${NEW_COUNT:-0}" -gt "${CHANSTATS_COUNT:-0}" ]; then
    echo "✅ ¡Las estadísticas se están generando correctamente!"
else
    echo "⚠️  Las estadísticas aún no se generan. Posibles causas:"
    echo "   - Poca actividad en los canales monitoreados"
    echo "   - Configuración de canales en chanstats.conf"
    echo "   - Revisar logs de Anope para más detalles"
fi

echo
echo "Para monitorear el progreso:"
echo "   tail -f /media/globalchat/servicios/bots/anope/logs/anope.log"
echo "   mysql -u stats -pstats123 globalchat -e 'SELECT COUNT(*) FROM stats_chanstats;'"