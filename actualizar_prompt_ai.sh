#!/bin/bash

# Script para actualizar el prompt del sistema en ai.globalchat.org
# con los nombres correctos de los bots

set -e

echo "🔄 Actualizando prompt del sistema en ai.globalchat.org..."

# Leer el archivo actual
HTML_FILE="/var/www/ai.globalchat.org/index.html"

if [ ! -f "$HTML_FILE" ]; then
    echo "❌ Error: No se encontró $HTML_FILE"
    exit 1
fi

# Crear backup
cp "$HTML_FILE" "${HTML_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# Nuevo prompt del sistema (actualizado)
NEW_PROMPT='Eres un asistente experto en IRC y en la red GlobalChat. Respondes en español, de forma clara y concreta, y solo sobre:
- GlobalChat (canales, nicks, roles, buenas prácticas).
- Bots/servicios Anope (NickServ, ChanServ, MemoServ, BotServ, HostServ).
- Commands IRC típicos: /join, /part, /nick, /msg, /whois, etc.
- Radio y canales de música de GlobalChat (#nuestrasvoces, #soundmusic, #urbanflow).
- Bots de GlobalChat: RadioBot_GC (radio y peticiones de música), Ayudante, Idle, SeenAllBot, Stats, YoutubeBot.
- Conexión: servidores distribuidos con alta disponibilidad, host irc.globalchat.net, puertos 6667 (texto) o 6697 (SSL).
- Roles y permisos: operadores (@), halfops (%), voice (+), usuarios normales.
- Netiqueta y buenas prácticas.
Si el usuario pregunta algo fuera de este tema, responde brevemente que solo puedes ayudar con GlobalChat y Anope.'

# Actualizar el prompt en el HTML usando sed
# Buscar la línea que contiene "systemPrompt" y reemplazar el contenido entre las comillas
sed -i.tmp "s|const systemPrompt = \`.*\`;|const systemPrompt = \`$NEW_PROMPT\`;|" "$HTML_FILE"

# Verificar que se actualizó correctamente
if grep -q "RadioBot_GC" "$HTML_FILE"; then
    echo "✅ Prompt actualizado correctamente"
    echo "📋 Cambios:"
    echo "   - Agregados nombres correctos de bots: RadioBot_GC, Ayudante, Idle, SeenAllBot, Stats, YoutubeBot"
    echo "   - Información de conexión actualizada"
    echo "   - Información de roles y permisos mejorada"
else
    echo "⚠️ Advertencia: No se pudo verificar la actualización"
fi

echo "✅ Proceso completado"
