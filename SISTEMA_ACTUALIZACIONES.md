# 🔄 Sistema de Auto-actualización - IRC App

## 📋 Descripción

Sistema completo de auto-actualización que verifica si hay nuevas versiones disponibles en GitHub Releases y permite descargarlas e instalarlas fácilmente.

---

## ✨ Características

✅ **Verificación automática** cada 24 horas  
✅ **Notificación visual** con banner atractivo  
✅ **Descarga directa** desde GitHub Releases  
✅ **Notas de la versión** integradas  
✅ **Verificación manual** desde configuración  
✅ **Compatible** con versioning semántico (1.0.0)  
✅ **Gratis** usando GitHub Releases  

---

## 🚀 Configuración paso a paso

### Paso 1: Añadir dependencias al `pubspec.yaml`

```yaml
dependencies:
  # ... tus otras dependencias ...
  
  # Para auto-actualización
  http: ^1.2.0
  package_info_plus: ^5.0.1
  path_provider: ^2.1.2
  url_launcher: ^6.2.4
```

Luego ejecuta:
```bash
flutter pub get
```

---

### Paso 2: Configurar GitHub Repository

#### 2.1 Actualizar información en `update_service.dart`

Abre `lib/services/update_service.dart` y modifica estas líneas:

```dart
// CONFIGURACIÓN ACTUAL:
static const String githubOwner = 'Globalchat-IRC';  // Organización de GitHub
static const String githubRepo = 'ircapp';           // Nombre del repositorio

// La URL completa será: https://github.com/Globalchat-IRC/ircapp
```

#### 2.2 Repositorio en GitHub

Tu repositorio ya está creado en:
**https://github.com/Globalchat-IRC/ircapp**

#### 2.3 Subir tu código (si aún no lo has hecho)

```bash
cd C:\src\irc_app

# Inicializar git si no está iniciado
git init

# Añadir remote
git remote add origin https://github.com/Globalchat-IRC/ircapp.git

# Añadir archivos
git add .
git commit -m "Añadido sistema de auto-actualización"

# Subir a GitHub
git push -u origin main
```

---

### Paso 3: Integrar en la aplicación

#### 3.1 Añadir el banner en tu pantalla principal

Abre el archivo de tu pantalla principal (ej: `lib/main.dart` o donde tengas el Scaffold principal) y añade:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/update_banner.dart';  // Importar banner

class MyHomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          // ⭐ Añadir banner de actualización aquí
          const UpdateBanner(),
          
          // ... resto de tu UI ...
          Expanded(
            child: YourContent(),
          ),
        ],
      ),
    );
  }
}
```

#### 3.2 Añadir botón en configuración (opcional)

En tu pantalla de configuración/ajustes:

```dart
import 'widgets/update_banner.dart';

// Dentro de tu ListView de configuración:
ListView(
  children: [
    // ... otras opciones ...
    
    const Divider(),
    const CheckUpdateButton(),  // ⭐ Botón para verificar actualizaciones
    
    // ... más opciones ...
  ],
)
```

---

### Paso 4: Actualizar versión en `pubspec.yaml`

Cada vez que hagas una nueva release, actualiza la versión:

```yaml
name: irc_app
description: Cliente IRC moderno
publish_to: 'none'

version: 1.0.1+2  # ⭐ Incrementa este número
#        ^   ^
#        |   |
#        |   +-- Build number (interno)
#        +------ Versión visible (1.0.1)
```

**Versionado semántico:**
- `1.0.0` → `1.0.1` - Bug fixes
- `1.0.0` → `1.1.0` - Nuevas funciones
- `1.0.0` → `2.0.0` - Cambios importantes

---

### Paso 5: Crear un Release en GitHub

#### 5.1 Compilar la nueva versión

```bash
cd C:\src\irc_app

# Actualizar versión en pubspec.yaml primero
# Luego compilar
flutter build windows --release

# Crear instalador con Inno Setup
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

#### 5.2 Crear Release en GitHub

1. **Ve a tu repositorio** en GitHub: https://github.com/Globalchat-IRC/ircapp
2. Haz clic en **"Releases"** (lado derecho)
3. Haz clic en **"Create a new release"** o ve directamente a: https://github.com/Globalchat-IRC/ircapp/releases/new

4. **Configurar el release:**
   ```
   Tag version: v1.0.1  ⭐ IMPORTANTE: Debe empezar con "v"
   Release title: IRC App v1.0.1
   
   Describe this release:
   ## Novedades de la versión 1.0.1
   
   ### ✨ Nuevas funciones
   - Sistema de auto-actualización implementado
   - Radio corregida para Windows
   - Mejoras en la interfaz
   
   ### 🐛 Correcciones
   - Arreglado problema con audio en Windows
   - Corregidos warnings en el instalador
   
   ### 📦 Instalación
   Descarga el archivo .exe y ejecuta el instalador
   ```

5. **Subir archivos:**
   - Arrastra el archivo del instalador: `irc_app_setup_1.0.1_x64.exe`
   - O haz clic en "Attach binaries..." y selecciona el archivo

6. **Publicar:**
   - Si es versión estable: marca **"Set as the latest release"**
   - Si es beta: marca **"Set as a pre-release"**
   - Haz clic en **"Publish release"**

---

