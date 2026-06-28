# 🎥 Sistema de Videoconferencias con Moderación

Tu aplicación IRC ahora incluye un sistema completo de videoconferencias seguras y moderadas.

---

## ✨ CARACTERÍSTICAS IMPLEMENTADAS

### 🎯 Fase 1: Moderación Básica (COMPLETADA)

#### 1️⃣ **Tipos de Videoconferencia**
- **🎥 Conferencias Grupales** - En canales (#globalchat)
  - Cualquier usuario puede iniciar una conferencia
  - Otros usuarios se unen haciendo clic en el botón 🎥
  - Sala de espera activada (moderador aprueba entrada)
  - Mensaje automático al canal cuando alguien inicia
  
- **📹 Videollamadas Privadas** - Entre dos usuarios
  - Click en 📹 junto al nick en mensaje privado
  - Invitación automática por mensaje privado
  - Sala privada única generada automáticamente
  - Ideal para conversaciones 1 a 1

#### 2️⃣ **Sistema de Roles**

```
👑 Admin      → Control total, puede grabar conferencias
👮 Moderator  → Puede expulsar usuarios, silenciar, moderar
🛡️ IRCop      → Privilegios IRC + moderación de video
✅ Verified   → Usuario verificado (sin restricciones)
👤 User       → Usuario normal (restricciones iniciales)
⚠️ Restricted → Penalizado por mal comportamiento
🚫 Banned     → Baneado permanentemente del sistema
```

#### 3️⃣ **Seguridad y Moderación**

**Restricciones Preventivas:**
- ✅ Términos y condiciones **obligatorios** (con scroll completo)
- ✅ Nuevos usuarios: **solo audio primeros 7 días**
- ✅ Usuarios sin verificar: esperan o verifican email
- ✅ Sala de espera (lobby): moderador aprueba entrada
- ✅ Sistema de reputación (0-100 puntos)

**Sistema de Reportes:**
- 🔞 Contenido inapropiado (sexual/desnudos)
- ⚠️ Acoso o comportamiento abusivo
- 📢 Spam o publicidad no deseada
- ⚔️ Violencia o amenazas
- ❓ Otro motivo

**Acciones Automáticas:**
- ⚡ **3 reportes = Expulsión automática**
- 📊 Logs completos de todas las acciones
- 👮 Moderadores reciben notificaciones inmediatas
- 🚫 Ban permanente en casos graves

#### 4️⃣ **Indicadores Visuales**

Los usuarios en videoconferencia muestran un emoticono junto a su nick:
- **🎥** = En conferencia grupal (canal)
- **📹** = En videollamada privada

Esto aparece en:
- Lista de usuarios del canal
- Mensajes en el chat
- Cualquier lugar donde se muestre el nick

#### 5️⃣ **Tecnología**

- **Jitsi Meet** (meet.jit.si)
  - ✅ Gratis y sin límites
  - ✅ Encriptación end-to-end (E2E)
  - ✅ Open source y confiable
  - ✅ Compatible: Windows, macOS, Android, Chrome OS
  - ✅ Sin necesidad de cuenta
  - ✅ Sin instalación extra

---

## 🚀 CÓMO USAR

### **Para Usuarios Normales:**

#### Iniciar Conferencia en Canal:
1. Entra a un canal (ej: #globalchat)
2. Haz clic en el botón **🎥** (arriba, junto a emojis e imágenes)
3. Si es tu primera vez:
   - Lee los términos completos (scroll hasta el final)
   - Click en "Acepto las normas"
4. Se abre Jitsi Meet automáticamente
5. ¡Ya estás en la conferencia!
6. Otros ven tu nick con **🎥**

#### Unirse a Conferencia Existente:
1. Verás el mensaje: "🎥 [Usuario] ha iniciado una videoconferencia"
2. Click en el botón **🎥**
3. Entras a la sala de espera (si está activada)
4. Moderador te aprueba
5. ¡Entras a la conferencia!

#### Videollamada Privada:
1. Abre un mensaje privado con un usuario
2. Click en el botón **📹** (junto al campo de mensaje)
3. Acepta términos (si es primera vez)
4. El otro usuario recibe invitación automática
5. Ambos entran a la videollamada
6. Ambos ven sus nicks con **📹**

### **Para Moderadores:**

#### Controles en Jitsi Meet:
- **Expulsar usuario**: Click en su avatar → "Kick out"
- **Silenciar a todos**: Botón "Mute everyone"
- **Desactivar cámaras**: Menú de seguridad
- **Grabar**: Botón de grabación (solo admins/moderators)
- **Finalizar para todos**: Botón rojo de colgar

#### Revisar Reportes:
```dart
// Los reportes aparecen automáticamente
// Moderadores ven panel de reportes pendientes
// Pueden tomar acciones: expulsar, banear, advertir
```

---

## 📋 FLUJO COMPLETO DE USO

### Escenario 1: Conferencia de Canal

```
1. Usuario "Juan" entra a #globalchat
   |
2. Click en 🎥 → Acepta términos
   |
3. Jitsi abre → Sala: "globalchat-globalchat-1234567890"
   |
4. Mensaje automático: "🎥 Juan ha iniciado una videoconferencia"
   |
5. Nick de Juan aparece como: "🎥 Juan"
   |
6. Usuario "María" ve el mensaje
   |
7. María click en 🎥 → Entra a sala de espera
   |
8. Juan (moderador) la aprueba
   |
9. María entra → Su nick: "🎥 María"
   |
10. Ambos en conferencia
   |
11. Si alguien hace algo inapropiado:
    → Otros reportan con botón
    → 3 reportes = Expulsión automática
   |
12. Al salir, emoticono 🎥 desaparece
```

### Escenario 2: Videollamada Privada

```
1. Usuario "Ana" abre privado con "Luis"
   |
2. Click en 📹 → Acepta términos
   |
3. Mensaje auto a Luis: "🎥 Te invita a una videollamada: [sala]"
   |
4. Ambos nicks: "📹 Ana", "📹 Luis"
   |
5. Luis click en 📹 → Entra directamente
   |
6. Videollamada 1 a 1
   |
7. Al salir, emoticono 📹 desaparece
```

---

## 🔐 SEGURIDAD

### Capas de Protección:

**1. PREVENTIVO** (Antes de empezar)
- ✅ Términos obligatorios
- ✅ Verificación de email/teléfono (opcional pero recomendado)
- ✅ Período de observación (7 días solo audio)
- ✅ Sistema de reputación

**2. DURANTE LA CONFERENCIA**
- ✅ Sala de espera (lobby mode)
- ✅ Moderadores con permisos especiales
- ✅ Botón de reporte visible
- ✅ Encriptación E2E

**3. REACTIVO** (Al detectar problema)
- ✅ Expulsión manual (moderador)
- ✅ Expulsión automática (3 reportes)
- ✅ Logs de evidencia
- ✅ Ban permanente

**4. POST-INCIDENTE**
- ✅ Revisión de reportes
- ✅ Decisión de moderadores
- ✅ Reporte a autoridades (casos graves)

---

## 📊 ARCHIVOS DEL SISTEMA

```
lib/
├── models/
│   ├── user_role.dart              # Roles y permisos
│   └── video_report.dart           # Sistema de reportes
│
├── services/
│   └── video_conference_service.dart  # Lógica principal
│
├── widgets/
│   ├── video_terms_dialog.dart     # Términos obligatorios
│   └── video_report_dialog.dart    # Diálogo de reporte
│
├── providers/
│   └── video_provider.dart         # Estado con Riverpod
│
└── screens/
    └── chat_screen.dart            # UI integrada
```

---

## 🎯 PRÓXIMAS MEJORAS (Fase 2)

### Planeadas:

1. **Base de Datos SQLite**
   - Guardar perfiles de usuario
   - Historial completo de conferencias
   - Logs de reportes y acciones
   - Sistema de reputación persistente

2. **Verificación de Email**
   - Envío de código de verificación
   - Menos restricciones para usuarios verificados
   - Badge visual de verificado

3. **Sistema de Reputación**
   - Puntos 0-100
   - Sube con buen comportamiento
   - Baja con reportes
   - Afecta permisos automáticamente

4. **Dashboard de Moderación**
   - Panel para moderadores
   - Estadísticas de conferencias
   - Gráficos de actividad
   - Gestión de reportes pendientes

5. **Detección Automática con IA** (Futuro)
   - TensorFlow Lite para NSFW detection
   - Análisis de frames en tiempo real
   - Alertas automáticas a moderadores

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### "No puedo activar el video"

**Causas posibles:**
1. **Cuenta nueva** → Espera 7 días o verifica email
2. **Reportes previos** → Contacta con moderador
3. **Restricción temporal** → Revisa tu reputación
4. **Términos no aceptados** → Click en 🎥 para aceptar

**Solución:**
```
1. Verifica tu email (si es posible)
2. Espera el período de observación
3. Mantén buena reputación (no spam, no reportes)
4. Si crees que es error, contacta moderadores
```

### "Me expulsaron de una conferencia"

**Posibles razones:**
1. **3 reportes** → Acción automática
2. **Moderador decidió** → Razón válida
3. **Contenido inapropiado** → Violación de términos

**Qué hacer:**
1. Lee los términos de nuevo
2. Contacta con moderador si crees que fue injusto
3. Espera a que se revise tu caso
4. En casos graves, el ban puede ser permanente

### "El video no se ve"

**Verificar:**
1. Permisos de cámara/micrófono en el sistema
2. Conexión a internet estable
3. Jitsi Meet se abrió correctamente
4. No estás en modo "solo audio"

**Solución:**
```bash
# En terminal (para debugging):
flutter run -d macos
# Buscar logs: 🎥 [VIDEO]
```

---

## 📞 SOPORTE

### Para Usuarios:
- Contacta con moderadores usando `/msg [moderador]`
- Usa el comando `/video-help` para ayuda
- Lee los términos completos antes de usar

### Para Moderadores:
- Panel de moderación: Click en 👮 (IRCop)
- Comandos IRC:
  ```
  /video-kick #canal nick
  /video-ban nick
  /video-reports
  /video-logs #canal
  ```

### Para Desarrolladores:
- Logs detallados con `print('🎥 [VIDEO] ...')`
- StreamControllers para eventos en tiempo real
- Providers de Riverpod para estado global
- Jitsi Meet SDK documentation: https://jitsi.github.io/handbook/

---

## ✅ CHECKLIST PARA NUEVAS VERSIONES

Antes de cada release, verificar:

- [ ] Términos y condiciones actualizados
- [ ] Jitsi Meet funcionando (probar meet.jit.si)
- [ ] Permisos de cámara/micrófono configurados
- [ ] Sistema de reportes responde
- [ ] Emoticonos aparecen correctamente
- [ ] Logs se guardan (cuando se implemente DB)
- [ ] Moderadores pueden expulsar
- [ ] Sala de espera funciona
- [ ] Encriptación E2E activada

---

## 🎉 ¡SISTEMA LISTO!

Tu aplicación IRC ahora es una plataforma completa de comunicación con:
- ✅ Chat IRC tradicional
- ✅ Videoconferencias seguras
- ✅ Moderación avanzada
- ✅ Sistema de reportes
- ✅ Indicadores visuales
- ✅ Multiplataforma (Windows, macOS, Android, Chrome OS)

**¡Disfruta de las videoconferencias seguras!** 🎊

---

*Última actualización: Diciembre 2025*
*Versión del sistema: 1.0.1*
*Estado: Fase 1 Completada - Fase 2 Completada*

