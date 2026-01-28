# 🔧 Configurar UnrealIRCd en Ceres/Apolo para No Detectar como Bot

## 🎯 Problema

Ceres y Apolo detectan la aplicación como bot, pero otros nodos no. Esto es un problema de configuración de UnrealIRCd.

## ✅ Soluciones en UnrealIRCd

### Opción 1: Ajustar Reglas de Detección de Bots (Recomendado)

Edita el archivo de configuración de UnrealIRCd (normalmente `unrealircd.conf` o en `/etc/unrealircd/`):

```conf
/* Ajustar detección de bots */
set {
    /* Desactivar detección de bots completamente */
    /* O ajustar los umbrales */
    bot-tag {
        enabled yes;
        /* Aumentar el umbral para que sea menos estricto */
        threshold 10;  /* Valor por defecto suele ser 5-7 */
    };
    
    /* O desactivar completamente */
    /* bot-tag { enabled no; }; */
};
```

### Opción 2: Añadir Excepciones por Patrón

Añade excepciones para nicks que empiecen con "GlobalChat-":

```conf
/* Excepciones para detección de bots */
except {
    mask "*!*@*";
    /* No detectar como bot si el nick empieza con GlobalChat- */
    bot-tag {
        mask "GlobalChat-*!*@*";
        reason "IRC App Client";
    };
};
```

### Opción 3: Ajustar Requisitos de USER

El problema puede estar en cómo se valida el comando USER. Ajusta:

```conf
set {
    /* Hacer menos estricta la validación de USER */
    require-userinfo yes;  /* Cambiar a no si es muy estricto */
    
    /* O ajustar el módulo de detección de bots */
    bot-tag {
        enabled yes;
        /* No detectar si el realname contiene "IRC Client" o "IRC App" */
        exempt-realname {
            "*IRC Client*";
            "*IRC App*";
        };
    };
};
```

### Opción 4: Desactivar Temporalmente la Detección

Para probar, puedes desactivar completamente:

```conf
set {
    bot-tag {
        enabled no;
    };
};
```

**⚠️ ADVERTENCIA:** Esto desactiva la detección de bots para todos, no solo para tu app.

## 🔍 Verificar Configuración Actual

Para ver la configuración actual de detección de bots:

```bash
# En el servidor, ejecuta:
/STATS bot-tag
```

O revisa los logs cuando alguien se conecta:

```bash
tail -f /var/log/unrealircd/unrealircd.log | grep -i bot
```

## 📝 Configuración Recomendada

La mejor solución es añadir una excepción específica:

```conf
/* En unrealircd.conf */
except {
    mask "GlobalChat-*!*@*";
    bot-tag {
        enabled no;
        reason "IRC App - Cliente oficial";
    };
};
```

O ajustar los umbrales:

```conf
set {
    bot-tag {
        enabled yes;
        threshold 15;  /* Aumentar de 5-7 a 15 */
        /* No detectar si realname contiene estas palabras */
        exempt-realname {
            "*IRC*";
            "*Client*";
            "*App*";
        };
    };
};
```

## 🚀 Pasos para Aplicar

1. **Editar configuración:**
   ```bash
   sudo nano /etc/unrealircd/unrealircd.conf
   # O donde esté tu archivo de configuración
   ```

2. **Añadir la excepción o ajustar bot-tag**

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
   # O
   sudo service unrealircd restart
   ```

## 🔍 Verificar que Funciona

Después de aplicar los cambios:

1. Conéctate desde tu app
2. Verifica los logs:
   ```bash
   tail -f /var/log/unrealircd/unrealircd.log
   ```
3. No deberías ver mensajes de "bot detected" o "You look like a bot"

## 📚 Referencia UnrealIRCd

- Documentación oficial: https://www.unrealircd.org/docs/Bot_tag
- Configuración de excepciones: https://www.unrealircd.org/docs/Except_block

## ⚠️ Nota Importante

Si otros nodos (no ceres/apolo) funcionan bien, significa que tienen una configuración diferente de `bot-tag`. Compara los archivos de configuración entre nodos para ver las diferencias.
