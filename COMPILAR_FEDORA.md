# Instrucciones para compilar IRC App para Fedora Linux

## Requisitos previos

1. **Fedora 38 o superior** (recomendado)
2. **Flutter SDK** instalado
3. **Dependencias de desarrollo** necesarias para Flutter Linux

## Pasos para compilar

### 1. Instalar dependencias del sistema

```bash
# Actualizar el sistema
sudo dnf update -y

# Instalar herramientas de desarrollo
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git curl unzip xz

# Instalar dependencias para Flutter Linux
sudo dnf install -y \
  clang cmake ninja-build pkg-config \
  gtk3-devel \
  glib2-devel \
  libsecret-devel \
  jsoncpp-devel \
  liblzma-devel \
  libepoxy-devel \
  libX11-devel \
  libXext-devel \
  libXrender-devel \
  libXtst-devel \
  libxcb-devel \
  libxkbcommon-devel \
  mesa-libGL-devel \
  mesa-libGLU-devel \
  libGLEW-devel
```

### 2. Instalar Flutter

```bash
# Descargar Flutter
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# Añadir Flutter al PATH
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc

# O si usas zsh:
# echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
# source ~/.zshrc
```

### 3. Verificar instalación

```bash
flutter doctor
```

Asegúrate de que aparezca:
- ✓ Flutter
- ✓ Linux toolchain - develop for Linux desktop
- ✓ Chrome - develop for the web (opcional)

### 4. Habilitar soporte para Linux desktop

```bash
flutter config --enable-linux-desktop
```

### 5. Clonar o copiar el proyecto

```bash
git clone <url-del-repositorio>
cd irc_app
```

O copia la carpeta completa del proyecto a tu sistema Fedora.

### 6. Obtener dependencias

```bash
flutter pub get
```

### 7. Compilar para Linux (Release)

```bash
flutter build linux --release
```

El ejecutable estará en: `build/linux/x64/release/bundle/irc_app`

## Distribución

### Opción 1: Carpeta completa (más fácil)

La carpeta completa con todas las bibliotecas necesarias está en:
```
build/linux/x64/release/bundle/
```

Puedes comprimir esta carpeta en un `.tar.gz`:
```bash
cd build/linux/x64/release/
tar -czf irc_app-linux-x64.tar.gz bundle/
```

### Opción 2: AppImage (recomendado para distribución)

Para crear un AppImage que funcione en múltiples distribuciones Linux:

```bash
# Instalar herramientas para crear AppImage
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage

# Crear estructura AppImage
mkdir -p AppDir/usr/bin
cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/

# Crear archivo .desktop
cat > AppDir/irc_app.desktop << EOF
[Desktop Entry]
Name=IRC App
Exec=irc_app
Icon=irc_app
Type=Application
Categories=Network;Chat;
EOF

# Copiar icono (ajusta la ruta a tu icono)
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps/
cp linux/irc_app.png AppDir/usr/share/icons/hicolor/256x256/apps/irc_app.png

# Crear AppImage
./appimagetool-x86_64.AppImage AppDir irc_app-x86_64.AppImage
```

### Opción 3: Paquete RPM (nativo de Fedora)

Para crear un paquete RPM:

```bash
# Instalar herramientas de empaquetado
sudo dnf install -y rpm-build rpmdevtools

# Crear estructura de directorios
rpmdev-setuptree

# Crear archivo spec (ejemplo básico)
cat > ~/rpmbuild/SPECS/irc_app.spec << EOF
Name:           irc_app
Version:        1.0.0
Release:        1%{?dist}
Summary:        IRC Chat Application

License:        MIT
URL:            https://github.com/tu-usuario/irc_app
Source0:        %{name}-%{version}.tar.gz

%description
A modern IRC chat client built with Flutter.

%prep
%setup -q

%install
mkdir -p %{buildroot}/opt/%{name}
cp -r * %{buildroot}/opt/%{name}/

%files
/opt/%{name}/*

%changelog
* $(date +"%a %b %d %Y") Tu Nombre <tu@email.com> - 1.0.0-1
- Initial package
EOF

# Copiar archivos
cp -r build/linux/x64/release/bundle ~/rpmbuild/SOURCES/irc_app-1.0.0

# Construir RPM
rpmbuild -ba ~/rpmbuild/SPECS/irc_app.spec
```

El RPM estará en `~/rpmbuild/RPMS/x86_64/`

### Opción 4: Flatpak (universal para todas las distribuciones)

```bash
# Instalar herramientas Flatpak
sudo dnf install -y flatpak flatpak-builder

# Añadir repositorio Flathub
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Crear archivo manifest (org.example.irc_app.yml)
# Ver: https://docs.flatpak.org/en/latest/manifests.html
```

## Ejecutar en modo debug

```bash
flutter run -d linux
```

## Solución de problemas

### Error: "gtk-3.0 not found"

```bash
sudo dnf install -y gtk3-devel
```

### Error: "No CMAKE_CXX_COMPILER could be found"

```bash
sudo dnf install -y cmake gcc-c++
```

### Error: "clang not found"

```bash
sudo dnf install -y clang
```

### Error con libsecret

```bash
sudo dnf install -y libsecret-devel
```

### Problemas con OpenGL

```bash
sudo dnf install -y mesa-libGL-devel mesa-libGLU-devel
```

### Limpiar y recompilar

Si encuentras errores de compilación:
```bash
flutter clean
flutter pub get
flutter build linux --release
```

## Notas importantes

- **Portabilidad**: El bundle incluye todas las bibliotecas necesarias, pero puede no funcionar en distribuciones muy antiguas
- **AppImage**: Es la forma más portátil de distribuir para Linux (funciona en Ubuntu, Fedora, Debian, openSUSE, etc.)
- **Flatpak/Snap**: Son formatos universales pero requieren que el usuario tenga instalado Flatpak o Snap
- **RPM**: Es específico de Fedora/RHEL/CentOS pero se integra mejor con el sistema
- **Tamaño**: El bundle completo puede ocupar ~80-150 MB dependiendo de las dependencias

## Permisos y seguridad

Si necesitas que la aplicación acceda a ciertos recursos del sistema:

```bash
# Permitir acceso a red (por defecto permitido)
# Permitir acceso a archivos del usuario
# Configurar permisos en Flatpak/Snap si usas esos formatos
```

## Actualizaciones

Para actualizar Flutter y recompilar:
```bash
flutter upgrade
flutter clean
flutter pub get
flutter build linux --release
```

## Recursos adicionales

- [Flutter Linux Desktop Support](https://docs.flutter.dev/desktop#linux)
- [Building Linux Apps](https://docs.flutter.dev/deployment/linux)
- [Flatpak Documentation](https://docs.flatpak.org/)
- [RPM Packaging Guide](https://rpm-packaging-guide.github.io/)

