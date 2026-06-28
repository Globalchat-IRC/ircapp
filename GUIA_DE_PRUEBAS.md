# 🧪 Guía de Pruebas - IRC App

Guía completa para probar todas las funcionalidades implementadas.

---

## 🎯 CHECKLIST DE PRUEBAS

### ✅ **FUNCIONALIDADES BÁSICAS**

#### 1️⃣ **Conexión IRC**
- [ ] Abrir la app → Pantalla de login
- [ ] Ingresar datos:
  - Servidor: `irc.yourserver.com`
  - Puerto: `6667` (o `6697` para SSL)
  - Nick: Tu nickname
- [ ] Click en "Conectar"
- [ ] Verificar que aparece "✅ Conectado"

#### 2️⃣ **Chat Básico**
- [ ] Unirse a un canal: `/join #test`
- [ ] Enviar mensaje normal
- [ ] Enviar mensaje con delay (slider)
- [ ] Probar autocompletado de comandos (escribe `/` y presiona Tab)
- [ ] Probar autocompletado de nicks (escribe `@` y un nombre)

#### 3️⃣ **Mensajes Especiales**
- [ ] Enviar `/me está probando` → Debe verse en itálica con color
- [ ] Editar mensaje enviado (botón de lápiz)
- [ ] Forzar envío inmediato (botón de rayo ⚡)
- [ ] Responder a un mensaje específico

---

### 🎥 **VIDEOCONFERENCIAS**

