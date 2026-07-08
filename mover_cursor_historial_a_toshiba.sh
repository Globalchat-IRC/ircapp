#!/bin/bash
# Mueve historial de Cursor al Toshiba. Ejecutar DESPUÉS de cerrar Cursor (Cmd+Q).
set -euo pipefail

TOSHIBA="/Volumes/TOSHIBA EXT2"
DEST="$TOSHIBA/DEV-MACBOOK/cursor"
CURSOR_USER="$HOME/Library/Application Support/Cursor/User"
LINKS=(
  "globalStorage"
  "workspaceStorage"
  "History"
)

CURSOR_DOT="$HOME/.cursor"
PROJECTS_LINK="$CURSOR_DOT/projects"
PROJECTS_DEST="$DEST/projects"

if pgrep -xq "Cursor"; then
  echo "❌ Cierra Cursor completamente (Cmd+Q) y vuelve a ejecutar."
  exit 1
fi

[[ -d "$TOSHIBA" ]] || { echo "❌ Conecta TOSHIBA EXT2"; exit 1; }

mkdir -p "$DEST"

for name in "${LINKS[@]}"; do
  src="$CURSOR_USER/$name"
  dst="$DEST/$name"

  [[ -e "$src" || -L "$src" ]] || { echo "⊘ No existe $name, saltando"; continue; }

  if [[ -L "$src" ]]; then
    echo "✓ $name ya es enlace externo"
    continue
  fi

  echo "→ Moviendo $name..."
  rsync -a "$src/" "$dst/"
  rm -rf "$src"
  ln -s "$dst" "$src"
  echo "✓ $name → $dst"
done

# ~/.cursor/projects (transcripts de agente, formato nuevo)
if [[ -L "$PROJECTS_LINK" ]]; then
  echo "✓ projects ya es enlace externo"
elif [[ -d "$PROJECTS_LINK" ]]; then
  echo "→ Moviendo ~/.cursor/projects..."
  mkdir -p "$PROJECTS_DEST"
  rsync -a "$PROJECTS_LINK/" "$PROJECTS_DEST/"
  mv "$PROJECTS_LINK" "${PROJECTS_LINK}.local_backup_$(date +%Y%m%d)"
  ln -s "$PROJECTS_DEST" "$PROJECTS_LINK"
  echo "✓ projects → $PROJECTS_DEST"
fi

cat > "$TOSHIBA/DEV-MACBOOK/LEEME.txt" <<EOF
DEV-MACBOOK (datos de desarrollo en Toshiba EXT2)
================================================

android/avd/     Emuladores Android (Pixel 9a, Medium Phone)
android/sdk/     Android SDK
cursor/          Historial y chats de Cursor (globalStorage, workspaceStorage, History)

Requiere TOSHIBA EXT2 conectado para emuladores y Cursor.
EOF

echo ""
echo "✅ Listo. Abre Cursor de nuevo."
echo "   Historial en: $DEST"
