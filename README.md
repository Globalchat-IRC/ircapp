# IRC App - Cliente IRC Multiplataforma

Un cliente IRC moderno y multiplataforma construido con **Flutter**, diseñado para conectarse a servidores IRC de GlobalChat y otras redes IRC estándar.

**Versión actual: 3.0.3**

---

## 📱 Plataformas Soportadas

- ✅ **macOS** (nativo)
- ✅ **iOS** (iPhone/iPad)
- ✅ **Android**
- ✅ **Web** (PWA)
- ✅ **Windows** (en desarrollo)
- ✅ **Linux** (en desarrollo)

---

## ✨ Características Principales

### 🔌 Conexión IRC
- ✅ Conexión a servidores IRC estándar (RFC 2812)
- ✅ Soporte SSL/TLS para conexiones seguras
- ✅ Selección automática de servidor basada en GeoIP
- ✅ Múltiples perfiles de servidor configurables
- ✅ Reconexión automática
- ✅ Detección de lag y ping en tiempo real

### 💬 Chat y Mensajería
- ✅ Soporte para múltiples canales simultáneamente
- ✅ Mensajes privados (queries)
- ✅ Lista de usuarios en tiempo real
- ✅ Mensajes de acción (/me)
- ✅ Respuestas a mensajes (threads)
- ✅ Edición de mensajes
- ✅ Reacciones con emojis
- ✅ Mensajes con delay configurable
- ✅ Envío inmediato con atajo de teclado
- ✅ Historial de mensajes persistente
- ✅ Búsqueda en mensajes
- ✅ Mensajes fijados (pinned)

### 🎨 Personalización
- ✅ **15+ temas visuales** predefinidos:
  - GlobalChat (clásico)
  - NuestrasVoces
  - Semana Santa Sevilla
  - Canal Sur
  - Y muchos más...
- ✅ **Imágenes de fondo por canal** configurables
- ✅ Fondo ASCII de GlobalChat por defecto
- ✅ Configuración de emojis personalizados
- ✅ Selector de iconos para usuarios
- ✅ Configuración de colores y estilos

### 👥 Gestión de Usuarios
- ✅ Lista de usuarios con avatares
- ✅ Información de usuario (WHOIS)
- ✅ Perfiles de usuario personalizables
- ✅ Sistema de reputación y badges
- ✅ Roles de usuario (OP, Voice, Founder, etc.)
- ✅ Detección automática de robots/bots
- ✅ Lista de contactos
- ✅ Sistema de tags para usuarios

### 🎛️ Moderación
- ✅ **Menú de moderador/founder** integrado
- ✅ Comandos Anope/ChanServ:
  - Kick, Ban, Unban
  - OP/DEOP, Voice/Devoice
  - Cambio de topic
  - Comandos ChanServ directos
- ✅ Panel de moderación avanzado
- ✅ Sistema de reportes de video

### 📻 Radio en Vivo
- ✅ **Reproductor de radio integrado**
- ✅ Múltiples estaciones disponibles:
  - Radio NuestrasVoces
  - SoundMusic
  - Radio Sonic Frequency
- ✅ Información de "Now Playing"
- ✅ Control de volumen
- ✅ Lista de estaciones favoritas
- ✅ Sincronización con canales IRC

### 🎥 Videoconferencias
- ✅ Integración con Jitsi Meet
- ✅ Lanzamiento de videollamadas desde el chat
- ✅ Soporte para múltiples cámaras
- ✅ Compartir pantalla
- ✅ Chat durante videollamadas

### 🔔 Notificaciones
- ✅ Notificaciones del sistema (macOS/Windows)
- ✅ Notificaciones web (PWA)
- ✅ Sonidos personalizables
- ✅ Alertas de menciones
- ✅ Indicador de escritura (typing)

### 🔐 Seguridad y Privacidad
- ✅ Modo incógnito
- ✅ Lista de usuarios ignorados
- ✅ Verificación de email
- ✅ Autenticación con servicios IRC (NickServ)
- ✅ Configuración de privacidad avanzada

### 📊 Funcionalidades Avanzadas
- ✅ Sistema de actualizaciones automáticas
- ✅ Backup y restauración de configuración
- ✅ Exportación de logs
- ✅ Estadísticas de uso
- ✅ Sistema de cache inteligente
- ✅ Soporte para comandos IRC personalizados

---

## 🍎 Características Específicas de macOS

### Interfaz Nativa
- ✅ **Interfaz nativa de macOS** con soporte completo de Cocoa
- ✅ Menú de aplicación nativo
- ✅ Atajos de teclado macOS estándar:
  - `Cmd+F`: Buscar en mensajes
  - `Cmd+N`: Nuevo canal
  - `Cmd+W`: Cerrar pestaña
  - `Cmd+,`: Preferencias
  - `Cmd+E`: Exportar logs
- ✅ Integración con el sistema de notificaciones de macOS
- ✅ Soporte para múltiples ventanas
- ✅ Dock integration

### Permisos y Seguridad
- ✅ **Sandboxing** configurado correctamente
- ✅ Permisos de red para conexiones salientes
- ✅ Permisos de archivos para descargas
- ✅ Soporte para certificados SSL/TLS
- ✅ Aceptación de certificados autofirmados (configurable)

