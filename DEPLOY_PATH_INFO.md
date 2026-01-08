# 📍 Información sobre la Ruta de Despliegue

## Ruta por Defecto

El script `deploy_to_ceres.sh` despliega la aplicación en:

**`/var/www/irc_app`**

## ¿Dónde se despliega?

### Opción 1: `/var/www/irc_app` (Por defecto)
- **Ventaja**: Estándar para aplicaciones web en Linux
- **Permisos**: Requiere `sudo` para cambiar ownership a `www-data`
- **Uso**: Recomendado para producción

### Opción 2: `/var/www/html/irc_app`
- Si ya tienes un sitio web en `/var/www/html`
- Útil si quieres mantener todo junto

### Opción 3: `/home/usuario/irc_app`
- Si no tienes permisos sudo
- Menos seguro, pero más fácil de gestionar

### Opción 4: Ruta personalizada
- Cualquier ruta que prefieras en ceres

## Cómo Cambiar la Ruta

### Opción A: Pasar como parámetro al script

```bash
./deploy_to_ceres.sh tu_usuario /ruta/personalizada/irc_app
```

### Opción B: Editar el script

Editar línea 24 en `deploy_to_ceres.sh`:
```bash
DEST_PATH=${2:-"/tu/ruta/personalizada"}
```

## Configuración de Nginx

**IMPORTANTE**: Si cambias la ruta, también debes actualizar la configuración de Nginx:

```nginx
server {
    ...
    root /tu/ruta/personalizada/irc_app;  # ← Cambiar aquí
    ...
}
```

## Verificar Ruta Actual en Ceres

Para ver qué rutas están disponibles en ceres:

```bash
ssh usuario@ceres.globalchat.org "ls -la /var/www/"
```

## Recomendación

Usa `/var/www/irc_app` si:
- Tienes acceso sudo
- Es un servidor de producción
- Quieres seguir estándares Linux

Usa otra ruta si:
- No tienes permisos sudo
- Ya tienes una estructura específica
- Es para testing/desarrollo




