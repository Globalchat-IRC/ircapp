# 🧙‍♂️ Installer Wizard - Guía de Uso

## ¿Qué es el Installer Wizard?

Es un asistente interactivo que te guía paso a paso para crear un instalador profesional de Windows para IRC App. No necesitas conocimientos técnicos, solo seguir el menú.

## 📋 Requisitos previos

Antes de usar el wizard, asegúrate de tener instalado:

1. **Flutter SDK** - https://docs.flutter.dev/get-started/install/windows
2. **Visual Studio 2022** con "Desarrollo para escritorio con C++"
3. **Inno Setup 6** - https://jrsoftware.org/isdl.php
4. **Git** (opcional) - https://git-scm.com/downloads

## 🚀 Inicio rápido

### Opción 1: Usar el Wizard de Batch (.bat)

1. Abre el **Explorador de archivos**
2. Ve a la carpeta del proyecto `irc_app`
3. Haz doble clic en **`installer_wizard.bat`**
4. Sigue las instrucciones en pantalla

### Opción 2: Usar el Wizard de PowerShell (.ps1) [Recomendado]

1. **Habilitar ejecución de scripts** (solo la primera vez):
   - Abre PowerShell como **Administrador**
   - Ejecuta: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
   - Escribe `S` para confirmar

2. **Ejecutar el wizard**:
   - Haz clic derecho en **`installer_wizard.ps1`**
   - Selecciona **"Ejecutar con PowerShell"**
   - O abre PowerShell normal y ejecuta: `.\installer_wizard.ps1`

## 🎯 Menú del Wizard

```
========================================
   IRC APP - INSTALLER WIZARD
========================================

  [1] 🔧 Configurar información del instalador
  [2] 📦 Compilar aplicación Flutter
  [3] 🎁 Crear instalador con Inno Setup
  [4] ⚡ Hacer todo (compilar + crear instalador)
  [5] ✅ Verificar requisitos del sistema
  [6] 📂 Abrir carpeta de instaladores
  [7] 🚪 Salir
```

## 📖 Guía paso a paso

### Primera vez: Proceso completo

#### Paso 1: Verificar requisitos (Opción 5)

1. Selecciona la **opción 5**
2. El wizard verificará:
   - ✅ Flutter instalado
   - ✅ Git instalado
   - ✅ Inno Setup instalado
   - ✅ Archivos del proyecto
   - ✅ Espacio en disco

3. Si falta algo, instálalo antes de continuar

#### Paso 2: Configurar instalador (Opción 1)

1. Selecciona la **opción 1**
2. El wizard te preguntará:
   - **Nombre de la aplicación**: Por defecto "IRC App"
   - **Versión**: Ejemplo "1.0.0"
   - **Tu nombre o empresa**: Aparecerá en el instalador
   - **URL del proyecto**: Opcional
   - **Icono en escritorio**: S/N (por defecto Sí)
   - **Requiere admin**: S/N (por defecto No)

3. El wizard:
   - Generará un GUID único automáticamente
   - Guardará la configuración en `installer_config.json`
   - Creará/actualizará el archivo `installer.iss`

#### Paso 3: Hacer todo (Opción 4) [RECOMENDADO]

1. Selecciona la **opción 4**
2. El wizard automáticamente:
   - Limpiará builds anteriores
   - Obtendrá dependencias
   - Compilará la aplicación (tarda varios minutos)
   - Creará el instalador con Inno Setup

3. Al finalizar:
   - Te preguntará si quieres abrir la carpeta
   - Encontrarás el instalador en `installers/`

### Siguientes veces: Proceso rápido

Si ya configuraste el instalador:

1. **Opción 4**: "Hacer todo"
2. Espera a que compile y cree el instalador
3. ¡Listo!

## 📁 Archivos generados

Después de usar el wizard:

```
irc_app/
├── installer_config.json       # Configuración guardada (editable)
├── installer.iss               # Script de Inno Setup (generado)
├── installers/                 # Carpeta de salida
│   └── irc_app_setup_1.0.0_x64.exe  # ¡Tu instalador!
└── build/
    └── windows/
        └── x64/
            └── runner/
                └── Release/    # Archivos compilados
```

## 🎨 Personalización avanzada

### Editar configuración manualmente

Puedes editar `installer_config.json`:

```json
{
  "AppName": "Mi IRC App",
  "AppVersion": "2.0.0",
  "Publisher": "Mi Empresa",
  "AppURL": "https://mi-sitio.com",
  "CreateDesktop": true,
  "RequireAdmin": false,
  "AppGuid": "{12345678-1234-1234-1234-123456789ABC}"
}
```

Después ejecuta **Opción 1** para aplicar cambios.

### Agregar imágenes personalizadas al instalador

1. Crea una carpeta `installer_assets/`
2. Añade estas imágenes:
   - `installer_image.bmp` (164 x 314 píxeles)
   - `installer_small_image.bmp` (55 x 58 píxeles)

3. Edita `installer.iss` y descomenta estas líneas:
   ```iss
   WizardImageFile=installer_assets\installer_image.bmp
   WizardSmallImageFile=installer_assets\installer_small_image.bmp
   ```

