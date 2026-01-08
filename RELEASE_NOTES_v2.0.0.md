podem# 🎉 IRC App v2.0.0 - Release Notes

## 🚀 Nueva Versión Mayor - macOS Optimizado

Esta es una versión mayor que incluye mejoras significativas específicas para macOS, mejorando la experiencia de usuario y la integración con el sistema operativo.

---

## ✨ Nuevas Características

### ⌨️ Atajos de Teclado macOS
- **⌘F**: Buscar en mensajes
- **⌘G**: Buscar siguiente resultado
- **⌘K**: Abrir diálogo para unirse a nuevo canal/privado
- **⌘W**: Cerrar pestaña/canal actual
- **⌘,**: Abrir Preferencias
- **⌘E**: Exportar conversación actual

### 🔍 Búsqueda Avanzada
- Diálogo de búsqueda mejorado con resaltado de resultados
- Filtrado por usuario
- Navegación con teclado (⌘G para siguiente, ⇧⌘G para anterior)
- Búsqueda en tiempo real mientras escribes

### 📤 Exportación de Conversaciones
- Exportar conversaciones a formato **texto plano (.txt)**
- Exportar conversaciones a formato **HTML** con formato bonito
- Diálogo para elegir formato y ubicación
- Incluye timestamps y formato legible

### 🔔 Notificaciones del Sistema macOS
- Notificaciones nativas cuando la app está en segundo plano
- Badge en el dock con contador de mensajes no leídos
- Notificaciones para menciones y mensajes privados
- Integración completa con el sistema de notificaciones de macOS

### 🎨 Mejoras de UI/UX
- Botones de búsqueda y exportar en el AppBar (solo macOS)
- Tooltips mejorados con atajos de teclado
- Interfaz más nativa para macOS

---

## 🛠️ Mejoras Técnicas

### 🔧 Servicios Nuevos
- **SearchService**: Servicio de búsqueda y filtrado de mensajes
- **ExportService**: Servicio para exportar conversaciones
- **MacOSNotificationService**: Servicio de notificaciones nativas
- **MacOSMenuService**: Servicio para menús nativos (preparado para futuras mejoras)

### 📦 Arquitectura
- Separación de responsabilidades mejorada
- Servicios modulares y reutilizables
- Mejor organización del código

### 🐛 Correcciones
- Corregido problema de radios en modo release (permisos de red)
- Mejorado sistema de logging para release
- Optimizaciones de rendimiento

---

## 📋 Cambios Técnicos Detallados

### Permisos macOS
- Agregado `com.apple.security.network.server` a Release.entitlements
- Agregado `com.apple.security.cs.allow-jit` para igualar permisos con Debug
- Todos los permisos ahora son idénticos entre Debug y Release

### Sistema de Búsqueda
- Búsqueda case-insensitive
- Resaltado de términos encontrados
- Filtrado por usuario opcional
- Navegación con teclado

### Sistema de Exportación
- Exportación a texto plano con formato legible
- Exportación a HTML con estilos CSS
- Diálogo nativo de macOS para elegir ubicación
- Timestamps formateados

---

## 🔄 Migración desde v1.0.5

No se requieren pasos especiales de migración. La aplicación actualizará automáticamente:
- Configuraciones existentes se mantienen
- Historial de mensajes se preserva
- Preferencias de usuario intactas

---

## 📥 Instalación

1. Descarga el archivo `irc_app_macos_v2.0.0.dmg`
2. Abre el DMG
3. Arrastra `irc_app.app` a la carpeta `Applications`
4. Ejecuta la aplicación desde `Applications`

**Nota**: Si tienes una versión anterior instalada, puedes reemplazarla directamente.

---

## 🐛 Problemas Conocidos

- Las notificaciones nativas requieren permisos del sistema (se solicitarán automáticamente)
- El badge del dock se actualiza cuando la app está activa

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

Esta versión marca un hito importante en la evolución de la aplicación, con un enfoque especial en la experiencia de usuario en macOS. Las mejoras de búsqueda y exportación hacen que la aplicación sea más útil para usuarios que necesitan revisar o compartir conversaciones.

---

**Versión**: 2.0.0  
**Fecha de Release**: Enero 2025  
**Plataforma**: macOS  
**Tamaño**: ~50.6 MB





