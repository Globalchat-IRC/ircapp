# 📸 Cómo Ejecutar los Scripts de Backup de Photos

## Scripts Disponibles

### 1. `copiar_photos_db_tower_robusto.sh`
**Copia solo el archivo SQLite** (271M)
- Más rápido
- Solo copia `Photos.sqlite`
- Ideal si solo necesitas la base de datos

### 2. `copiar_biblioteca_photos_completa.sh`
**Copia toda la biblioteca de Photos**
- Más lento (copia todo)
- Copia toda la estructura `temporal.photoslibrary`
- Ideal si necesitas la biblioteca completa

---

## 🚀 Cómo Ejecutar

### Paso 1: Abrir Terminal
Abre Terminal o iTerm en tu Mac

### Paso 2: Ir al directorio
```bash
cd /Users/fnaveira/mobile/irc_app
```

### Paso 3: Ejecutar el script

**Opción A: Solo el SQLite (rápido)**
```bash
./copiar_photos_db_tower_robusto.sh
```

**Opción B: Toda la biblioteca (completo)**
```bash
./copiar_biblioteca_photos_completa.sh
```

---

## ⚠️ Permisos Necesarios

Si aparece "Operation not permitted":
1. Ve a: **Preferencias del Sistema → Privacidad y Seguridad → Acceso completo al disco**
2. Otorga permisos a **Terminal** (o iTerm si lo usas)
3. Vuelve a ejecutar el script

---

## 📍 Ubicación del Backup

- **Solo SQLite**: `/backups/photos_db/Photos.sqlite`
- **Biblioteca completa**: `/backups/photos_db/temporal.photoslibrary/`

---

## ✅ Verificar que Funcionó

```bash
ssh -p 62500 root@192.168.1.42 "ls -lh /backups/photos_db/"
```

---

## 🔧 Solución de Problemas

**Si la conexión se cierra:**
- El script ya tiene opciones para mantener la conexión activa
- Si sigue fallando, verifica la configuración SSH en tower

**Si no ves el archivo:**
- Verifica que estás conectado como root
- Usa la ruta absoluta: `/backups/photos_db/`
