#!/bin/bash
cd /Users/fnaveira/mobile/irc_app

# Inicializar git si no existe
if [ ! -d .git ]; then
    echo "Inicializando repositorio git..."
    git init
    git config user.name "Backup"
    git config user.email "backup@local"
fi

# Agregar todos los archivos
echo "Agregando archivos..."
git add -A

# Hacer commit
echo "Creando commit..."
git commit -m "Backup: Cliente IRC GlobalChat con selección de canales, UI moderna y traducción al español"

# Mostrar el último commit
echo ""
echo "✅ Backup completado!"
echo "Último commit:"
git log --oneline -1

