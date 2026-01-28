# 🔍 Ident (Username) que Envía la App

## 📋 Formato del Comando USER

La app envía el comando USER con este formato:

```
USER <username> 0 * :<realname>
```

## 🔍 Cómo se Genera el Username (Ident)

### Lógica Actual

1. **Toma el nickname** (ej: `GlobalChat-76242`)
2. **Convierte a minúsculas** (ej: `globalchat-76242`)
3. **Extrae solo las letras** (ej: `globalchat`)
4. **Si hay al menos 3 letras:**
   - Usa esa parte (máximo 8 caracteres)
   - Ejemplo: `GlobalChat-76242` → `globalchat`
5. **Si no hay suficientes letras:**
   - Usa `ircapp` en lugar de `user` genérico

### Ejemplos

| Nickname | Username (Ident) | Realname |
|----------|------------------|----------|
| `GlobalChat-76242` | `globalchat` | `GlobalChat-76242 - IRC App` |
| `GlobalChat-123` | `globalchat` | `GlobalChat-123 - IRC App` |
| `User123` | `user` | `User123 - IRC App` |
| `ABC-999` | `abc` | `ABC-999 - IRC App` |
| `123456` | `ircapp` | `123456 - IRC App` |

## ⚠️ Problema con antirandom

El módulo `antirandom` de UnrealIRCd puede bloquear si:

1. **El username es muy genérico** (como `user`, `guest`, `test`)
2. **El username tiene números** (aunque ahora los eliminamos)
3. **El realname es muy genérico**

## ✅ Solución Aplicada

- **Username:** Ahora usa `ircapp` en lugar de `user` si no hay suficientes letras
- **Realname:** Incluye el nickname completo para que sea único: `GlobalChat-76242 - IRC App`

## 🔧 Para Verificar Qué Se Envía

En los logs de la app verás:

```
✅ [IRCService] Commands sent: NICK GlobalChat-76242, USER globalchat 0 * :GlobalChat-76242 - IRC App
```

Esto muestra:
- **NICK:** `GlobalChat-76242`
- **USER username:** `globalchat`
- **USER realname:** `GlobalChat-76242 - IRC App`

## 📝 Configuración en UnrealIRCd

Para permitir estos ident, añade a `unrealircd.conf`:

```conf
except {
    mask "GlobalChat-*!*@*";
    antirandom {
        enabled no;
    };
    bot-tag {
        enabled no;
    };
};
```

O si quieres ser más específico con el ident:

```conf
except {
    mask "*!globalchat@*";
    mask "*!ircapp@*";
    antirandom {
        enabled no;
    };
    bot-tag {
        enabled no;
    };
};
```
