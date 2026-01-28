#!/bin/bash

# Script para monitorear el progreso de la copia de temporal2026.photoslibrary

DEST="/Volumes/TOSHIBA EXT 1/catalog_photos/temporal2026.photoslibrary"
LOG="/tmp/ditto_temporal2026.log"
INTERVALO=30  # segundos entre verificaciones

echo "═══════════════════════════════════════════════════════════════"
echo "  MONITOREO DE COPIA: temporal2026.photoslibrary"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Verificando cada $INTERVALO segundos..."
echo "Presiona Ctrl+C para detener"
echo ""

# Función para obtener tamaño formateado
formatear_tamano() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$((bytes / 1073741824)) GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$((bytes / 1048576)) MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "${bytes} B"
    fi
}

# Contador de iteraciones
ITERACION=0

while true; do
    ITERACION=$((ITERACION + 1))
    FECHA=$(date '+%H:%M:%S')
    
    # Verificar si el proceso está corriendo
    PROCESO=$(ps aux | grep "[d]itto.*temporal2026" | wc -l)
    
    # Obtener estadísticas
    if [ -d "$DEST" ]; then
        TAMANO_ACTUAL=$(du -sk "$DEST" 2>/dev/null | awk '{print $1}')
        TAMANO_ACTUAL_BYTES=$((TAMANO_ACTUAL * 1024))
        ARCHIVOS=$(find "$DEST" -type f 2>/dev/null | wc -l | tr -d ' ')
        DIRECTORIOS=$(find "$DEST" -type d 2>/dev/null | wc -l | tr -d ' ')
    else
        TAMANO_ACTUAL=0
        TAMANO_ACTUAL_BYTES=0
        ARCHIVOS=0
        DIRECTORIOS=0
    fi
    
    # Calcular velocidad (comparar con iteración anterior)
    if [ -n "$TAMANO_ANTERIOR" ] && [ "$TAMANO_ANTERIOR" -gt 0 ]; then
        DIFERENCIA=$((TAMANO_ACTUAL - TAMANO_ANTERIOR))
        VELOCIDAD=$((DIFERENCIA * 1024 / INTERVALO))  # bytes por segundo
        VELOCIDAD_MB=$((VELOCIDAD / 1048576))
    else
        VELOCIDAD=0
        VELOCIDAD_MB=0
    fi
    
    # Mostrar información
    echo "═══════════════════════════════════════════════════════════════"
    echo "  [$FECHA] Verificación #$ITERACION"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [ "$PROCESO" -gt 0 ]; then
        echo "  Estado: ✅ PROCESO ACTIVO"
    else
        echo "  Estado: ⚠️  PROCESO NO DETECTADO"
    fi
    
    echo ""
    echo "  Progreso:"
    echo "    • Tamaño copiado: $(formatear_tamano $TAMANO_ACTUAL_BYTES)"
    echo "    • Archivos: $ARCHIVOS"
    echo "    • Directorios: $DIRECTORIOS"
    
    if [ "$VELOCIDAD_MB" -gt 0 ]; then
        echo "    • Velocidad: ~${VELOCIDAD_MB} MB/s"
        
        # Estimar tiempo restante (asumiendo ~86 GB total)
        if [ "$VELOCIDAD" -gt 0 ]; then
            TOTAL_ESTIMADO=$((86 * 1024 * 1024 * 1024))  # 86 GB en bytes
            RESTANTE=$((TOTAL_ESTIMADO - TAMANO_ACTUAL_BYTES))
            if [ "$RESTANTE" -gt 0 ]; then
                SEGUNDOS_RESTANTES=$((RESTANTE / VELOCIDAD))
                HORAS=$((SEGUNDOS_RESTANTES / 3600))
                MINUTOS=$(((SEGUNDOS_RESTANTES % 3600) / 60))
                echo "    • Tiempo estimado restante: ~${HORAS}h ${MINUTOS}m"
            fi
        fi
    fi
    
    # Mostrar últimas líneas del log si existe
    if [ -f "$LOG" ]; then
        ULTIMAS_LINEAS=$(tail -2 "$LOG" 2>/dev/null | grep -v "^$" | tail -1)
        if [ -n "$ULTIMAS_LINEAS" ]; then
            echo ""
            echo "  Última actividad:"
            echo "    $ULTIMAS_LINEAS"
        fi
    fi
    
    echo ""
    
    # Guardar tamaño actual para próxima iteración
    TAMANO_ANTERIOR=$TAMANO_ACTUAL
    
    # Esperar antes de siguiente verificación
    sleep $INTERVALO
done