## 🎯 Flujo de trabajo para nuevas versiones

```
1. Hacer cambios en el código
   ↓
2. Actualizar versión en pubspec.yaml (ej: 1.0.1 → 1.0.2)
   ↓
3. Commit y push a GitHub
   git add .
   git commit -m "Version 1.0.2: Descripción de cambios"
   git push
   ↓
4. Compilar aplicación
   flutter build windows --release
   ↓
5. Crear instalador
   ISCC.exe installer.iss
   ↓
6. Crear Release en GitHub
   - Tag: v1.0.2
   - Título: IRC App v1.0.2
   - Descripción: Notas de la versión
   - Adjuntar: irc_app_setup_1.0.2_x64.exe
   ↓
7. Publicar Release
   ↓
8. Los usuarios recibirán notificación automática en 24h
   (o al verificar manualmente)
```

---

## 🔧 Personalización

### Cambiar intervalo de verificación

En `lib/services/update_service.dart`:

```dart
// Verificar cada 24 horas (predeterminado)
static const Duration checkInterval = Duration(hours: 24);

// O cambiar a:
static const Duration checkInterval = Duration(hours: 12);  // Cada 12 horas
static const Duration checkInterval = Duration(days: 7);    // Cada semana
```

### Verificar al iniciar la app

En `lib/providers/update_provider.dart`:

```dart
UpdateNotifier() : super(const UpdateState()) {
  // Cambiar el delay inicial (predeterminado: 5 segundos)
  Future.delayed(const Duration(seconds: 5), () {
    checkForUpdates();
  });
}

// Cambiar a inmediato:
Future.delayed(const Duration(seconds: 0), () {
  checkForUpdates();
});
```

### Personalizar colores del banner

En `lib/widgets/update_banner.dart`:

```dart
gradient: LinearGradient(
  colors: [
    Colors.blue.shade600,    // Cambiar estos colores
    Colors.blue.shade700,
  ],
),
```

---

## 🧪 Cómo probar el sistema

### Prueba 1: Simular nueva versión

1. **Cambia temporalmente la versión actual** en `pubspec.yaml`:
   ```yaml
   version: 0.1.0+1  # Versión antigua
   ```

2. **Crea un release** en GitHub con versión `v1.0.0`

3. **Ejecuta la app** y espera 5 segundos

4. **Deberías ver** el banner de actualización

### Prueba 2: Verificación manual

1. En la app, ve a **Configuración**
2. Busca **"Buscar actualizaciones"**
3. Haz clic
4. Si hay versión nueva, aparecerá

### Prueba 3: Forzar verificación desde código

Añade un botón de debug:

```dart
ElevatedButton(
  onPressed: () {
    ref.read(updateProvider.notifier).checkForUpdates(forceCheck: true);
  },
  child: Text('🔍 Verificar Actualización (Debug)'),
)
```

---

## ❓ Preguntas frecuentes

### ¿Funciona sin internet?

**No**, el sistema necesita conexión a internet para:
- Verificar si hay actualizaciones en GitHub
- Descargar el instalador

Si no hay internet, simplemente no verifica (sin errores).

### ¿Qué pasa si GitHub está caído?

El sistema maneja el error silenciosamente y volverá a intentar en el próximo intervalo (24h).

### ¿Puedo usar mi propio servidor en lugar de GitHub?

**Sí**, pero tendrás que modificar `update_service.dart` para que consulte tu API. GitHub es gratis y confiable, así que es la opción recomendada.

### ¿Cómo desactivo las actualizaciones automáticas?

En `lib/providers/update_provider.dart`, comenta o elimina:

```dart
UpdateNotifier() : super(const UpdateState()) {
  // Comentar estas líneas para desactivar verificación automática
  // Future.delayed(const Duration(seconds: 5), () {
  //   checkForUpdates();
  // });
}
```

Los usuarios aún podrán verificar manualmente desde configuración.

### ¿Funciona en todas las plataformas?

Actualmente está optimizado para **Windows**. Para macOS/Linux necesitarías:
- Adaptar el método de instalación
- Usar diferentes formatos (DMG para macOS, AppImage/DEB para Linux)

---

## 🔐 Seguridad

### Verificación de checksums (opcional avanzado)

Para mayor seguridad, puedes añadir verificación SHA256:

1. Genera checksum del instalador:
   ```bash
   certutil -hashfile irc_app_setup_1.0.0_x64.exe SHA256
   ```

2. Añádelo en las notas del release:
   ```
   SHA256: abc123...
   ```

3. Modifica `update_service.dart` para verificar antes de instalar

---

## 📊 Estadísticas de descargas

GitHub Releases te proporciona:
- ✅ Número de descargas por versión
- ✅ Fecha de cada descarga
- ✅ Assets más populares

Ve a: `https://github.com/tu-usuario/irc_app/releases`

---

## 🎉 ¡Listo!

Ya tienes un sistema completo de auto-actualización. Tus usuarios recibirán notificaciones automáticas cuando publiques nuevas versiones.

**Próxima vez que actualices:**
1. Incrementa versión en `pubspec.yaml`
2. Compila e instala
3. Crea Release en GitHub
4. ¡Los usuarios se enterarán automáticamente!

---

**Creado por**: Fran Naveira  
**Última actualización**: Diciembre 2025

