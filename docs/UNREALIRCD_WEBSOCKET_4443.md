# UnrealIRCd: WebSocket en puerto 4443

La app web se conecta **directo** al WebSocket de UnrealIRCd en el puerto **4443** (wss://servidor:4443). No hay gateway intermedio.

Para que funcione, el puerto 4443 debe estar configurado como **WebSocket** en `unrealircd.conf`.

## 1. Módulos

En `unrealircd.conf`:

```
loadmodule "websocket";
loadmodule "webserver";
```

Luego: `/rehash` en IRC.

## 2. Bloque listen para 4443

No basta con:

```
listen {
    ip *;
    port 4443;
}
```

Tiene que incluir **websocket** (y **tls** si usas wss). Ejemplo con TLS (recomendado):

```
listen {
    ip *;
    port 4443;
    options {
        tls;
        websocket { type text; }
    }
    tls-options {
        certificate "/ruta/a/fullchain.pem";
        key "/ruta/a/privkey.pem";
        options { no-client-certificate; }
    }
}
```

- **no-client-certificate** es necesario para que Chrome no falle al conectar.
- Si usas Let's Encrypt, las rutas suelen ser como `/etc/letsencrypt/live/tudominio/fullchain.pem` y `privkey.pem`.

Sin TLS (solo pruebas, no desde https):

```
listen {
    ip *;
    port 4443;
    options { websocket { type text; } }
}
```

## 3. Comprobar

- Desde https solo se puede usar **wss://** (no ws://).
- La app usa **wss://&lt;servidor&gt;:4443** (mismo host que el IRC, por ejemplo ceres.globalchat.org).
- Si no conecta: revisar que el listen tenga `websocket { type text; }` y, con wss, `tls` + certificado y `no-client-certificate`.

Documentación oficial: https://www.unrealircd.org/docs/WebSocket_support
