#!/usr/bin/env python3
"""
Script to check global user activity statistics across the entire IRC network
"""

def print_mysql_commands():
    """Print MySQL commands to check global activity stats"""
    print("=== Comandos MySQL para verificar actividad global ===\n")
    
    # Global user activity (summing across all channels)
    print("1. TOP USUARIOS MÁS ACTIVOS GLOBALMENTE:")
    print('mysql -u stats -pstats123 globalchat -e "')
    print("SELECT nick, ")
    print("       SUM(letters) as total_letters, ")
    print("       SUM(words) as total_words, ")
    print("       SUM(line) as total_lines, ")
    print("       SUM(actions) as total_actions ")
    print("FROM stats_chanstats ")
    print("WHERE type = 'total' ")
    print("GROUP BY nick ")
    print("ORDER BY total_letters DESC ")
    print("LIMIT 20;")
    print('"')
    print()
    
    # Daily global activity
    print("2. ACTIVIDAD GLOBAL DEL DÍA:")
    print('mysql -u stats -pstats123 globalchat -e "')
    print("SELECT nick, ")
    print("       SUM(letters) as daily_letters, ")
    print("       SUM(words) as daily_words, ")
    print("       SUM(line) as daily_lines ")
    print("FROM stats_chanstats ")
    print("WHERE type = 'daily' ")
    print("GROUP BY nick ")
    print("ORDER BY daily_letters DESC ")
    print("LIMIT 15;")
    print('"')
    print()
    
    # Network totals
    print("3. TOTALES DE LA RED:")
    print('mysql -u stats -pstats123 globalchat -e "')
    print("SELECT ")
    print("    'Total Network' as metric,")
    print("    SUM(letters) as total_letters, ")
    print("    SUM(words) as total_words, ")
    print("    SUM(line) as total_lines, ")
    print("    COUNT(DISTINCT nick) as active_users, ")
    print("    COUNT(DISTINCT chan) as active_channels ")
    print("FROM stats_chanstats ")
    print("WHERE type = 'total';")
    print('"')
    print()
    
    # Daily network totals
    print("4. TOTALES DEL DÍA:")
    print('mysql -u stats -pstats123 globalchat -e "')
    print("SELECT ")
    print("    'Daily Network' as metric,")
    print("    SUM(letters) as daily_letters, ")
    print("    SUM(words) as daily_words, ")
    print("    SUM(line) as daily_lines, ")
    print("    COUNT(DISTINCT nick) as daily_active_users ")
    print("FROM stats_chanstats ")
    print("WHERE type = 'daily';")
    print('"')
    print()
    
    # Check if we have the right data structure
    print("5. VERIFICAR ESTRUCTURA DE DATOS:")
    print('mysql -u stats -pstats123 globalchat -e "')
    print("SELECT type, COUNT(*) as records, ")
    print("       MIN(letters) as min_letters, ")
    print("       MAX(letters) as max_letters, ")
    print("       AVG(letters) as avg_letters ")
    print("FROM stats_chanstats ")
    print("GROUP BY type;")
    print('"')
    print()
    
    print("6. ÚLTIMAS ESTADÍSTICAS GENERADAS:")
    print('mysql -u stats -pstats123 globalchat -e "')
    print("SELECT type, chan, nick, letters, words, line, actions ")
    print("FROM stats_chanstats ")
    print("ORDER BY letters DESC ")
    print("LIMIT 10;")
    print('"')

def print_alternative_sources():
    """Print alternative data sources for global activity"""
    print("\n=== FUENTES ALTERNATIVAS PARA ACTIVIDAD GLOBAL ===\n")
    
    print("Si stats_chanstats está vacío, podemos usar:")
    print()
    
    print("1. USUARIOS CONECTADOS ACTUALMENTE (desde UnrealIRCd JSON-RPC):")
    print("   - Crear endpoint PHP que use UnrealIRCd JSON-RPC")
    print("   - Obtener lista completa de usuarios conectados")
    print("   - Calcular estadísticas en tiempo real")
    print()
    
    print("2. LOGS DE UNREALIRCD:")
    print("   - Parsear logs de UnrealIRCd para actividad")
    print("   - Contar mensajes, conexiones, etc.")
    print("   - Generar estadísticas históricas")
    print()
    
    print("3. MÓDULO PERSONALIZADO DE ANOPE:")
    print("   - Crear módulo que recolecte solo estadísticas globales")
    print("   - Almacenar en tabla separada (stats_global_activity)")
    print("   - Independiente de chanstats por canales")

if __name__ == "__main__":
    print("DIAGNÓSTICO DE ACTIVIDAD GLOBAL DE USUARIOS IRC")
    print("=" * 50)
    print_mysql_commands()
    print_alternative_sources()
    
    print("\n=== PASOS SIGUIENTES ===")
    print("1. Ejecuta los comandos MySQL en el servidor")
    print("2. Si stats_chanstats está vacío, verifica módulo m_chanstats")
    print("3. Si no hay datos suficientes, considera fuentes alternativas")
    print("4. Muestra captura de MagIRC para ver qué sección específica necesita datos")