## ❓ Solución de problemas

### Error: "Flutter no encontrado"

**Solución**:
1. Asegúrate de haber instalado Flutter
2. Añade Flutter al PATH del sistema:
   - Busca "Variables de entorno" en Windows
   - Edita la variable `Path`
   - Añade: `C:\ruta\a\flutter\bin`
3. Reinicia la terminal/cmd

### Error: "Inno Setup no encontrado"

**Solución**:
1. Descarga Inno Setup desde: https://jrsoftware.org/isdl.php
2. Instálalo en la ruta por defecto: `C:\Program Files (x86)\Inno Setup 6\`
3. Reinicia el wizard

### Error: "No se puede ejecutar scripts de PowerShell"

**Solución**:
1. Abre PowerShell como Administrador
2. Ejecuta: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. Confirma con `S`

### Error: "pubspec.yaml no encontrado"

**Solución**:
- Asegúrate de estar en la carpeta correcta del proyecto
- El wizard debe ejecutarse desde la carpeta raíz de `irc_app`

### Error al compilar: "error de TLS"

**Solución**:
Ver el archivo `COMPILAR_WINDOWS.md` para soluciones detalladas.

## 🎯 Casos de uso

### Caso 1: Primera versión (1.0.0)

```
1. Opción 5: Verificar requisitos
2. Opción 1: Configurar (versión 1.0.0)
3. Opción 4: Hacer todo
4. Distribuir instalador
```

### Caso 2: Actualización (1.0.1)

```
1. Editar installer_config.json → Cambiar versión a "1.0.1"
2. Opción 1: Aplicar configuración
3. Opción 4: Hacer todo
4. Distribuir nueva versión
```

### Caso 3: Solo recompilar (sin cambios)

```
1. Opción 2: Compilar aplicación
2. Opción 3: Crear instalador
```

### Caso 4: Probar compilación (sin instalador)

```
1. Opción 2: Compilar aplicación
2. Ejecutar: build\windows\x64\runner\Release\irc_app.exe
```

## 🚀 Distribución

Una vez creado el instalador:

### Opción 1: Enviar por email/USB
- Comprime el `.exe` en un `.zip` (opcional)
- Envía o copia el archivo

### Opción 2: GitHub Releases
1. Ve a tu repositorio en GitHub
2. Releases → "Create a new release"
3. Sube el instalador
4. Publica

### Opción 3: Subir a tu sitio web
- Sube el `.exe` a tu servidor
- Crea un link de descarga

## 📊 Checklist de calidad

Antes de distribuir, verifica:

- [ ] El instalador se ejecuta sin errores
- [ ] La aplicación se instala correctamente
- [ ] Los iconos aparecen en el menú inicio
- [ ] El icono de escritorio funciona (si está habilitado)
- [ ] La aplicación se ejecuta después de instalar
- [ ] La desinstalación funciona correctamente
- [ ] No hay DLLs faltantes
- [ ] Probado en Windows 10 y Windows 11
- [ ] Probado en máquina limpia (sin Flutter instalado)

## 🎓 Consejos

### ✅ Mejores prácticas

1. **Usa versionado semántico**: 1.0.0, 1.0.1, 1.1.0, 2.0.0
2. **Prueba en máquina limpia**: Usa una VM o PC sin Flutter
3. **Mantén backups**: Guarda cada versión del instalador
4. **Documenta cambios**: Crea un CHANGELOG.md
5. **Firma el instalador**: Si es posible (requiere certificado)

### ⚠️ Evitar

1. **No cambies el GUID**: Se usa para actualizaciones
2. **No omitas pruebas**: Siempre prueba antes de distribuir
3. **No uses espacios en rutas**: Puede causar problemas
4. **No olvides actualizar la versión**: Cada release debe tener versión única

## 🔄 Actualizaciones

### Actualizar versión menor (1.0.0 → 1.0.1)

1. Edita `installer_config.json`
2. Cambia `"AppVersion": "1.0.1"`
3. Ejecuta **Opción 4**
4. Distribuye

### Actualizar versión mayor (1.0.0 → 2.0.0)

1. Edita `installer_config.json`
2. Cambia `"AppVersion": "2.0.0"`
3. Ejecuta **Opción 4**
4. Actualiza README y CHANGELOG
5. Distribuye

## 📞 Soporte

Si tienes problemas:

1. Ejecuta **Opción 5** para verificar requisitos
2. Revisa los errores en la consola
3. Consulta `INSTALADOR_INNOSETUP.md` para detalles técnicos
4. Consulta `COMPILAR_WINDOWS.md` para problemas de compilación

## 📚 Documentación adicional

- **INSTALADOR_INNOSETUP.md**: Guía completa de Inno Setup
- **COMPILAR_WINDOWS.md**: Instrucciones de compilación para Windows
- **COMPILAR_FEDORA.md**: Instrucciones para Linux/Fedora

## 🎉 ¡Éxito!

Si llegaste hasta aquí y todo funcionó:

**¡Felicidades! 🎊** Ya tienes un instalador profesional de Windows para tu aplicación IRC.

---

**Creado por**: Fran Naveira  
**Última actualización**: Diciembre 2025

