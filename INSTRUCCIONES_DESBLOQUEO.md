# 🔓 Cómo Desbloquear SSH en Tower

## ¿Quién te bloquea?

El servidor SSH en **tower** está bloqueando tu conexión. Las causas más comunes son:

1. **fail2ban** - Bloquea IPs después de múltiples intentos fallidos
2. **MaxStartups** - Límite de conexiones simultáneas alcanzado
3. **Firewall (iptables/ufw)** - Regla que bloquea tu IP
4. **hosts.deny** - Bloqueo manual en `/etc/hosts.deny`
5. **SSH sobrecargado** - Demasiadas conexiones activas

## Tu IP Mac: `192.168.1.48`

## Solución Rápida

### Opción 1: Script Automático (Recomendado)

1. **Copia el script a tower** (si tienes acceso por otro método):
   ```bash
   # Desde tu Mac, si tienes acceso por otro puerto:
   scp -P 22 /Users/fnaveira/mobile/irc_app/desbloquear_ssh_tower.sh root@192.168.1.42:/tmp/
   ```

2. **Ejecuta en tower**:
   ```bash
   sudo bash /tmp/desbloquear_ssh_tower.sh
   ```

### Opción 2: Comandos Manuales

**Conecta a tower por otro método** (acceso físico, otro puerto SSH, etc.) y ejecuta:

```bash
# 1. Desbloquear en fail2ban
sudo fail2ban-client set sshd unbanip 192.168.1.48

# 2. Verificar y limpiar hosts.deny
sudo grep 192.168.1.48 /etc/hosts.deny
sudo sed -i '/192.168.1.48/d' /etc/hosts.deny

# 3. Verificar iptables
sudo iptables -L INPUT -n | grep 192.168.1.48
sudo iptables -D INPUT -s 192.168.1.48 -j DROP  # Si hay bloqueo

# 4. Reiniciar SSH
sudo systemctl restart ssh
# o
sudo systemctl restart sshd

# 5. Verificar que funciona
sudo systemctl status ssh
```

### Opción 3: Esperar (Bloqueo Temporal)

Si el bloqueo es temporal (fail2ban), suele durar **10-30 minutos**. Espera y vuelve a intentar.

## Prevenir Bloqueos Futuros

Configura SSH en tower para evitar bloqueos:

```bash
# En tower:
sudo nano /etc/ssh/sshd_config
```

Agrega/modifica estas líneas:

```
MaxStartups 20:50:100
ClientAliveInterval 60
ClientAliveCountMax 5
TCPKeepAlive yes
```

Luego reinicia SSH:

```bash
sudo systemctl restart ssh
```

## Verificar Estado

Para verificar si estás desbloqueado, desde tu Mac:

```bash
ssh -p 62500 root@192.168.1.42 "echo 'OK'"
```

Si funciona, puedes continuar con la transferencia.
