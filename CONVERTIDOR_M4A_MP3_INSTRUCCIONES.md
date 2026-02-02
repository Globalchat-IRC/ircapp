# 🎵 Convertidor M4A a MP3 para Mac

## 📋 Descripción

Convertidor amigable de archivos M4A a MP3 con interfaz gráfica para macOS. Convierte tus archivos de audio con alta calidad (320kbps) de forma sencilla.

## 🚀 Instalación

### Paso 1: Instalar FFmpeg

Este convertidor requiere FFmpeg. Instálalo usando Homebrew:

```bash
# Si no tienes Homebrew, instálalo primero desde https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Luego instala FFmpeg
brew install ffmpeg
```

**Alternativa sin Homebrew:**
- Descarga FFmpeg desde: https://ffmpeg.org/download.html
- Sigue las instrucciones de instalación para macOS

### Paso 2: Usar el Convertidor

Tienes dos formas de usar el convertidor:

#### Opción A: Doble clic (MÁS FÁCIL) 🖱️

1. Busca el archivo `Convertidor_M4A_MP3.command` en Finder
2. Haz **doble clic** sobre él
3. Si es la primera vez, macOS te pedirá permiso:
   - Ve a **Preferencias del Sistema** → **Seguridad y Privacidad**
   - Haz clic en **Abrir de todas formas**
4. Sigue las instrucciones en pantalla

#### Opción B: Desde Terminal 💻

```bash
cd /Users/fnaveira/mobile/irc_app
./convertir_m4a_mp3.sh
```

## 🎯 Cómo usar

Una vez que ejecutes el convertidor, verás un menú con dos opciones:

### 1️⃣ Convertir archivos individuales
- Selecciona uno o varios archivos M4A
- El convertidor los procesará y creará archivos MP3 en la misma ubicación

### 2️⃣ Convertir carpeta completa
- Selecciona una carpeta
- El convertidor buscará todos los archivos M4A dentro
- Convertirá todos automáticamente

## ⚙️ Características

- ✅ Interfaz gráfica amigable con ventanas de diálogo
- ✅ Conversión de alta calidad (320kbps)
- ✅ Procesa múltiples archivos a la vez
- ✅ Busca archivos M4A recursivamente en carpetas
- ✅ Muestra progreso en tiempo real
- ✅ Notificación al completar la conversión
- ✅ Los archivos MP3 se crean en la misma ubicación que los M4A

## 📝 Notas

- Los archivos MP3 se crean con el mismo nombre que los M4A originales
- La calidad de conversión es de 320kbps (alta calidad)
- Los archivos M4A originales **NO se eliminan**
- Si ya existe un archivo MP3 con el mismo nombre, se sobrescribirá

## 🐛 Solución de problemas

### "FFmpeg no está instalado"
- Asegúrate de haber instalado FFmpeg con Homebrew
- Verifica la instalación ejecutando en Terminal: `ffmpeg -version`

### "No se puede abrir porque es de un desarrollador no identificado"
1. Ve a **Preferencias del Sistema** → **Seguridad y Privacidad**
2. En la pestaña **General**, haz clic en **Abrir de todas formas**
3. Vuelve a hacer doble clic en el archivo

### El script no se ejecuta
- Asegúrate de que el archivo tenga permisos de ejecución:
  ```bash
  chmod +x /Users/fnaveira/mobile/irc_app/convertir_m4a_mp3.sh
  chmod +x /Users/fnaveira/mobile/irc_app/Convertidor_M4A_MP3.command
  ```

## 📧 Soporte

Si tienes problemas, verifica:
1. Que FFmpeg esté instalado correctamente
2. Que los archivos M4A no estén corruptos
3. Que tengas permisos de escritura en la carpeta de destino

## 🎉 ¡Listo!

Ahora puedes convertir tus archivos M4A a MP3 fácilmente. ¡Disfruta!
