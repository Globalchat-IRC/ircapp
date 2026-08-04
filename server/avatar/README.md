# Avatar GIF en el servidor

Para que **todos** vean el avatar animado (GIF) de cada usuario:

1. Sube `upload-gif.php` al servidor **xmlrpc.globalchat.org**, dentro de la carpeta **avatar** (misma donde está `generate-default-avatar.php`).
2. Asegúrate de que exista la carpeta `avatar/avatars/default/` y que el servidor web pueda escribir en ella (permisos).
3. La app ya envía el GIF con el nick al guardar el avatar en Ajustes; este script lo guarda como `avatars/default/{hash}.gif` (mismo hash MD5 del nick que usa la app), así el resto de usuarios cargan esa misma URL y ven el GIF.

**URL del script en producción:** `https://xmlrpc.globalchat.org/avatar/upload-gif.php`
