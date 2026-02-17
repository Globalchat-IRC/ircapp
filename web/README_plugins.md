# Plugins del webchat (estilo mlite2/Kiwi)

## Plugins portados de mlite2 (incluidos en este proyecto)

- **plugins/plugin-hide-console.js**: Silencia `console.log`/`info`/`warn` en producción; deja pasar solo errores críticos.
- **plugins/plugin-text-replacer.js**: Reemplaza el mensaje "Error de inicio de sesión..." por uno más amigable si aparece en el DOM.

Puedes cargarlos añadiendo en `plugins.json` o con `?plugin=plugins/plugin-hide-console.js`.

Los plugins son scripts JS o hojas CSS que se cargan al abrir la app. Misma idea que en mlite2.

## Cómo añadir plugins

### 1. Lista en el servidor (para todos los usuarios)

Edita `plugins.json` en este directorio (o en el servidor desplegado). Formato:

```json
[
  { "name": "mi-plugin", "url": "https://ejemplo.com/plugin.js" },
  { "name": "tema", "url": "https://ejemplo.com/theme.css" }
]
```

- **name**: identificador (sin espacios).
- **url**: URL absoluta del `.js` o `.css`, o ruta relativa (ej. `plugins/mi-plugin.js`).

Los `.js` se inyectan como `<script src="...">`. Los `.css` como `<link rel="stylesheet">`.  
Otras URLs (p. ej. `.html`) se descargan y se ejecutan los `<script>` que contengan.

### 2. Desde la URL (solo esta sesión)

Puedes cargar plugins sin tocar el servidor añadiendo parámetros a la URL:

- Un plugin: `?plugin=https://ejemplo.com/script.js`
- Varios: `?plugins=https://a.com/1.js,https://b.com/2.css`

Se cargan antes que los de `plugins.json`.

## API para plugins

La app expone `window.ircApp`:

- `plugins`: array de `{ name, url }` que se van a cargar.
- `pluginsLoaded`: array de nombres de plugins ya cargados.

Los plugins pueden usar el DOM y esta API para integrarse con el chat.
