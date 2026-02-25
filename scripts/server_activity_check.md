# Verificación y Configuración de Estadísticas de Actividad IRC

## Problema
Las estadísticas de actividad global de usuarios y canales no aparecen en MagIRC (secciones como "Top 10 - Canales del día / Usuarios del día").

## Verificación paso a paso

### 1. Conecta al servidor y verifica la tabla stats_chanstats

```bash
# Conectar al servidor
ssh root@ceres.globalchat.org

# Verificar si existe la tabla y tiene datos
mysql -u stats -pstats123 globalchat -e "SELECT COUNT(*) as total_records FROM stats_chanstats;"

# Ver tipos de estadísticas disponibles
mysql -u stats -pstats123 globalchat -e "SELECT DISTINCT type FROM stats_chanstats ORDER BY type;"

# Ver estructura de la tabla
mysql -u stats -pstats123 globalchat -e "SHOW CREATE TABLE stats_chanstats\G"
```

### 2. Si la tabla está vacía o no existe, verificar módulo m_chanstats

```bash
# Verificar si el módulo está cargado en Anope
ps aux | grep anope
cd /media/globalchat/servicios/bots/anope/

# Ver logs de Anope para errores del módulo
tail -50 logs/anope.log | grep -i chanstats

# Verificar configuración del módulo
cat conf/chanstats.conf
```

### 3. Si necesitas reconfigurar chanstats.conf

```bash
# Editar configuración
sudo nano /media/globalchat/servicios/bots/anope/conf/chanstats.conf

# Debe contener:
# engine = "mysql/main"
# prefix = "stats_"
```

### 4. Verificar que los canales estén siendo monitoreados

```bash
# Ver si hay vista anope_chanstats para MagIRC
mysql -u stats -pstats123 globalchat -e "SHOW CREATE VIEW anope_chanstats\G"

# Si no existe, crearla:
mysql -u stats -pstats123 globalchat -e "
CREATE ALGORITHM=UNDEFINED DEFINER=stats@localhost SQL SECURITY DEFINER 
VIEW anope_chanstats AS 
SELECT * FROM stats_chanstats;
"
```

### 5. Reiniciar Anope y verificar

```bash
# Reiniciar Anope
sudo systemctl restart anope

# O si no usa systemd:
cd /media/globalchat/servicios/bots/anope/
sudo ./bin/anoperc restart

# Verificar que está funcionando
ps aux | grep anope
tail -20 logs/anope.log

# Esperar unos minutos y verificar si se generan estadísticas
mysql -u stats -pstats123 globalchat -e "SELECT chan, nick, letters, words, line FROM stats_chanstats WHERE letters > 0 ORDER BY letters DESC LIMIT 10;"
```

### 6. Forzar generación de estadísticas (si es necesario)

```bash
# Si el módulo está cargado pero no genera datos, puede necesitar actividad nueva
# O verificar que los canales estén en la configuración de chanstats

# Ver configuración de canales monitoreados
grep -A 20 -B 5 "target" /media/globalchat/servicios/bots/anope/conf/chanstats.conf
```

## Resultado esperado

Después de estos pasos deberías ver:
- Datos en `stats_chanstats` con diferentes tipos (`total`, `daily`, `weekly`, `monthly`)
- Vista `anope_chanstats` funcionando
- MagIRC mostrando estadísticas de actividad en las secciones correspondientes

## Notas importantes

- El módulo `m_chanstats` recolecta estadísticas de mensajes, palabras, acciones, emoticonos, kicks, cambios de modos, etc.
- Las estadísticas se agregan por tipo: `total` (histórico), `daily` (día actual), `weekly` (semana actual), `monthly` (mes actual)
- MagIRC lee estas estadísticas para mostrar tops de usuarios y canales más activos