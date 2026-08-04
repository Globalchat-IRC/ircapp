#!/bin/bash
# GlobalChat - Menú de Build y Deploy
# Doble clic desde Finder para ejecutar

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

show_menu() {
  RESULT=$(osascript -e '
    tell application "System Events"
      set theButton to button returned of (display dialog "🌐 GlobalChat - Build & Deploy

¿Qué querés hacer?" & return & return & "📁 Directorio: '"$DIR"'" buttons {"Cancelar", "Deploy Token Server", "Deploy Webchat", "Solo Compilar"} default button 3 with title "GlobalChat Deploy" with icon note)
    end tell
  ' 2>/dev/null) || echo "Cancelar"
  echo "$RESULT"
}

do_build() {
  osascript -e 'display notification "Compilando Flutter web con ofuscación..." with title "GlobalChat Build"'
  ./build_web_obfuscated.sh 2>&1 | while IFS= read -r line; do
    echo "$line"
  done
  EXIT_CODE=${PIPESTATUS[0]}
  if [ $EXIT_CODE -eq 0 ]; then
    osascript -e 'display notification "Build completado ✅" with title "GlobalChat Build" sound name "Glass"'
  else
    osascript -e 'display notification "Build falló ❌" with title "GlobalChat Build" sound name "Basso"'
  fi
}

do_deploy_web() {
  osascript -e 'display notification "Compilando + Desplegando webchat a Ceres..." with title "GlobalChat Deploy"'
  ./deploy_web.sh 2>&1 | while IFS= read -r line; do
    echo "$line"
  done
  EXIT_CODE=${PIPESTATUS[0]}
  if [ $EXIT_CODE -eq 0 ]; then
    osascript -e 'display notification "Webchat desplegado ✅" with title "GlobalChat Deploy" sound name "Glass"'
  else
    osascript -e 'display notification "Deploy falló ❌" with title "GlobalChat Deploy" sound name "Basso"'
  fi
}

do_deploy_token() {
  osascript -e 'display notification "Desplegando token server a Ceres..." with title "GlobalChat Deploy"'
  cd token_server && ./deploy_token_server.sh 2>&1 | while IFS= read -r line; do
    echo "$line"
  done
  EXIT_CODE=${PIPESTATUS[0]}
  cd "$DIR"
  if [ $EXIT_CODE -eq 0 ]; then
    osascript -e 'display notification "Token server desplegado ✅" with title "GlobalChat Deploy" sound name "Glass"'
  else
    osascript -e 'display notification "Deploy falló ❌" with title "GlobalChat Deploy" sound name "Basso"'
  fi
}

while true; do
  CHOICE=$(show_menu)
  case "$CHOICE" in
    "Solo Compilar")
      do_build
      ;;
    "Deploy Webchat")
      do_deploy_web
      ;;
    "Deploy Token Server")
      do_deploy_token
      ;;
    *)
      exit 0
      ;;
  esac
done
