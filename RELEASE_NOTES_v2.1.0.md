# 🎉 IRC App v2.1.0 - Release Notes

## 🚀 Nueva Versión - Funcionalidades Avanzadas

Esta versión incluye mejoras significativas en privacidad, organización, y experiencia de usuario.

---

## ✨ Nuevas Características

### 👥 Lista de Contactos/Favoritos
- **Sistema de contactos completo**: Guarda información de usuarios con los que chateas
- **Favoritos**: Marca usuarios como favoritos para acceso rápido
- **Agrupación**: Organiza contactos en grupos personalizados
- **Tags**: Etiqueta contactos para mejor organización
- **Notas**: Agrega notas personales sobre cada contacto
- **Estadísticas**: Ve cuántos mensajes has intercambiado con cada contacto

### 🏷️ Sistema de Tags/Etiquetas
- **Etiquetar mensajes**: Marca mensajes importantes con etiquetas personalizadas
- **Colores personalizados**: Cada etiqueta tiene su propio color
- **Búsqueda por etiquetas**: Filtra mensajes por etiquetas
- **Contador de uso**: Ve cuántas veces has usado cada etiqueta
- **Gestión completa**: Crea, edita y elimina etiquetas fácilmente

### 🔐 Cifrado de Mensajes
- **Cifrado punto a punto**: Cifra mensajes privados entre usuarios
- **Intercambio de claves**: Sistema seguro de intercambio de claves públicas
- **Verificación de identidad**: Verifica que estás hablando con la persona correcta
- **Cifrado automático**: Los mensajes cifrados se detectan y procesan automáticamente

### 🕵️ Modo Privado/Incógnito
- **Sin historial**: No guarda mensajes cuando está activo
- **Navegación privada**: Ocultar estado de presencia
- **Sin rastros**: No deja huellas de tu actividad
- **Activación rápida**: Activa/desactiva desde ajustes

### 🔒 Control de Privacidad Avanzado
- **Bloquear usuarios**: Bloquea usuarios molestos completamente
- **Lista de permitidos**: Controla quién puede ver tu estado
- **Ocultar presencia**: Oculta tu estado de presencia
- **Ocultar typing**: No mostrar cuando estás escribiendo
- **Control de WHOIS**: Decide quién puede ver tu información

### 📸 Preview de Medios
- **Imágenes en línea**: Preview automático de imágenes compartidas
- **Videos en línea**: Preview de videos con controles de reproducción
- **Vista completa**: Toca para ver en pantalla completa
- **Zoom y pan**: Navega imágenes con gestos
- **Soporte múltiples formatos**: JPG, PNG, GIF, WebP, MP4, WebM, MOV, AVI

### 📝 Markdown Avanzado
- **Soporte completo de Markdown**: Formatea tus mensajes con Markdown
- **Syntax highlighting**: Código con resaltado de sintaxis
- **Temas**: Soporte para temas claro y oscuro
- **Elementos soportados**:
  - Encabezados (# ## ###)
  - Negrita (**texto**)
  - Cursiva (*texto*)
  - Código inline (`código`)
  - Bloques de código (```código```)
  - Listas
  - Enlaces
  - Citas

### 💾 Sistema de Backup y Sincronización
- **Backup completo**: Guarda toda tu configuración y datos
- **Restauración fácil**: Restaura desde backup con un clic
- **Exportar configuración**: Exporta solo configuración (sin datos sensibles)
- **Formato JSON**: Backups en formato JSON legible
- **Metadata incluida**: Versión, fecha, plataforma en cada backup

### ⚡ Cache y Optimización
- **Cache inteligente**: Cache automático de imágenes y avatares
- **Limpieza automática**: Limpia cache antiguo automáticamente
- **Límites configurables**: Configura el tamaño máximo del cache
- **Gestión manual**: Limpia cache manualmente cuando lo necesites
- **Optimización de rendimiento**: Mejor rendimiento con muchos mensajes

### 📋 Virtualización de Listas
- **Mejor rendimiento**: Listas virtualizadas para mejor rendimiento
- **Lazy loading**: Carga mensajes bajo demanda
- **Scroll suave**: Scroll más suave con muchas mensajes
- **Optimización de memoria**: Uso eficiente de memoria

---

## 🛠️ Mejoras Técnicas

### 🔧 Servicios Nuevos
- **ContactsProvider**: Gestión de contactos y favoritos
- **TagsProvider**: Sistema de etiquetas para mensajes
- **EncryptionService**: Cifrado de mensajes punto a punto
- **PrivacyService**: Gestión completa de privacidad
- **CacheService**: Sistema de cache y optimización
- **BackupService**: Backup y restauración de datos

### 📦 Modelos Nuevos
- **Contact**: Modelo para contactos/favoritos
- **MessageTag**: Modelo para etiquetas de mensajes

### 🎨 Widgets Nuevos
- **ContactsList**: Lista de contactos con agrupación
- **MediaPreview**: Preview de imágenes y videos
- **MarkdownMessage**: Renderizado de Markdown avanzado
- **PrivacySettingsScreen**: Pantalla de configuración de privacidad

### 🐛 Correcciones
- Filtrado automático de mensajes de usuarios bloqueados
- Mejor detección de URLs de medios
- Soporte mejorado para Markdown en mensajes
- Optimización de rendimiento con muchos mensajes

---

## 📋 Cambios Técnicos Detallados

### Integración de Servicios
- Todos los servicios se inicializan automáticamente al iniciar la app
- Filtrado de mensajes bloqueados en tiempo real
- Cache automático de avatares e imágenes

### Privacidad
- Mensajes de usuarios bloqueados no se muestran
- Estado de presencia configurable
- Control granular de quién puede ver tu información

### Rendimiento
- Virtualización de listas para mejor rendimiento
- Cache inteligente reduce uso de red
- Lazy loading de mensajes antiguos

---

## 🔄 Migración desde v2.0.0

No se requieren pasos especiales de migración. La aplicación actualizará automáticamente:
- Configuraciones existentes se mantienen
- Historial de mensajes se preserva
- Preferencias de usuario intactas
- Nuevos servicios se inicializan automáticamente

---

## 📥 Instalación

1. Descarga el archivo `irc_app_macos_v2.1.0.dmg`
2. Abre el DMG
3. Arrastra `irc_app.app` a la carpeta `Applications`
4. Ejecuta la aplicación desde `Applications`

**Nota**: Si tienes una versión anterior instalada, puedes reemplazarla directamente.

---

## 🐛 Problemas Conocidos

- El cifrado de mensajes requiere que ambos usuarios tengan la app v2.1.0+
- Las etiquetas de mensajes se guardan localmente (no se sincronizan entre dispositivos)
- El modo incógnito desactiva automáticamente el guardado de historial

---

## 🙏 Agradecimientos

Gracias a todos los usuarios que han reportado bugs y sugerido mejoras. Esta versión incluye muchas de sus peticiones.

**Contribuidores especiales en esta versión:**
- weed
- nocturne
- sonic

De la red GlobalChat por sus contribuciones y feedback continuo.

---

## 📝 Notas de Desarrollo

Esta versión marca un hito importante en la evolución de la aplicación, con un enfoque especial en privacidad, organización y experiencia de usuario. Las mejoras de privacidad y organización hacen que la aplicación sea más útil y segura para usuarios que necesitan control sobre su información.

---

**Versión**: 2.1.0  
**Fecha de Release**: Enero 2025  
**Plataforma**: macOS  
**Tamaño**: ~55 MB


