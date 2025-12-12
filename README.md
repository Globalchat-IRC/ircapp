# IRC Client Flutter

Un cliente IRC moderno y multiplataforma construido con **Flutter**, diseñado para conectarse a servidores IRC como **ceres.globalchat.org**.

## Características

- ✅ Conexión a servidores IRC estándar (RFC 2812)
- ✅ Soporte para múltiples canales simultáneamente
- ✅ Lista de usuarios en tiempo real
- ✅ Interfaz moderna y responsiva
- ✅ Compatible con iOS y Android
- ✅ Gestión de estado con Riverpod
- ✅ Arquitectura limpia y escalable

## Requisitos

- Flutter 3.38.4 o superior
- Dart 3.10.3 o superior
- Xcode (para iOS)
- Android Studio (para Android)

## Instalación

### 1. Clonar o descargar el proyecto

```bash
cd /Users/fnaveira/mobile/irc_app
```

### 2. Obtener dependencias

```bash
flutter pub get
```

### 3. Ejecutar el proyecto

#### iOS
```bash
flutter run -d iphone
```

#### Android
```bash
flutter run -d android
```

#### En simulador iOS
```bash
open -a Simulator
flutter run
```

## Uso

### Conectarse al servidor

1. Ingresa los parámetros de conexión:
   - **Host**: `ceres.globalchat.org` (por defecto)
   - **Puerto**: `6667` (por defecto)
   - **Nickname**: Tu nombre de usuario en IRC

2. Presiona "Connect"

### Usar el cliente

- **Canales**: En la barra lateral izquierda puedes ver los canales unidos
- **Usuarios**: En la barra lateral derecha se muestran los usuarios del canal actual
- **Mensaje**: Escribe tu mensaje en el campo inferior y presiona Enter o el botón de envío
- **Unirse a canal**: Presiona el botón "Join" para unirte a un nuevo canal
- **Salir**: Presiona el botón de logout (rojo) para desconectarte

## Estructura del Proyecto

```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── models/
│   └── irc_message.dart     # Modelos de datos (Message, Channel)
├── services/
│   └── irc_service.dart     # Servicio IRC (conexión, comandos)
├── providers/
│   └── irc_provider.dart    # Proveedores Riverpod (estado global)
└── screens/
    ├── login_screen.dart    # Pantalla de conexión
    └── chat_screen.dart     # Pantalla principal de chat
```

## Comando IRC Soportados

- **NICK**: Cambiar nickname
- **USER**: Registrar usuario
- **JOIN**: Unirse a un canal
- **PART**: Salir de un canal
- **PRIVMSG**: Enviar mensaje
- **QUIT**: Desconectarse

## Configuración de la Aplicación

### Android

Para permitir conexiones HTTP inseguras, edita `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

Para permitir conexiones no seguras, edita `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Esta aplicación necesita acceso a la red local</string>
<key>NSBonjourServices</key>
<array>
  <string>_http._tcp</string>
</array>
```

## Dependencias Principales

- **flutter_riverpod**: ^2.6.0 - Gestión de estado
- **intl**: ^0.19.0 - Internacionalización y formato de fechas

## Próximas Mejoras

- [ ] Soporte para SSL/TLS
- [ ] Persistencia de mensajes
- [ ] Notificaciones push
- [ ] Búsqueda en histórico
- [ ] Temas personalizables
- [ ] Autenticación SASL

## Licencia

Este proyecto está disponible bajo la licencia MIT.

## Autor

Desarrollado con Flutter ❤️
samples, guidance on mobile development, and a full API reference.