#### 4️⃣ **Conferencia de Canal**
- [ ] Estar en un canal (#test)
- [ ] Click en botón **🎥** (junto a emojis)
- [ ] Leer términos completos (scroll hasta el final)
- [ ] Click en "Acepto las normas"
- [ ] Verificar que se abre Jitsi Meet
- [ ] Verificar mensaje automático en el canal
- [ ] Tu nick debe mostrar emoji 🎥

#### 5️⃣ **Videollamada Privada**
- [ ] Abrir mensaje privado con otro usuario
- [ ] Click en botón **📹** (junto al campo de texto)
- [ ] Aceptar términos (si es primera vez)
- [ ] Verificar que se abre Jitsi Meet
- [ ] Verificar invitación enviada al otro usuario
- [ ] Tu nick debe mostrar emoji 📹

#### 6️⃣ **Emoticonos de Estado**
- [ ] Usuario en conferencia de canal → 🎥 Nick
- [ ] Usuario en videollamada privada → 📹 Nick
- [ ] Usuario normal → Nick (sin emoji)
- [ ] Verificar que aparece en lista de usuarios

---

### 👮 **PANEL DE MODERACIÓN**

#### 7️⃣ **Acceso al Panel**
- [ ] Con la app corriendo, abrir navegador
- [ ] Ir a: `http://localhost:8765/mod`
- [ ] Ingresar nick de IRCop
- [ ] Ingresar password (cualquiera por ahora)
- [ ] Click en "Entrar"

#### 8️⃣ **Dashboard**
- [ ] Ver estadísticas en la parte superior
- [ ] Ver grid de cámaras (si hay usuarios en video)
- [ ] Verificar que muestra emoticonos 🎥/📹
- [ ] Ver lista de reportes (si hay)
- [ ] Ver logs en tiempo real en la parte inferior

#### 9️⃣ **Acciones de Moderación**
- [ ] Click en "Expulsar" en una cámara
- [ ] Ingresar razón de expulsión
- [ ] Verificar log en la parte inferior
- [ ] Probar botón "Banear"
- [ ] Verificar WebSocket conectado (🟢 arriba a la derecha)

---

### 🗄️ **BASE DE DATOS Y REPUTACIÓN**

#### 🔟 **Ver Perfil de Usuario**
- [ ] Click derecho en un usuario (o implementar botón)
- [ ] Seleccionar "Ver Perfil"
- [ ] Verificar que abre `UserProfileDialog`

**En el perfil deberías ver:**
- [ ] Header con avatar y emoji de rol
- [ ] Badge de reputación con color
- [ ] Pestaña "Info":
  - Fecha de registro
  - Estado de verificación (email, teléfono, ID)
  - Reputación actual
  - Permisos de video
- [ ] Pestaña "Reputación":
  - Historial de cambios
  - Razones de cada cambio
- [ ] Pestaña "Actividad":
  - Conferencias pasadas
  - Duración y participantes

#### 1️⃣1️⃣ **Verificación de Email**
- [ ] En el menú de usuario (o botón)
- [ ] Click en "Verificar Email"
- [ ] Ingresar email válido
- [ ] Click en "Enviar Código"
- [ ] Ver código en consola (para testing)
- [ ] Ingresar código de 6 dígitos
- [ ] Click en "Verificar"
- [ ] Verificar mensaje de éxito
- [ ] Verificar que reputación subió +10
- [ ] Verificar badge ✉️ en perfil

#### 1️⃣2️⃣ **Sistema de Reputación**
- [ ] Ver badge de reputación en lista de usuarios
- [ ] Colores según nivel:
  - Verde: 80-100 (⭐ excelente)
  - Verde claro: 60-79 (👍 buena)
  - Naranja: 40-59 (➖ regular)
  - Naranja oscuro: 20-39 (👎 baja)
  - Rojo: 0-19 (🚫 muy baja)

---

### 🔗 **INTEGRACIÓN CON UNREALIRCD**

#### 1️⃣3️⃣ **Sincronización IRC**
⚠️ **Requiere UnrealIRCd con reputation system habilitado**

- [ ] Conectar al servidor IRC
- [ ] Esperar 5 minutos (sincronización automática)
- [ ] Verificar en logs:
  ```
  🔄 [REP-SYNC] Sincronizando X usuarios...
  ✅ [REP-SYNC] Sincronizados X/X usuarios
  ```
- [ ] Hacer WHOIS de ti mismo: `/whois tunick`
- [ ] Verificar que muestra: `reputation score is XXXX`
- [ ] Ver si tu reputación cambió en la app

#### 1️⃣4️⃣ **Reputación Híbrida**
- [ ] Ver perfil de un usuario
- [ ] Verificar que la reputación es el promedio:
  - 40% IRC + 60% Video
- [ ] Ejemplo: IRC 8000/10000 (80) + Video 75/100
  - Híbrida: (80 × 0.4) + (75 × 0.6) = 77

---

### 🎨 **INTERFAZ Y UX**

#### 1️⃣5️⃣ **Tema y Diseño**
- [ ] Verificar tema oscuro/claro
- [ ] Verificar colores según rol
- [ ] Iconos visibles y claros
- [ ] Animaciones suaves
- [ ] Responsive en diferentes tamaños

#### 1️⃣6️⃣ **Versión de la App**
- [ ] Ver versión en esquina inferior derecha
- [ ] Debe mostrar: `v1.0.1` o similar
- [ ] Verificar que sea visible sobre RadioControls

#### 1️⃣7️⃣ **Sistema de Actualizaciones**
- [ ] Ver si aparece banner de actualización
- [ ] Si hay versión nueva → Banner en la parte superior
- [ ] Botones: "Ver Detalles", "Actualizar", "Cerrar"

---

## 🐛 **PRUEBAS DE ERRORES**

#### 1️⃣8️⃣ **Manejo de Errores**
- [ ] Intentar conectar con datos incorrectos
- [ ] Verificar mensaje de error claro
- [ ] Desconectar internet y probar
- [ ] Verificar que la app no se cuelga

#### 1️⃣9️⃣ **Límites y Validaciones**
- [ ] Enviar mensaje vacío → No debe enviar
- [ ] Nick muy largo → Debe truncar
- [ ] Código de verificación incorrecto → Error claro
- [ ] Reputación fuera de rango → Clampeado a 0-100

---

## 📊 **PRUEBAS DE RENDIMIENTO**

#### 2️⃣0️⃣ **Rendimiento**
- [ ] Canal con muchos usuarios (>50)
- [ ] Muchos mensajes rápidos
- [ ] Múltiples conferencias simultáneas
- [ ] Panel de moderación con muchas cámaras
- [ ] Base de datos con muchos registros

---

## 🔍 **VERIFICACIÓN DE LOGS**

#### 2️⃣1️⃣ **Consola de Flutter**
Buscar estos mensajes de confirmación:

```
✅ [VIDEO-DB] Base de datos inicializada
✅ [MOD-SERVER] Servidor iniciado automáticamente
   http://localhost:8765/mod
✅ [REP-SYNC] Servicio de sincronización IRC iniciado
📦 [ChatScreen] App version: v1.0.1
👤 [VIDEO] Perfil cargado desde BD: nick (Rep: XX)
```

#### 2️⃣2️⃣ **Panel de Moderación**
En `http://localhost:8765/mod`:
```
[14:23:15] ✅ Autenticado como AdminGlobal
[14:23:20] 🔌 Conectado al servidor WebSocket
```

#### 2️⃣3️⃣ **Base de Datos**
Verificar archivo creado:
```
/Users/[tu_usuario]/Library/Application Support/video_moderation.db
```

---

## 🎯 **ESCENARIOS DE USO COMPLETOS**

### **Escenario 1: Usuario Nuevo**
```
1. Abrir app por primera vez
2. Conectar al IRC
3. Unirse a #test
4. Enviar algunos mensajes
5. Verificar email
   → Reputación: 50 → 60 (+10)
6. Iniciar conferencia de canal
7. Verificar términos
8. Ver que aparece emoji 🎥
9. Salir de conferencia
   → Emoji desaparece
```

### **Escenario 2: Moderador**
```
1. Conectar como IRCop
2. Abrir panel de moderación
   → http://localhost:8765/mod
3. Autenticarse
4. Ver usuarios en video
5. Recibir reporte de usuario
6. Expulsar usuario problemático
7. Ver logs de acción
8. Verificar reputación bajó
```

### **Escenario 3: Reputación Híbrida**
```
1. Usuario conecta al IRC
2. Tiene buena reputación IRC (8000/10000)
3. Verifica email en la app
   → Video: 60/100
4. Sistema calcula híbrida:
   → (80 × 0.4) + (60 × 0.6) = 68/100
5. Ver perfil → Badge con 68 puntos
6. Iniciar conferencia sin restricciones
```

---

## 🎊 **CHECKLIST FINAL**

Marca las funcionalidades que funcionan correctamente:

### **Core:**
- [ ] ✅ Conexión IRC estable
- [ ] ✅ Envío y recepción de mensajes
- [ ] ✅ Comandos IRC funcionan
- [ ] ✅ Autocompletado funciona

### **Video:**
- [ ] 🎥 Conferencias de canal
- [ ] 📹 Videollamadas privadas
- [ ] 🎯 Términos obligatorios
- [ ] 🔔 Emoticonos de estado

### **Moderación:**
- [ ] 👮 Panel web accesible
- [ ] 📹 Grid de cámaras
- [ ] 🚪 Expulsar usuarios
- [ ] 🚫 Banear usuarios
- [ ] 📊 Logs en tiempo real
- [ ] 🔌 WebSocket conectado

### **Base de Datos:**
- [ ] 🗄️ BD SQLite creada
- [ ] 👤 Perfiles guardados
- [ ] ⭐ Reputación funciona
- [ ] 📈 Historial se guarda

### **Verificación:**
- [ ] ✉️ Envío de código
- [ ] ✅ Verificación exitosa
- [ ] 🎁 Bonificación +10 rep
- [ ] 🏷️ Badge visible

### **IRC Sync:**
- [ ] 🔄 Sincronización auto
- [ ] 📊 WHOIS funciona
- [ ] 🔀 Reputación híbrida
- [ ] 🎯 Pesos correctos (40%/60%)

---

## 📞 **REPORTE DE BUGS**

Si encuentras algún problema, anota:

```
BUG #:
Descripción:
Pasos para reproducir:
1.
2.
3.
Resultado esperado:
Resultado actual:
Logs (si hay):
```

---

## 🎉 **¡DISFRUTA PROBANDO!**

Esta aplicación tiene **7000+ líneas de código** y **2500+ líneas de documentación**.

Todas las funcionalidades están implementadas y listas para usar.

Si todo funciona correctamente, ¡tienes una plataforma IRC completa y profesional! 🚀

---

*Última actualización: Diciembre 2025*
*Versión: 2.1.0*