### Rendimiento
- ✅ Optimizado para Apple Silicon (M1/M2/M3)
- ✅ Soporte para Intel (x86_64)
- ✅ Compilación universal (Universal Binary)
- ✅ Gestión eficiente de memoria
- ✅ Cache de mensajes optimizado

### Instalación
- ✅ **Instalador DMG** (.dmg) incluido
- ✅ Instalación drag-and-drop
- ✅ Logo de GlobalChat en el instalador
- ✅ Enlace simbólico a Applications

---

## 📦 Instalación en macOS

### Opción 1: Instalador DMG (Recomendado)

1. Descarga el archivo `irc_app_macos_v3.0.3.dmg` desde la carpeta `releases/`
2. Abre el archivo DMG
3. Arrastra la aplicación a la carpeta Applications
4. Ejecuta la aplicación desde Applications

### Opción 2: Compilación desde Código Fuente

#### Requisitos
- macOS 10.14 o superior
- Xcode 12.0 o superior
- Flutter 3.38.4 o superior
- CocoaPods (se instala automáticamente)

#### Pasos de Compilación

```bash
# 1. Clonar el repositorio
git clone https://github.com/Globalchat-IRC/ircapp.git
cd ircapp

# 2. Obtener dependencias
flutter pub get

# 3. Instalar dependencias de CocoaPods
cd macos
pod install
cd ..

# 4. Compilar la aplicación
flutter build macos --release

# 5. Crear el instalador DMG (opcional)
./build_dmg.sh
```

La aplicación compilada estará en: `build/macos/Build/Products/Release/irc_app.app`

---

## 🚀 Uso Rápido

### Primera Conexión

1. **Abrir la aplicación**
2. **Seleccionar servidor** (selección automática por GeoIP):
   - América: `caliope.globalchat.org`
   - Resto del mundo: `apolo.globalchat.org`, `ceres.globalchat.org`, etc.
3. **Ingresar nickname** (tu nombre de usuario IRC)
4. **Presionar "Conectar"**

### Navegación Básica

- **Unirse a un canal**: Usa el botón "Lista de Canales" o escribe `/join #canal`
- **Enviar mensaje**: Escribe en el campo inferior y presiona Enter
- **Mensaje privado**: Haz clic en un usuario y selecciona "Mensaje Privado"
- **Cambiar de canal**: Haz clic en el nombre del canal en la barra lateral

### Atajos de Teclado (macOS)

| Atajo | Acción |
|-------|--------|
| `Cmd+F` | Buscar en mensajes |
| `Cmd+N` | Nuevo canal |
| `Cmd+W` | Cerrar pestaña/canal |
| `Cmd+,` | Abrir Preferencias |
| `Cmd+E` | Exportar logs |
| `Cmd+K` | Lista de canales |
| `Enter` | Enviar mensaje |
| `Shift+Enter` | Nueva línea |
| `Cmd+Enter` | Enviar inmediatamente (sin delay) |

---

## ⚙️ Configuración

### Ajustes Generales

Accede a **Ajustes** desde el menú o con `Cmd+,`:

- **Tema Visual**: Selecciona entre 15+ temas disponibles
- **Delay de Mensajes**: Configura el tiempo de espera antes de enviar (0-10 segundos)
- **Sonidos**: Activa/desactiva sonidos de notificaciones
- **Privacidad**: Configura modo incógnito y usuarios ignorados

### Imágenes de Fondo por Canal

1. Ve a **Ajustes** → **Imágenes de Fondo por Canal**
2. Haz clic en **"Agregar Imagen de Fondo"**
3. Ingresa el nombre del canal (ej: `#nuestrasvoces`)
4. Ingresa la URL de la imagen
5. Guarda

**Nota**: Si no hay imagen configurada para un canal, se mostrará el fondo ASCII de GlobalChat por defecto.

### Radio

- **Reproducir**: Haz clic en el botón de play en la barra de controles
- **Cambiar estación**: Usa los botones anterior/siguiente
- **Lista de estaciones**: Haz clic en el icono de lista
- **Volumen**: Configurable desde los controles

### Moderación

Si eres moderador o founder de un canal:

1. Haz clic derecho en un usuario o mensaje
2. Selecciona **"Menú Moderador"**
3. Elige la acción deseada:
   - Kick, Ban, Unban
   - OP/DEOP, Voice/Devoice
   - Comandos ChanServ

---

## 🔧 Cambios y Mejoras (v3.0.3)

### Nuevas Funcionalidades
- ✅ **Imágenes de fondo configurables por canal**
- ✅ **TabBar con pestañas "Chat" y "Medios"** (web y macOS)
- ✅ **Galería de medios separada** para imágenes y videos
- ✅ **Mejoras en la sincronización de usuarios** (case-insensitive)
- ✅ **Mejor manejo de conexiones SSL/TLS** en macOS
- ✅ **Permisos mejorados** para conexiones de red

