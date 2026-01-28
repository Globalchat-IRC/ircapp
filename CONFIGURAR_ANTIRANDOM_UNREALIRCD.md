# 🔧 Configurar antirandom en UnrealIRCd para Permitir IRC App

## 🎯 Problema

```
[antirandom] denied access to user with score 10: GlobalChat-76242@81.39.165.208
```

El módulo `antirandom` está rechazando conexiones porque detecta nicks con números aleatorios (como `GlobalChat-76242`).

## ✅ Soluciones

### Opción 1: Añadir Excepción para GlobalChat-* (Recomendado)

Añade esto a `unrealircd.conf`:

```conf
except {
    mask "GlobalChat-*!*@*";
    antirandom {
        enabled no;
        reason "IRC App - Cliente oficial";
    };
};
```

### Opción 2: Ajustar Umbrales de antirandom

Aumenta el umbral para que sea menos estricto:

```conf
set {
    antirandom {
        enabled yes;
        /* Aumentar el umbral de 10 a 20 o más */
        threshold 20;  /* Por defecto suele ser 10 */
        
        /* O desactivar completamente (NO RECOMENDADO) */
        /* enabled no; */
    };
};
```

### Opción 3: Excepción por IP (Si es tu IP fija)

Si tu IP es fija, puedes añadir una excepción por IP:

```conf
except {
    mask "*!*@81.39.165.208";
    antirandom {
        enabled no;
    };
};
```

### Opción 4: Ajustar Puntuación de Detección

Puedes ajustar cómo se calcula la puntuación:

```conf
set {
    antirandom {
        enabled yes;
        threshold 20;
        
        /* Reducir puntuación por números en nick */
        nick-score {
            numbers 2;  /* Reducir de 5 a 2 */
        };
        
        /* Reducir puntuación por caracteres especiales */
        nick-score {
            special 1;  /* Reducir si hay caracteres especiales */
        };
    };
};
```

## 🔍 Verificar Configuración Actual

Para ver la configuración actual:

```bash
# En el servidor IRC
/STATS antirandom
```

O revisa los logs:

```bash
tail -f /var/log/unrealircd/unrealircd.log | grep antirandom
```

## 📝 Configuración Completa Recomendada

Combina ambas excepciones (bot-tag y antirandom):

```conf
/* Excepción para IRC App */
except {
    mask "GlobalChat-*!*@*";
    
    /* Desactivar detección de bots */
    bot-tag {
        enabled no;
        reason "IRC App - Cliente oficial";
    };
    
    /* Desactivar antirandom */
    antirandom {
        enabled no;
        reason "IRC App - Cliente oficial";
    };
};
```

## 🚀 Pasos para Aplicar

1. **Editar configuración:**
   ```bash
   sudo nano /etc/unrealircd/unrealircd.conf
   # O donde esté tu archivo de configuración
   ```

2. **Añadir la excepción** (Opción 1 es la más recomendada)

3. **Verificar sintaxis:**
   ```bash
   /unrealircd configtest
   ```

4. **Recargar configuración:**
   ```bash
   /rehash
   ```

   O reiniciar:
   ```bash
   sudo systemctl restart unrealircd
   ```

## 🔍 Verificar que Funciona

Después de aplicar:

1. Conéctate desde tu app
2. Verifica los logs:
   ```bash
   tail -f /var/log/unrealircd/unrealircd.log | grep -E "(antirandom|bot-tag)"
   ```
3. No deberías ver mensajes de "denied access" o "bot detected"

## 📚 Referencia UnrealIRCd

- Documentación antirandom: https://www.unrealircd.org/docs/Antirandom_module
- Documentación except: https://www.unrealircd.org/docs/Except_block

## ⚠️ Nota Importante

El módulo `antirandom` está diseñado para prevenir conexiones automatizadas y spam. Al añadir excepciones, asegúrate de que solo afecten a tu aplicación legítima y no a bots maliciosos.

## 🎯 Solución Definitiva

La mejor solución es combinar ambas excepciones en un solo bloque `except`:

```conf
except {
    mask "GlobalChat-*!*@*";
    bot-tag { enabled no; };
    antirandom { enabled no; };
};
```

Esto resuelve tanto el problema de detección de bots como el de antirandom.
