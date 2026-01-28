# 🔧 Comandos para ejecutar en TOWER

## Diagnóstico rápido

```bash
# Verificar si SSH está corriendo
sudo systemctl status ssh
# o
sudo systemctl status sshd

# Ver en qué puerto está escuchando
sudo netstat -tlnp | grep ssh
# o
sudo ss -tlnp | grep ssh
```

## Si SSH no está corriendo

```bash
# Iniciar servicio SSH
sudo systemctl start ssh
# o
sudo systemctl start sshd

# Habilitar para que inicie automáticamente
sudo systemctl enable ssh
# o
sudo systemctl enable sshd
```

## Configurar puerto 62500

```bash
# 1. Editar configuración SSH
sudo nano /etc/ssh/sshd_config

# 2. Buscar la línea "Port" y cambiarla a:
Port 62500

# 3. Guardar (Ctrl+O, Enter, Ctrl+X)

# 4. Reiniciar servicio SSH
sudo systemctl restart ssh
# o
sudo systemctl restart sshd
```

## Configurar firewall (si es necesario)

### Ubuntu/Debian (UFW):
```bash
sudo ufw allow 62500/tcp
sudo ufw allow 22/tcp
sudo ufw status
```

### CentOS/RHEL (firewalld):
```bash
sudo firewall-cmd --permanent --add-port=62500/tcp
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --reload
```

## Verificar que funciona

```bash
# Desde tu Mac, probar:
ssh -p 62500 root@192.168.1.42
```

## Script automático

Si prefieres, puedes copiar el script `configurar_ssh_en_tower.sh` a tower y ejecutarlo:

```bash
# En tower:
sudo bash configurar_ssh_en_tower.sh
```
