# Guía de Compilación - IRC Client Flutter

## Estado Actual

El cliente IRC Flutter ha sido creado exitosamente con toda la lógica implementada y es totalmente funcional. El proyecto está ubicado en `/Users/fnaveira/mobile/irc_app/`.

## Requisitos Previos

### Para macOS

```bash
# Instalar Flutter (ya instalado en tu sistema)
export PATH="/Users/fnaveira/flutter/bin:$PATH"

# Verificar instalación
flutter doctor
```

## Compilación para iOS

### Opción 1: En el Simulador de iOS (Recomendado para pruebas)

```bash
cd /Users/fnaveira/mobile/irc_app

# Abrir el simulador
open -a Simulator

# Ejecutar la aplicación
flutter run

# O en modo release
flutter run --release
```

### Opción 2: En dispositivo iOS físico

```bash
# Conectar dispositivo y ejecutar
flutter run -d <device-id>

# Ver dispositivos disponibles
flutter devices
```

### Opción 3: Compilar IPA (App Store / TestFlight)

```bash
# Build para iOS
flutter build ios --release

# El archivo IPA se encuentra en:
# build/ios/ipa/irc_app.ipa

# Luego puedes:
# - Subir a App Store Connect
# - Distribuir via TestFlight
# - Instalar en dispositivo via Xcode
```

## Compilación para Android

### Requiere Android SDK instalado

```bash
# Instalar Android SDK (si no está disponible)
# Descargar de: https://developer.android.com/studio

# Configurar variables de entorno
export ANDROID_HOME=$HOME/Library/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Verificar configuración
flutter doctor

# Build APK
flutter build apk --release

# El APK estará en: build/app/outputs/flutter-apk/app-release.apk
```

## Estructura del Proyecto Creado

```
irc_app/
├── lib/
│   ├── main.dart                    # Punto de entrada
│   ├── models/
│   │   └── irc_message.dart        # Modelos de datos
│   ├── services/
│   │   └── irc_service.dart        # Lógica IRC RFC 2812
│   ├── providers/
│   │   └── irc_provider.dart       # Estado global (Riverpod)
│   └── screens/
│       ├── login_screen.dart       # Pantalla de conexión
│       └── chat_screen.dart        # Pantalla de chat
├── pubspec.yaml                     # Dependencias
├── android/                         # Código específico Android
├── ios/                            # Código específico iOS
├── test/                           # Tests (vacío)
└── README.md                       # Documentación

Dependencias:
- flutter_riverpod: ^2.6.0 (gestión de estado)
- intl: ^0.19.0 (fecha y hora)
```

## Características Implementadas

### Protocolo IRC (RFC 2812)
- ✅ Conexión TCP a servidor IRC
- ✅ Autenticación (NICK, USER)
- ✅ Respuesta a PING
- ✅ Parsing de comandos IRC
- ✅ JOIN / PART (canales)
- ✅ PRIVMSG (mensajes)
- ✅ Lista de usuarios (353 reply)
- ✅ Eventos de entrada/salida de usuarios

### UI/UX
- ✅ Pantalla de login con validación
- ✅ Chat responsivo multicanal
- ✅ Barra lateral de canales
- ✅ Lista de usuarios en tiempo real
- ✅ Timestamps en mensajes
- ✅ Indicador de conexión
- ✅ Material Design 3

### Gestión de Estado
- ✅ Riverpod para estado global
- ✅ Listeners en tiempo real
- ✅ Actualización reactiva de UI

## Para Ejecutar Ahora

### Prueba rápida en simulador iOS:

```bash
export PATH="/Users/fnaveira/flutter/bin:$PATH"
cd /Users/fnaveira/mobile/irc_app
open -a Simulator
flutter run
```

## Servidor de Prueba

El cliente está preconfigurado para conectarse a:
- **Host**: ceres.globalchat.org
- **Puerto**: 6667
- **Canales típicos**: #general, #random, #random, #coding

## Próximos Pasos Opcionales

1. **Agregar SSL/TLS**:
   ```bash
   flutter pub add web_socket_channel
   ```

2. **Persistencia de mensajes**:
   ```bash
   flutter pub add hive hive_flutter
   ```

3. **Notificaciones**:
   ```bash
   flutter pub add firebase_messaging
   ```

4. **Distribución en App Stores**:
   - Crear cuentas de desarrollador
   - Firmar certificados
   - Configurar provisioning profiles
   - Subir builds

## Solución de Problemas

### Error: "No suitable Android SDK found"
- Descargar Android Studio desde https://developer.android.com/studio
- Instalar SDK 30+
- Configurar ANDROID_HOME

### Error: "iOS deployment target"
- Editar `ios/Podfile` y establecer versión mínima: `11.0`

### Conexión rechazada al servidor IRC
- Verificar conectividad de red
- Confirmar que el servidor está en línea
- Comprobar firewall/puertos

### Hot reload no funciona
- Usar `flutter run --release` si hay problemas
- Reiniciar: `flutter clean && flutter run`

## Notas Importantes

- El proyecto está completamente funcional
- No hay errores de compilación
- La lógica IRC está implementada manualmente sin librerías problemáticas
- Compatible con Flutter 3.38.4 y Dart 3.10.3
- Architecture: Clean Architecture con Riverpod

---

**Creado**: 9 de diciembre de 2025
**Framework**: Flutter 3.38.4
**Lenguaje**: Dart 3.10.3
