# PWA y Service Worker (Flutter Web)

## Despliegue en la raíz

La app se sirve en **la raíz** del dominio:
- **URL:** https://mobilev1.globalchat.org/
- **Ruta en servidor:** `/var/www/irc_app/`

Por eso el build debe usar siempre **`--base-href="/"`**:

```bash
flutter build web --release --base-href="/"
```

Los scripts `deploy_completo.sh`, `nueva_version_deploy.sh` y `build_web_secure.sh` ya usan este base href.

## Errores en consola: FetchEvent / "the promise was rejected"

Si en la consola del navegador ves:

- `The FetchEvent for "<URL>" resulted in a network error response: the promise was rejected`
- `Failed to load resource: net::ERR_FAILED` (a veces en una URL que incluye la versión, p. ej. `v4.0.52+1`)

**Causa:** El **service worker** que genera Flutter (`flutter_service_worker.js`) intercepta peticiones. Si alguna fetch falla (red, 404, CORS, etc.), la promesa se rechaza y el navegador muestra esos mensajes.

**Qué comprobar:**

1. **Base href**  
   El build debe hacerse con `--base-href="/"` si la app está en la raíz. Si en el futuro desplegáis en una ruta versionada (p. ej. `/v4.0.53/`), entonces habría que usar `--base-href="/v4.0.53/"`.

2. **Servidor**  
   Que el documento principal y los assets (p. ej. `index.html`, `main.dart.js`, `flutter_service_worker.js`) respondan **200** en la ruta donde se abre la app (sin redirecciones rotas ni 404).

3. **Apache**  
   El script `fix_service_worker_apache.sh` configura el MIME type correcto y `Service-Worker-Allowed: /` para el service worker. Ejecutadlo si el SW no se registra bien.

En muchos casos estos avisos no impiden que la app cargue (la primera carga va por red). Si la app funciona y solo queréis quitar el ruido en consola, podéis desregistrar el SW en DevTools → Application → Service Workers (solo para pruebas).