### Correcciones
- ✅ Corrección de usuarios faltantes en listas de canales
- ✅ Mejora en la detección de usuarios duplicados
- ✅ Corrección de problemas de conexión a apolo.globalchat.org
- ✅ Mejora en el manejo de certificados SSL
- ✅ Corrección de problemas de CORS en web

### Optimizaciones
- ✅ Mejora en el rendimiento de la lista de usuarios
- ✅ Optimización de la carga de mensajes
- ✅ Mejora en el uso de memoria
- ✅ Optimización de la compilación para macOS

---

## 🛠️ Desarrollo

### Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada
├── models/                      # Modelos de datos
│   ├── irc_message.dart        # Mensajes y canales IRC
│   ├── app_theme.dart          # Temas visuales
│   ├── radio_station.dart      # Estaciones de radio
│   └── ...
├── services/                    # Servicios
│   ├── irc_service.dart        # Servicio IRC principal
│   ├── radio_service.dart       # Servicio de radio
│   ├── irc_socket_connection.dart  # Conexión TCP nativa
│   └── ...
├── providers/                   # Providers Riverpod
│   ├── irc_provider.dart        # Estado IRC
│   ├── theme_provider.dart      # Temas
│   ├── radio_provider.dart      # Radio
│   └── ...
├── screens/                     # Pantallas
│   ├── login_screen.dart        # Pantalla de login
│   ├── chat_screen.dart         # Pantalla principal
│   ├── settings_screen.dart     # Ajustes
│   └── ...
└── widgets/                     # Widgets reutilizables
    ├── radio_controls.dart      # Controles de radio
    ├── moderator_menu.dart      # Menú de moderador
    └── ...

macos/
├── Runner/                      # Configuración macOS
│   ├── AppDelegate.swift        # Delegado de la app
│   ├── MainFlutterWindow.swift  # Ventana principal
│   ├── DebugProfile.entitlements # Permisos (debug)
│   └── Release.entitlements     # Permisos (release)
└── ...
```

### Compilación para Desarrollo

```bash
# Modo debug
flutter run -d macos

# Modo release
flutter build macos --release
```

### Scripts Útiles

- `build_dmg.sh`: Crea el instalador DMG
- `backup_git.sh`: Crea backup local del repositorio

---

## 📋 Requisitos del Sistema

### macOS
- **Versión mínima**: macOS 10.14 (Mojave)
- **Recomendado**: macOS 11.0 (Big Sur) o superior
- **Arquitectura**: Apple Silicon (M1/M2/M3) o Intel (x86_64)
- **Memoria**: 4 GB RAM mínimo, 8 GB recomendado
- **Espacio en disco**: 100 MB para la aplicación

### Para Desarrollo
- **Xcode**: 12.0 o superior
- **Flutter**: 3.38.4 o superior
- **Dart**: 3.10.3 o superior
- **CocoaPods**: Instalado automáticamente

---

## 🐛 Troubleshooting

### Problemas de Conexión

**No se conecta al servidor:**
- Verifica tu conexión a Internet
- Comprueba que el servidor esté disponible
- Revisa los permisos de red en Preferencias del Sistema
- Intenta con otro servidor (apolo, ceres, caliope)

**Error de certificado SSL:**
- La aplicación acepta certificados autofirmados automáticamente
- Si persiste, verifica la fecha/hora del sistema

### Problemas de Usuarios

**Usuarios no aparecen en la lista:**
- Espera unos segundos después de unirte al canal
- La lista se actualiza automáticamente
- Intenta salir y volver a entrar al canal

**Usuarios duplicados:**
- Esto ha sido corregido en v3.0.3
- Si persiste, reinicia la aplicación

### Problemas de Radio

**La radio no se reproduce:**
- Verifica tu conexión a Internet
- Comprueba que el volumen no esté en 0
- Intenta con otra estación

### Problemas de Rendimiento

**La aplicación va lenta:**
- Cierra canales que no uses
- Limpia el cache desde Ajustes
- Reinicia la aplicación

---

## 📝 Notas de Versión

### v3.0.3 (Actual)
- Imágenes de fondo por canal
- TabBar con galería de medios
- Mejoras en sincronización de usuarios
- Correcciones de conexión SSL
- Optimizaciones de rendimiento

### v3.0.0
- Sistema de temas visuales
- Radio integrada
- Videoconferencias Jitsi
- Sistema de moderación
- Notificaciones mejoradas

### v2.1.0
- Soporte para múltiples canales
- Mensajes privados
- Lista de usuarios
- Búsqueda en mensajes

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📄 Licencia

Este proyecto está disponible bajo la licencia MIT.

---

## 👥 Créditos

Desarrollado con ❤️ usando Flutter para GlobalChat IRC Network.

**Red IRC**: [GlobalChat.org](https://globalchat.org)  
**Repositorio**: [GitHub](https://github.com/Globalchat-IRC/ircapp)

---

## 📞 Soporte

Para reportar bugs o solicitar features:
- **Issues**: [GitHub Issues](https://github.com/Globalchat-IRC/ircapp/issues)
- **IRC**: Conéctate a `#globalchat` en `irc.globalchat.org`

---

**¡Disfruta chateando en IRC! 🎉**
