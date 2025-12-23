import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../services/irc_service.dart';
import '../models/channel_info.dart';
import '../models/irc_message.dart';
import '../models/whois_info.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String nick;

  const UserProfileScreen({Key? key, required this.nick}) : super(key: key);

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isLoading = true;
  bool _hasRequestedWhois = false;

  @override
  void initState() {
    super.initState();
    // Solicitar información de whois
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔍 [PROFILE] Requesting whois for: ${widget.nick}');
      ref.read(whoisProvider.notifier).requestWhois(widget.nick);
      _hasRequestedWhois = true;
      
      // Verificar si ya tenemos información en caché
      final cachedInfo = ref.read(whoisProvider)[widget.nick.toLowerCase()];
      if (cachedInfo != null) {
        print('🔍 [PROFILE] Found cached whois info');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // Si no hay información en caché, esperar un poco menos tiempo antes de mostrar error
        // Esto evita que la pantalla se quede en negro por mucho tiempo
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted && _isLoading) {
            final whoisInfo = ref.read(whoisProvider)[widget.nick.toLowerCase()];
            if (whoisInfo == null) {
              print('🔍 [PROFILE] Timeout: No whois info received after 2 seconds, showing error');
              setState(() {
                _isLoading = false;
              });
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final whoisMap = ref.watch(whoisProvider);
    final whoisInfo = whoisMap[widget.nick.toLowerCase()];
    
    // Si tenemos información y aún estamos cargando, actualizar el estado
    if (whoisInfo != null && _isLoading && _hasRequestedWhois) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
    
    // Debug: verificar qué hay en el mapa
    if (whoisInfo == null) {
      print('🔍 [PROFILE] No whois info found for ${widget.nick.toLowerCase()}');
      print('🔍 [PROFILE] Available whois keys: ${whoisMap.keys.toList()}');
    } else {
      print('🔍 [PROFILE] Found whois info for ${widget.nick}: ${whoisInfo.username}@${whoisInfo.host}');
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: appTheme.background,
        appBar: AppBar(
          title: Text('Perfil de ${widget.nick}'),
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.textPrimary,
          automaticallyImplyLeading: true,
          leading: BackButton(
            color: appTheme.textPrimary,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      body: _isLoading
          ? Container(
              color: appTheme.background,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: appTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando información...',
                      style: TextStyle(
                        color: appTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : whoisInfo == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: appTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo obtener información del usuario',
                        style: TextStyle(
                          color: appTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                          });
                          ref.read(whoisProvider.notifier).requestWhois(widget.nick);
                          Future.delayed(const Duration(milliseconds: 1500), () {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.primary,
                          foregroundColor: appTheme.textPrimary,
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con avatar y nombre
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              appTheme.primary,
                              appTheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: appTheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: UserAvatar(
                                nick: widget.nick,
                                size: 80,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.nick,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: appTheme.textPrimary,
                                        ),
                                      ),
                                      if (_isRobotUser(whoisInfo)) ...[
                                        const SizedBox(width: 8),
                                        const Text('🤖', style: TextStyle(fontSize: 24)),
                                      ],
                                    ],
                                  ),
                                  // Indicador de staff / operador de la red
                                  if (whoisInfo.isStaff) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width - 120, // Ajustar al ancho disponible
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurpleAccent.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.amberAccent,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            size: 16,
                                            color: Colors.amberAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Staff GlobalChat${whoisInfo.staffRole != null && whoisInfo.staffRole!.isNotEmpty ? ' · ${whoisInfo.staffRole}' : ''}',
                                              style: TextStyle(
                                                color: appTheme.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (whoisInfo.isAway) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.orange,
                                          width: 1,
                                        ),
                                      ),
                                      child: const Text(
                                        'Ausente',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Cambio de nick (solo si es el propio usuario)
                      Consumer(
                        builder: (context, ref, _) {
                          final currentNick = ref.watch(currentNicknameProvider);
                          final isOwnProfile = currentNick != null && 
                              currentNick.toLowerCase() == widget.nick.toLowerCase();
                          
                          if (!isOwnProfile) {
                            return const SizedBox.shrink();
                          }
                          
                          return Column(
                            children: [
                              _buildSection(
                                appTheme,
                                'Cambiar Nick',
                                [
                                  _ChangeNickWidget(
                                    appTheme: appTheme,
                                    onNickChanged: (newNick) {
                                      final ircService = ref.read(ircServiceProvider);
                                      ircService.changeNick(newNick);
                                      // No actualizar el provider aquí, esperar a que el servidor confirme el cambio
                                      // El listener en chat_screen actualizará el provider cuando el servidor confirme
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Cambiando nick a $newNick...'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                      // Información básica
                      _buildSection(
                        appTheme,
                        'Información Básica',
                        [
                          if (whoisInfo.username != null)
                            _buildInfoRow(
                              appTheme,
                              'Usuario',
                              '${whoisInfo.username}@${whoisInfo.host ?? "N/A"}',
                              Icons.person,
                            ),
                          if (whoisInfo.realName != null)
                            _buildInfoRow(
                              appTheme,
                              'Nombre Real',
                              whoisInfo.realName!,
                              Icons.badge,
                            ),
                          if (whoisInfo.server != null)
                            _buildInfoRow(
                              appTheme,
                              'Servidor',
                              whoisInfo.server!,
                              Icons.dns,
                            ),
                          if (whoisInfo.serverInfo != null)
                            _buildInfoRow(
                              appTheme,
                              'Info del Servidor',
                              whoisInfo.serverInfo!,
                              Icons.info,
                            ),
                          if (whoisInfo.host != null)
                            _buildInfoRow(
                              appTheme,
                              'IP Virtual',
                              whoisInfo.host!,
                              Icons.shield,
                            ),
                          // Información sobre si la conexión del usuario es segura (SSL/TLS)
                          _buildInfoRow(
                            appTheme,
                            'Conexión',
                            whoisInfo.isSecureConnection
                                ? 'Segura (SSL/TLS)'
                                : 'Sin información de SSL',
                            whoisInfo.isSecureConnection
                                ? Icons.lock
                                : Icons.lock_open,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Preferencias de notificación para este usuario
                      _buildSection(
                        appTheme,
                        'Notificaciones',
                        [
                          Consumer(
                            builder: (context, ref, _) {
                              final settings =
                                  ref.watch(notificationSettingsProvider);
                              final isMuted =
                                  settings.isUserMuted(widget.nick);
                              return SwitchListTile(
                                title: const Text(
                                  'Silenciar notificaciones de este usuario',
                                ),
                                subtitle: const Text(
                                  'No sonar cuack ni alertas cuando hable',
                                ),
                                value: isMuted,
                                activeColor: appTheme.accent,
                                onChanged: (_) {
                                  ref
                                      .read(notificationSettingsProvider
                                          .notifier)
                                      .toggleMuteUser(widget.nick);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Estado
                      if (whoisInfo.isAway || whoisInfo.idleSeconds != null || whoisInfo.signonTime != null)
                        _buildSection(
                          appTheme,
                          'Estado',
                          [
                            if (whoisInfo.isAway && whoisInfo.awayMessage != null)
                              _buildInfoRow(
                                appTheme,
                                'Mensaje de Ausencia',
                                whoisInfo.awayMessage!,
                                Icons.airplanemode_active,
                              ),
                            if (whoisInfo.idleSeconds != null)
                              _buildInfoRow(
                                appTheme,
                                'Tiempo Inactivo',
                                _formatDuration(whoisInfo.idleSeconds!),
                                Icons.timer,
                              ),
                            if (whoisInfo.signonTime != null)
                              _buildInfoRow(
                                appTheme,
                                'Conectado desde',
                                _formatDateTime(whoisInfo.signonTime!),
                                Icons.access_time,
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // Canales
                      if (whoisInfo.channels.isNotEmpty)
                        _buildSection(
                          appTheme,
                          'Canales (${whoisInfo.channels.length})',
                          [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: whoisInfo.channels.map((channel) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appTheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: appTheme.primary.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    channel,
                                    style: TextStyle(
                                      color: appTheme.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // Botón para abrir mensaje privado
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (!mounted) return;
                            
                            // Hacer pop con el nick como resultado para que el chat_screen lo maneje
                            Navigator.of(context).pop({'openPrivateMessage': widget.nick});
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Mensaje Privado'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appTheme.primary,
                            foregroundColor: appTheme.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Botón para gestionar IP virtual / vHost mediante el bot ipvirtual
                      if (whoisInfo.host != null)
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final ircService = ref.read(ircServiceProvider);
                              // Enviar un mensaje de ayuda al bot ipvirtual para gestionar la IP virtual
                              ircService.sendServiceMessage('ipvirtual', 'HELP');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Se ha enviado una petición de ayuda al bot ipvirtual para cambiar tu IP virtual.',
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.shield),
                            label: const Text('Cambiar IP Virtual'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appTheme.primary,
                              foregroundColor: appTheme.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildSection(AppTheme appTheme, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appTheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: appTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(AppTheme appTheme, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: appTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: appTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds segundos';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes minutos';
    } else if (seconds < 86400) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours horas y $minutes minutos';
    } else {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      return '$days días y $hours horas';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Hoy a las ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ayer a las ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // Detectar si un usuario es un robot basándose en su información de whois
  bool _isRobotUser(WhoisInfo? whoisInfo) {
    if (whoisInfo == null) {
      // Si no hay información de whois, solo verificar el nick
      return widget.nick.toLowerCase().contains('robot');
    }
    
    final nick = widget.nick.toLowerCase();
    final username = whoisInfo.username?.toLowerCase() ?? '';
    final host = whoisInfo.host?.toLowerCase() ?? '';
    final realName = whoisInfo.realName?.toLowerCase() ?? '';
    final server = whoisInfo.server?.toLowerCase() ?? '';
    
    return nick.contains('robot') ||
           username.contains('robot') ||
           host.contains('robot') ||
           realName.contains('robot') ||
           server.contains('robot');
  }
}

// Widget para cambiar el nick
class _ChangeNickWidget extends ConsumerStatefulWidget {
  final dynamic appTheme;
  final Function(String) onNickChanged;

  const _ChangeNickWidget({
    required this.appTheme,
    required this.onNickChanged,
  });

  @override
  ConsumerState<_ChangeNickWidget> createState() => _ChangeNickWidgetState();
}

class _ChangeNickWidgetState extends ConsumerState<_ChangeNickWidget> {
  late TextEditingController _nickController;
  bool _isEditing = false;
  String? _lastKnownNick;

  @override
  void initState() {
    super.initState();
    final currentNick = ref.read(currentNicknameProvider) ?? 'Usuario';
    _lastKnownNick = currentNick;
    _nickController = TextEditingController(text: currentNick);
  }

  @override
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en el provider para actualizar el nick mostrado
    final currentNickFromProvider = ref.watch(currentNicknameProvider) ?? 'Usuario';
    print('🔄 [ChangeNickWidget] build() - currentNickFromProvider: "$currentNickFromProvider", _lastKnownNick: "$_lastKnownNick", _isEditing: $_isEditing');
    
    // Actualizar el controlador si el nick cambió desde el provider
    if (currentNickFromProvider != _lastKnownNick && !_isEditing) {
      print('🔄 [ChangeNickWidget] ✅ Actualizando controlador de "$_lastKnownNick" a "$currentNickFromProvider"');
      _lastKnownNick = currentNickFromProvider;
      _nickController.text = currentNickFromProvider;
    } else if (currentNickFromProvider != _lastKnownNick && _isEditing) {
      print('🔄 [ChangeNickWidget] ⚠️  Nick cambió pero estamos editando, no actualizamos el controlador');
    }
    
    if (!_isEditing) {
      return ListTile(
        leading: Icon(Icons.edit, color: widget.appTheme.primary),
        title: const Text('Nick actual'),
        subtitle: Text(
          currentNickFromProvider,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.appTheme.textPrimary,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: widget.appTheme.primary),
          onPressed: () {
            setState(() {
              _isEditing = true;
            });
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nickController,
            style: TextStyle(color: widget.appTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nuevo nick',
              hintText: 'Escribe el nuevo nick',
              prefixIcon: Icon(Icons.person, color: widget.appTheme.primary),
              labelStyle: TextStyle(color: widget.appTheme.primary),
              filled: true,
              fillColor: widget.appTheme.surface.withOpacity(0.9),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.appTheme.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.6), width: 1.5),
              ),
            ),
            onSubmitted: (value) {
              final newNick = value.trim();
              if (newNick.isNotEmpty && newNick != currentNickFromProvider) {
                widget.onNickChanged(newNick);
                setState(() {
                  _isEditing = false;
                });
              } else {
                setState(() {
                  _isEditing = false;
                });
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _nickController.text = currentNickFromProvider;
                  });
                },
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final newNick = _nickController.text.trim();
                  if (newNick.isNotEmpty && newNick != currentNickFromProvider) {
                    widget.onNickChanged(newNick);
                    setState(() {
                      _isEditing = false;
                    });
                  } else {
                    setState(() {
                      _isEditing = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.appTheme.primary,
                  foregroundColor: widget.appTheme.textPrimary,
                ),
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

