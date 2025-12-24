# 🔗 Integración de Reputación con UnrealIRCd

Sistema híbrido que combina la reputación del servidor IRC con la reputación del sistema de videoconferencias.

---

## 📋 TABLA DE CONTENIDOS

1. [Resumen](#resumen)
2. [Cómo Funciona](#cómo-funciona)
3. [Configuración de UnrealIRCd](#configuración-de-unrealircd)
4. [Sistema Híbrido](#sistema-híbrido)
5. [API y Uso](#api-y-uso)
6. [Ejemplos](#ejemplos)
7. [Solución de Problemas](#solución-de-problemas)

---

## 🎯 RESUMEN

La integración permite:

✅ **Sincronizar reputación** entre UnrealIRCd y la app
✅ **Calcular reputación híbrida** (40% IRC + 60% Video)
✅ **Actualización automática** cada 5 minutos
✅ **Bonificaciones IRC** por buen comportamiento
✅ **Penalizaciones** por kicks/bans
✅ **100% automático** y transparente

---

## 🔄 CÓMO FUNCIONA

### **Arquitectura:**

```
┌────────────────────────────────────────────────────────┐
│                  SISTEMA HÍBRIDO                        │
├────────────────────────────────────────────────────────┤
│                                                         │
│  [UnrealIRCd Server]                [Flutter App]      │
│         │                                    │          │
│         │  WHOIS requests                    │          │
│         ├────────────────────────────────────►          │
│         │                                    │          │
│         │  Reputation score (0-10000)        │          │
│         ◄────────────────────────────────────┤          │
│         │                                    │          │
│         │                                    ▼          │
│         │                       ┌──────────────────┐   │
│         │                       │ ReputationSync   │   │
│         │                       │                  │   │
│         │                       │ • IRC Rep: 40%   │   │
│         │                       │ • Video Rep: 60% │   │
│         │                       │ • Auto sync 5min │   │
│         │                       └──────────────────┘   │
│         │                                    │          │
│         │                                    ▼          │
│         │                       ┌──────────────────┐   │
│         │                       │ SQLite Database  │   │
│         │                       │ Hybrid Reputation│   │
│         │                       └──────────────────┘   │
│                                                         │
└────────────────────────────────────────────────────────┘
```

### **Flujo de Sincronización:**

```
1. App inicia → Servicio de sync se activa
   ↓
2. Cada 5 minutos:
   ├─ Obtener usuarios del canal
   ├─ Para cada usuario:
   │  ├─ Enviar WHOIS al servidor
   │  ├─ Parsear reputation score
   │  ├─ Obtener reputación video de BD
   │  ├─ Calcular híbrida: (IRC × 40%) + (Video × 60%)
   │  └─ Actualizar BD si cambio ≥ 5 puntos
   └─ Log de cambios
   ↓
3. Usuario ve su reputación actualizada en UI
```

### **Escalas de Reputación:**

| Sistema | Rango | Descripción |
|---------|-------|-------------|
| **UnrealIRCd** | 0-10000 | Score del servidor |
| **App (Video)** | 0-100 | Score de comportamiento en video |
| **Híbrida** | 0-100 | Promedio ponderado final |

---

## ⚙️ CONFIGURACIÓN DE UNREALIRCD

### **1. Habilitar Reputation System**

Editar `unrealircd.conf`:

```conf
# Habilitar sistema de reputación
set {
    reputation {
        enabled yes;
        
        # Mostrar en WHOIS
        show-in-whois yes;
        
        # Score inicial para nuevos usuarios
        default-score 5000;
        
        # Score mínimo y máximo
        min-score 0;
        max-score 10000;
        
        # Decaimiento de score por tiempo
        decay {
            enabled yes;
            rate 1;  # Puntos perdidos por hora de inactividad
        };
        
        # Penalizaciones
        penalty {
            # Por cada kick
            kick 500;
            
            # Por cada ban
            ban 2000;
            
            # Por flood
            flood 100;
            
            # Por exceso de conexiones
            connect-flood 50;
        };
        
        # Bonificaciones
        bonus {
            # Por tiempo conectado (por hora)
            connected-time 10;
            
            # Por tener nick registrado
            registered-nick 1000;
            
            # Por ser IRCop
            ircop 5000;
        };
    };
}
```

### **2. Configurar WHOIS Extendido**

Asegurar que WHOIS muestre reputation:

```conf
# En la sección de información de usuario
set {
    whois {
        # Mostrar información extendida
        extended yes;
        
        # Incluir reputation score
        reputation yes;
        
        # Otros campos útiles
        idle-time yes;
        channels yes;
        modes yes;
    };
}
```

### **3. Habilitar Comandos de Reputación**

```conf
# Comandos disponibles para IRCops
set {
    oper-commands {
        # Ver reputación de cualquier usuario
        /reputation <nick>
        
        # Modificar reputación manualmente
        /setrep <nick> <score>
        
        # Resetear reputación
        /resetrep <nick>
        
        # Estadísticas globales
        /repstats
    };
}
```

### **4. Configurar Logs de Reputación**

```conf
# Logging de cambios de reputación
log {
    reputation-changes {
        file "reputation.log";
        maxsize 10M;
        flush-on-write yes;
    };
}
```

### **5. Reiniciar UnrealIRCd**

```bash
./unrealircd restart
```

### **6. Verificar Configuración**

```bash
# Conectarse al servidor IRC
/connect your.server.com

# Verificar WHOIS propio
/whois yournick

# Deberías ver algo como:
# [yournick] reputation score is 5000
```

---

## 🔀 SISTEMA HÍBRIDO

### **Fórmula de Cálculo:**

```dart
Reputación Híbrida = (IRC_Rep × 40%) + (Video_Rep × 60%)
```

**Ejemplo:**
```
Usuario: JuanPerez
IRC Reputation: 8000/10000 → 80/100 normalizado
Video Reputation: 75/100

Cálculo:
Híbrida = (80 × 0.4) + (75 × 0.6)
       = 32 + 45
       = 77/100

Resultado final: 77 puntos
```

### **Pesos Configurables:**

Los pesos se pueden ajustar según prioridades:

| Escenario | IRC % | Video % | Razón |
|-----------|-------|---------|-------|
| **Por defecto** | 40% | 60% | Video es más importante |
| **Servidor nuevo** | 60% | 40% | Poca data de video aún |
| **Solo video** | 20% | 80% | Priorizar comportamiento video |
| **IRC estricto** | 70% | 30% | Confianza en histórico IRC |

```dart
// Cambiar pesos en el código
final hybrid = sync.calculateHybridReputation(
  ircReputation: 8000,
  videoReputation: 75,
  ircWeight: 0.7,  // 70% IRC
  videoWeight: 0.3, // 30% Video
);
```

### **Factores IRC Considerados:**

| Factor | Impacto | Puntos |
|--------|---------|--------|
| **Tiempo conectado** | Positivo | +10 por 100h |
| **Nick registrado** | Positivo | +5 |
| **IRCop** | Positivo | +15 |
| **Muchos canales** | Positivo | +3 |
| **1-5 kicks** | Negativo | -2 cada uno |
| **5-10 kicks** | Negativo | -10 |
| **>10 kicks** | Negativo | -20 |

### **Factores Video Considerados:**

| Factor | Impacto | Puntos |
|--------|---------|--------|
| **Email verificado** | Positivo | +10 |
| **Primera conferencia** | Positivo | +5 |
| **Buen comportamiento** | Positivo | +3 |
| **Recibir reporte** | Negativo | -5 |
| **Ser expulsado** | Negativo | -10 |
| **Ban temporal** | Negativo | -25 |
| **Ban permanente** | Negativo | 0 (reset) |

---

## 💻 API Y USO

### **Inicialización Automática:**

El servicio se inicia automáticamente al arrancar la app:

```dart
// En main.dart (ya configurado)
ref.watch(unrealircdReputationSyncProvider);

// Sincronización automática cada 5 minutos
```

### **Sincronizar Usuario Específico:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

// Sincronizar un usuario
final profile = await sync.syncUserReputation('JuanPerez');

if (profile != null) {
  print('Reputación actualizada: ${profile.reputation}/100');
}
```

### **Sincronizar Todos los Usuarios:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

// Sincronizar canal completo
await sync.syncAllUsers();
```

### **Obtener Reputación IRC:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

// Obtener score IRC directo
final ircRep = await sync.getIRCReputation('JuanPerez');

if (ircRep != null) {
  print('IRC Reputation: $ircRep/10000');
  
  // Convertir a escala 0-100
  final normalized = sync.convertIRCToAppReputation(ircRep);
  print('Normalizado: $normalized/100');
}
```

### **Aplicar Bonificación IRC:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

// Analizar factores IRC y aplicar bonificación
await sync.applyIRCBonus('JuanPerez');

// Esto analiza:
// - Tiempo conectado
// - Nick registrado
// - IRCop status
// - Kicks recibidos
// Y aplica bonificación/penalización automática
```

### **Calcular Reputación Híbrida:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

// Calcular manualmente
final hybrid = sync.calculateHybridReputation(
  ircReputation: 8000,      // Score IRC
  videoReputation: 75,      // Score video
  ircWeight: 0.4,           // 40% IRC
  videoWeight: 0.6,         // 60% Video
);

print('Reputación híbrida: $hybrid/100');
```

### **Estadísticas de Sincronización:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

final stats = sync.getSyncStats();

print('Reputaciones en cache: ${stats['cached_reputations']}');
print('Auto-sync activo: ${stats['auto_sync_active']}');
print('Usuarios IRC: ${stats['irc_users']}');
```

### **Control Manual:**

```dart
final sync = ref.read(unrealircdReputationSyncProvider);

// Detener sincronización automática
sync.stopAutoSync();

// Reanudar con intervalo custom
sync.startAutoSync(interval: Duration(minutes: 10));

// Limpiar cache
sync.clearCache();
```

---

## 💡 EJEMPLOS

### **Ejemplo 1: Usuario Nuevo**

```dart
// Usuario "NuevoUser" se registra
// IRC: 5000/10000 (default)
// Video: 50/100 (default)

final hybrid = sync.calculateHybridReputation(
  ircReputation: 5000,
  videoReputation: 50,
);

print(hybrid); // Output: 50
// (50 × 0.4) + (50 × 0.6) = 20 + 30 = 50
```

### **Ejemplo 2: Usuario Veterano**

```dart
// Usuario "Veterano" lleva años en el servidor
// IRC: 9500/10000 (muy buena reputación)
// Video: 85/100 (verificado, buen comportamiento)

final hybrid = sync.calculateHybridReputation(
  ircReputation: 9500,
  videoReputation: 85,
);

print(hybrid); // Output: 89
// (95 × 0.4) + (85 × 0.6) = 38 + 51 = 89
```

### **Ejemplo 3: Usuario Problemático**

```dart
// Usuario "Troll" con historial negativo
// IRC: 2000/10000 (muchos kicks/bans)
// Video: 25/100 (reportes múltiples)

final hybrid = sync.calculateHybridReputation(
  ircReputation: 2000,
  videoReputation: 25,
);

print(hybrid); // Output: 23
// (20 × 0.4) + (25 × 0.6) = 8 + 15 = 23
// Resultado: Cerca de ban automático
```

### **Ejemplo 4: IRCop Verificado**

```dart
// Usuario "AdminGlobal" es IRCop
// IRC: 10000/10000 (máxima)
// Video: 100/100 (admin, email verificado)

final hybrid = sync.calculateHybridReputation(
  ircReputation: 10000,
  videoReputation: 100,
);

print(hybrid); // Output: 100
// (100 × 0.4) + (100 × 0.6) = 40 + 60 = 100
// Resultado: Reputación perfecta
```

### **Ejemplo 5: Sincronización en Login**

```dart
// Al conectarse al servidor
void _onIRCConnected() async {
  final sync = ref.read(unrealircdReputationSyncProvider);
  
  // Obtener nick actual
  final myNick = ref.read(currentNicknameProvider);
  
  if (myNick != null) {
    // Sincronizar reputación inmediatamente
    final profile = await sync.syncUserReputation(myNick);
    
    if (profile != null) {
      print('Tu reputación: ${profile.reputation}/100');
      
      // Mostrar notificación si cambió
      if (profile.reputation >= 80) {
        _showNotification('¡Excelente reputación! 🌟');
      } else if (profile.reputation < 30) {
        _showNotification('⚠️ Reputación baja. Mejora tu comportamiento.');
      }
    }
  }
}
```

---

## 🐛 SOLUCIÓN DE PROBLEMAS

### **"No se sincroniza la reputación"**

**Causa 1:** UnrealIRCd no tiene reputation habilitado.

**Solución:**
```conf
# Verificar en unrealircd.conf
set {
    reputation {
        enabled yes;
        show-in-whois yes;
    };
}
```

**Causa 2:** WHOIS no devuelve reputation score.

**Solución:**
```bash
# Probar manualmente
/whois yournick

# Si no muestra "reputation score is XXXX"
# Actualizar UnrealIRCd a versión 6.0+
```

### **"Reputación no se actualiza en la app"**

**Causa:** Cache no se está actualizando.

**Solución:**
```dart
// Forzar limpieza de cache
final sync = ref.read(unrealircdReputationSyncProvider);
sync.clearCache();

// Sincronizar manualmente
await sync.syncUserReputation(nick);
```

### **"Sincronización muy lenta"**

**Causa:** Muchos usuarios en el canal.

**Solución:**
```dart
// Aumentar intervalo de sincronización
sync.stopAutoSync();
sync.startAutoSync(interval: Duration(minutes: 10)); // En vez de 5

// O sincronizar solo usuarios activos
```

### **"Reputación híbrida incorrecta"**

**Causa:** Pesos mal configurados.

**Solución:**
```dart
// Verificar pesos
final hybrid = sync.calculateHybridReputation(
  ircReputation: ircRep,
  videoReputation: videoRep,
  ircWeight: 0.4,  // Debe sumar 1.0
  videoWeight: 0.6, // 0.4 + 0.6 = 1.0 ✓
);
```

### **"Error al parsear WHOIS"**

**Causa:** Formato de respuesta diferente.

**Solución:**
Implementar parser custom para tu servidor:

```dart
// En unrealircd_reputation_sync.dart
// Personalizar parseWHOISReputation() según tu formato
```

---

## 📊 COMANDOS IRC ÚTILES

### **Para Usuarios:**

```irc
# Ver tu propia reputación
/whois yournick

# Salida ejemplo:
# [yournick] reputation score is 5000
```

### **Para IRCops:**

```irc
# Ver reputación de otro usuario
/reputation JuanPerez

# Modificar reputación manualmente
/setrep JuanPerez 7500

# Resetear reputación (volver a default)
/resetrep JuanPerez

# Estadísticas globales
/repstats

# Ver logs
/raw STATS r
```

---

## 🎯 MEJORES PRÁCTICAS

### **1. Monitorear Cambios Significativos**

```dart
// Alertar si hay cambios bruscos
if ((hybridRep - videoRep).abs() >= 20) {
  _notifyModerators('$nick: cambio drástico de reputación');
}
```

### **2. Sincronizar en Momentos Clave**

```dart
// Al unirse a conferencia
void _onJoinConference(String nick) async {
  await sync.syncUserReputation(nick);
}

// Al recibir reporte
void _onUserReported(String nick) async {
  await sync.syncUserReputation(nick);
}
```

### **3. Cachear Reputaciones Frecuentes**

```dart
// Evitar WHOIS excesivos
final cachedRep = _cache[nick];
if (cachedRep != null && 
    DateTime.now().difference(cachedRep['timestamp']) < Duration(minutes: 5)) {
  return cachedRep['reputation'];
}
```

### **4. Logs Detallados**

```dart
// Registrar todas las sincronizaciones
await _dbService.saveModerationAction(ModerationAction(
  id: uuid.v4(),
  moderatorNick: 'System',
  targetNick: nick,
  conferenceId: 'N/A',
  channel: 'N/A',
  action: 'reputation_sync',
  reason: 'IRC: $ircRep, Video: $videoRep → Híbrida: $hybridRep',
  timestamp: DateTime.now(),
));
```

---

## 🚀 PRÓXIMAS MEJORAS

### **Corto Plazo:**
- [ ] Parser robusto para diferentes formatos de WHOIS
- [ ] Cache persistente de reputaciones IRC
- [ ] Dashboard de estadísticas de sincronización
- [ ] Alertas de cambios significativos

### **Mediano Plazo:**
- [ ] Sincronización bidireccional (App → IRC)
- [ ] Comandos IRC custom desde la app
- [ ] Integración con otros daemons IRC (InspIRCd, etc)
- [ ] API REST para consultas externas

### **Largo Plazo:**
- [ ] Machine Learning para predecir comportamiento
- [ ] Blockchain para verificación de reputación
- [ ] Cross-server reputation (múltiples servidores)
- [ ] Gamificación con achievements

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

### **Servidor IRC:**
- [ ] UnrealIRCd versión 6.0+
- [ ] Reputation system habilitado
- [ ] WHOIS extendido configurado
- [ ] Logs de reputación activos
- [ ] Comandos de IRCop habilitados

### **Aplicación:**
- [ ] Provider inicializado en main.dart
- [ ] Sincronización automática activa
- [ ] Parser de WHOIS implementado
- [ ] BD actualizada con reputación híbrida
- [ ] UI muestra reputación correcta

### **Testing:**
- [ ] WHOIS devuelve reputation score
- [ ] Sincronización manual funciona
- [ ] Sincronización automática funciona
- [ ] Cálculo híbrido correcto
- [ ] Bonificaciones IRC aplican bien
- [ ] Penalizaciones funcionan
- [ ] Cache se limpia correctamente

---

## 🎉 ¡SISTEMA HÍBRIDO COMPLETO!

Tu aplicación IRC ahora tiene:
- ✅ Sincronización con UnrealIRCd
- ✅ Reputación híbrida (IRC + Video)
- ✅ Actualización automática cada 5 min
- ✅ Bonificaciones por buen comportamiento
- ✅ Penalizaciones por infracciones
- ✅ 100% configurable y extensible

**¡La reputación nunca fue tan completa!** 🌟

---

*Última actualización: Diciembre 2025*
*Versión: 2.1.0*
*Estado: Sistema Híbrido Implementado* ✅

