import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/radio_provider.dart';
import '../models/app_theme.dart';
import '../models/radio_station.dart';
import '../widgets/user_avatar.dart';
import '../widgets/qualia_radio_request_dialog.dart';
import '../models/whois_info.dart';
import '../models/user_role.dart';
import '../providers/video_provider.dart';
import '../config/debug_config.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String nick;

  const UserProfileScreen({super.key, required this.nick});

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
      // debugLog('🔍 [PROFILE] Requesting whois for: ${widget.nick}');
      ref.read(whoisProvider.notifier).requestWhois(widget.nick);
      _hasRequestedWhois = true;
      
      // Verificar si ya tenemos información en caché
      final cachedInfo = ref.read(whoisProvider)[widget.nick.toLowerCase()];
      if (cachedInfo != null) {
        // debugLog('🔍 [PROFILE] Found cached whois info');
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
              // debugLog('🔍 [PROFILE] Timeout: No whois info received after 2 seconds, showing error');
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
      // debugLog('🔍 [PROFILE] No whois info found for ${widget.nick.toLowerCase()}');
      // debugLog('🔍 [PROFILE] Available whois keys: ${whoisMap.keys.toList()}');
    } else {
      // debugLog('🔍 [PROFILE] Found whois info for ${widget.nick}: ${whoisInfo.username}@${whoisInfo.host}');
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
                              color: appTheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            UserAvatar(
                              nick: widget.nick,
                              size: 80,
                              fallbackIcon: _isRobotUser(whoisInfo) ? '🤖' : null,
                              isRobot: _isRobotUser(whoisInfo),
                              gradient: _isRobotUser(whoisInfo)
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: [
                                        _getUserColor(widget.nick.hashCode),
                                        _getUserColor(widget.nick.hashCode).withValues(alpha: 0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              border: _isRobotUser(whoisInfo)
                                  ? Border.all(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                      width: 2,
                                    )
                                  : null,
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
                                  // Etiqueta de Robot GlobalChat
                                  if (_isRobotUser(whoisInfo)) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width - 120,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFFFD700).withValues(alpha: 0.3),
                                            const Color(0xFFFFA500).withValues(alpha: 0.3),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.smart_toy,
                                            size: 16,
                                            color: Color(0xFFFFD700),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Robot GlobalChat',
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
                                  // Etiqueta de Dueño del Canal
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final channels = ref.watch(channelsProvider);
                                      
                                      // Buscar todos los canales donde el usuario es dueño
                                      final ownerChannels = <String>[];
                                      for (var entry in channels.entries) {
                                        final channelName = entry.key;
                                        final channel = entry.value;
                                        final userMode = channel.getUserMode(widget.nick);
                                        
                                        if (userMode == '~' || userMode == '&') {
                                          ownerChannels.add(channelName);
                                        }
                                      }
                                      
                                      if (ownerChannels.isNotEmpty) {
                                        // Usar colores del tema adaptados para dueño
                                        // Color naranja/rojo adaptado al tema
                                        final ownerColor = appTheme.primary.withValues(alpha: 0.9).computeLuminance() > 0.5
                                            ? const Color(0xFFFF5722) // Naranja/rojo para temas claros
                                            : appTheme.accent.withValues(alpha: 0.8); // Adaptado para temas oscuros
                                        
                                        return Column(
                                          children: [
                                            const SizedBox(height: 8),
                                            Container(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context).size.width - 120,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: ownerColor.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: ownerColor.withValues(alpha: 0.8),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: ownerColor.withValues(alpha: 0.3),
                                                    blurRadius: 4,
                                                    spreadRadius: 0.5,
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.admin_panel_settings,
                                                    size: 16,
                                                    color: ownerColor,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          ownerChannels.length == 1
                                                              ? 'Dueño del canal'
                                                              : 'Dueño de ${ownerChannels.length} canales',
                                                          style: TextStyle(
                                                            color: ownerColor,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            shadows: [
                                                              Shadow(
                                                                color: appTheme.background.withValues(alpha: 0.8),
                                                                blurRadius: 2,
                                                                offset: const Offset(0, 0.5),
                                                              ),
                                                            ],
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                        if (ownerChannels.length <= 3) ...[
                                                          const SizedBox(height: 4),
                                                          Wrap(
                                                            spacing: 4,
                                                            runSpacing: 2,
                                                            children: ownerChannels.map((channel) {
                                                              return Container(
                                                                padding: const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                                decoration: BoxDecoration(
                                                                  color: ownerColor.withValues(alpha: 0.2),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                  border: Border.all(
                                                                    color: ownerColor.withValues(alpha: 0.5),
                                                                    width: 1,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  channel,
                                                                  style: TextStyle(
                                                                    color: ownerColor,
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              );
                                                            }).toList(),
                                                          ),
                                                        ] else ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            '${ownerChannels.take(2).join(', ')}...',
                                                            style: TextStyle(
                                                              color: ownerColor.withValues(alpha: 0.9),
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
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
                                        color: Colors.deepPurpleAccent.withValues(alpha: 0.25),
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
                                        color: Colors.orange.withValues(alpha: 0.3),
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
                          
                          debugLog('🔍 [PERFIL] Verificando perfil - currentNick: $currentNick, widget.nick: ${widget.nick}, isOwnProfile: $isOwnProfile');
                          
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
                      // Petición de canciones Qualia Radio (cualquier usuario)
                      Consumer(
                        builder: (context, ref, _) {
                          return Column(
                            children: [
                              _buildSection(
                                appTheme,
                                'Qualia Radio',
                                [
                                  QualiaRadioRequestProfileCard(
                                    onTap: () => showQualiaRadioRequestDialog(
                                      context,
                                      ref,
                                      channel: '#QualiaRadio',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                      // Compartir canción en el canal (solo si es el propio usuario)
                      Consumer(
                        builder: (context, ref, _) {
                          final currentNick = ref.watch(currentNicknameProvider);
                          final isOwnProfile = currentNick != null && 
                              currentNick.toLowerCase() == widget.nick.toLowerCase();
                          
                          debugLog('🎵 [PERFIL] Verificando sección Radio - isOwnProfile: $isOwnProfile');
                          
                          if (!isOwnProfile) {
                            return const SizedBox.shrink();
                          }
                          
                          final radioState = ref.watch(radioProvider);
                          final isPlaying = radioState.isPlaying;
                          final activeStation = radioState.activeStation;
                          
                          // Debug logs
                          debugLog('🎵 [PERFIL] Radio state - isPlaying: $isPlaying, activeStation: ${activeStation?.name ?? "null"}');
                          
                          // Mostrar siempre la sección de radio, pero con diferentes contenidos según el estado
                          return Column(
                            children: [
                              _buildSection(
                                appTheme,
                                'Radio',
                                [
                                  if (!isPlaying || activeStation == null)
                                    _buildRadioOffMessage(appTheme)
                                  else
                                    _buildShareSongButton(
                                      context,
                                      appTheme,
                                      ref,
                                      activeStation,
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
                      // Perfil personal (editable si es propio, solo lectura si es de otro usuario)
                      Consumer(
                        builder: (context, ref, _) {
                          final currentNick = ref.watch(currentNicknameProvider);
                          final isOwnProfile = currentNick != null && 
                              currentNick.toLowerCase() == widget.nick.toLowerCase();
                          
                          return Column(
                            children: [
                              if (isOwnProfile)
                                _buildPersonalProfileSection(context, appTheme, ref)
                              else
                                _buildPersonalProfileViewSection(context, appTheme, ref),
                              if (isOwnProfile) ...[
                                const SizedBox(height: 16),
                                _buildAwaySection(context, appTheme, ref),
                                const SizedBox(height: 16),
                              ],
                            ],
                          );
                        },
                      ),
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
                                activeThumbColor: appTheme.accent,
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
                                    color: appTheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: appTheme.primary.withValues(alpha: 0.4),
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
                              // Enviar un mensaje de ayuda al bot de IP virtual
                              // Intentar primero con "HostServ" (nombre estándar en IRC) y luego con "ipvirtual"
                              // debugLog('🌐 [UserProfile] Intentando con HostServ (estándar IRC)...');
                              ircService.sendServiceMessage('HostServ', 'HELP');
                              
                              // También intentar con ipvirtual por si el servidor usa ese nombre
                              Future.delayed(const Duration(milliseconds: 500), () {
                                // debugLog('🌐 [UserProfile] También intentando con ipvirtual...');
                                ircService.sendServiceMessage('ipvirtual', 'HELP');
                              });
                              
                              // debugLog('🌐 [UserProfile] Comandos enviados:');
                              // debugLog('🌐 [UserProfile]   - PRIVMSG HostServ :HELP');
                              // debugLog('🌐 [UserProfile]   - PRIVMSG ipvirtual :HELP');
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

  Widget _buildAwaySection(BuildContext context, AppTheme appTheme, WidgetRef ref) {
    final awayStatus = ref.watch(userAwayStatusProvider);
    final ircService = ref.read(ircServiceProvider);
    
    return _buildSection(
      appTheme,
      'Estado de Ausencia',
      [
        SwitchListTile(
          title: const Text('Estoy ausente'),
          subtitle: Text(
            awayStatus.isAway 
                ? 'Mensaje: ${awayStatus.awayMessage ?? "Sin mensaje"}'
                : 'Activa para indicar que estás ausente',
          ),
          value: awayStatus.isAway,
          activeThumbColor: appTheme.primary,
          onChanged: (value) {
            if (value) {
              // Activar away con mensaje actual o por defecto
              final currentMessage = awayStatus.awayMessage;
              final defaultMessage = ircService.getDefaultAwayMessage();
              final messageToUse = currentMessage ?? defaultMessage;
              ircService.sendAway(messageToUse);
            } else {
              // Desactivar away
              ircService.sendBack();
            }
          },
        ),
        if (awayStatus.isAway) ...[
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.edit, color: appTheme.primary),
            title: const Text('Cambiar mensaje de away'),
            subtitle: Text(
              awayStatus.awayMessage ?? 'Sin mensaje',
              style: TextStyle(color: appTheme.textSecondary),
            ),
            trailing: Icon(Icons.chevron_right, color: appTheme.textSecondary),
            onTap: () => _showAwayMessageDialog(context, appTheme, ref, awayStatus.awayMessage),
          ),
        ],
      ],
    );
  }

  void _showAwayMessageDialog(BuildContext context, AppTheme appTheme, WidgetRef ref, String? currentMessage) {
    final messageController = TextEditingController(text: currentMessage ?? '');
    final ircService = ref.read(ircServiceProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('Mensaje de Ausencia', style: TextStyle(color: appTheme.textPrimary)),
        content: TextField(
          controller: messageController,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: appTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ej: Estoy ocupado, volveré pronto',
            hintStyle: TextStyle(color: appTheme.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: appTheme.background,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final message = messageController.text.trim();
              ircService.sendAway(message.isEmpty ? null : message);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message.isEmpty ? 'Away activado sin mensaje' : 'Mensaje de away actualizado')),
              );
            },
            child: Text('Guardar', style: TextStyle(color: appTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalProfileSection(BuildContext context, AppTheme appTheme, WidgetRef ref) {
    return FutureBuilder<UserProfile?>(
      future: ref.read(videoDatabaseProvider).getUserProfile(widget.nick),
      builder: (context, snapshot) {
        // Si está cargando, mostrar un indicador
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildSection(
            appTheme,
            'Perfil Personal',
            [
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }
        
        // Si no hay datos o el perfil no existe, crear uno por defecto
        UserProfile profile;
        if (!snapshot.hasData || snapshot.data == null) {
          profile = UserProfile(
            nick: widget.nick,
            role: UserRole.user,
            reputation: 50,
            hasAcceptedVideoTerms: false,
            emailVerified: false,
            phoneVerified: false,
            idVerified: false,
            gender: null,
            age: null,
            interests: [],
          );
          // Guardar el perfil por defecto en segundo plano
          Future.microtask(() async {
            final db = ref.read(videoDatabaseProvider);
            await db.saveUserProfile(profile);
          });
        } else {
          profile = snapshot.data!;
        }
        
        return _buildSection(
          appTheme,
          'Perfil Personal',
          [
            _PersonalProfileEditor(
              appTheme: appTheme,
              profile: profile,
              onProfileUpdated: (updatedProfile) async {
                final db = ref.read(videoDatabaseProvider);
                await db.saveUserProfile(updatedProfile);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil actualizado')),
                );
                // Forzar actualización del widget
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonalProfileViewSection(BuildContext context, AppTheme appTheme, WidgetRef ref) {
    return FutureBuilder<UserProfile?>(
      future: ref.read(videoDatabaseProvider).getUserProfile(widget.nick),
      builder: (context, snapshot) {
        // Si está cargando, no mostrar nada (o mostrar un indicador sutil)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        // Si no hay datos, no mostrar la sección
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        
        final profile = snapshot.data!;
        final hasPersonalInfo = profile.gender != null || profile.age != null || (profile.interests.isNotEmpty);
        
        // Solo mostrar la sección si hay información personal
        if (!hasPersonalInfo) {
          return const SizedBox.shrink();
        }
        
        return _buildSection(
          appTheme,
          'Perfil Personal',
          [
            if (profile.gender != null)
              _buildInfoRow(
                appTheme,
                'Sexo',
                profile.gender == 'M' ? 'Masculino' : (profile.gender == 'F' ? 'Femenino' : 'Otro'),
                Icons.person,
              ),
            if (profile.age != null)
              _buildInfoRow(
                appTheme,
                'Edad',
                '${profile.age} años',
                Icons.cake,
              ),
            if (profile.interests.isNotEmpty)
              _buildInfoRow(
                appTheme,
                'Intereses',
                profile.interests.join(', '),
                Icons.favorite,
              ),
          ],
        );
      },
    );
  }

  Widget _buildSection(AppTheme appTheme, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appTheme.primary.withValues(alpha: 0.2),
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

  // Mensaje cuando la radio está apagada
  Widget _buildRadioOffMessage(AppTheme appTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appTheme.textSecondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.radio,
            color: appTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Radio apagada',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: appTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enciende la radio para compartir la canción que estás escuchando',
                  style: TextStyle(
                    fontSize: 12,
                    color: appTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mapear estación de radio al canal correspondiente
  String? _getChannelForStation(String stationName) {
    final name = stationName.toLowerCase();
    if (name == 'qualia_radio' || name == 'qualia radio') {
      return '#QualiaRadio';
    }
    return null;
  }

  // Construir el botón para compartir canción
  Widget _buildShareSongButton(
    BuildContext context,
    AppTheme appTheme,
    WidgetRef ref,
    RadioStation activeStation,
  ) {
    // Obtener la canción actual (sin espacios y verificando que no esté vacía)
    final currentSongRaw = activeStation.currentArtistSong?.trim();
    final currentSong = (currentSongRaw != null && currentSongRaw.isNotEmpty && currentSongRaw != 'Sin información')
        ? currentSongRaw
        : 'Sin información';
    final stationName = activeStation.name;
    
    // Obtener el canal actual donde está el usuario
    final currentChannel = ref.read(currentChannelProvider);
    
    // Mapear estación al canal sugerido (para mostrar en el mensaje)
    final suggestedChannel = _getChannelForStation(stationName);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appTheme.primary.withValues(alpha: 0.1),
            appTheme.accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appTheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note,
                color: appTheme.accent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reproduciendo',
                      style: TextStyle(
                        fontSize: 12,
                        color: appTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentSong,
                      style: TextStyle(
                        fontSize: 16,
                        color: appTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En $stationName',
                      style: TextStyle(
                        fontSize: 12,
                        color: appTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: currentChannel != null && currentChannel.isNotEmpty
                  ? () => _sendSongToChannel(context, ref, currentChannel, stationName, currentSong, suggestedChannel, appTheme)
                  : null,
              icon: const Icon(Icons.send, size: 18),
              label: Text(
                currentChannel != null && currentChannel.isNotEmpty
                    ? 'Enviar canción a $currentChannel'
                    : 'Debes estar en un canal',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enviar canción al canal actual
  Future<void> _sendSongToChannel(
    BuildContext context,
    WidgetRef ref,
    String currentChannel,
    String stationName,
    String currentSong,
    String? suggestedChannel,
    AppTheme appTheme,
  ) async {
    try {
      final ircService = ref.read(ircServiceProvider);
      
      // Forzar actualización de la canción actual antes de compartir
      await ref.read(radioProvider.notifier).refreshNowPlaying();
      // Esperar un poco para que se actualice el estado
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Obtener la canción actualizada
      final updatedRadioState = ref.read(radioProvider);
      final updatedStation = updatedRadioState.activeStation;
      final updatedSong = updatedStation?.currentArtistSong?.trim();
      final finalSong = (updatedSong != null && updatedSong.isNotEmpty && updatedSong != 'Sin información')
          ? updatedSong
          : (currentSong != 'Sin información' && currentSong.isNotEmpty ? currentSong : 'Sin información');
      
      // Crear mensaje moderno y atractivo
      final message = '🎵 🎶 ¡Escuchando ahora en $stationName! 🎶 🎵\n'
          '▶️ $finalSong\n'
          '📻 ${suggestedChannel != null ? '¡Únete a escuchar en $suggestedChannel! 🎧' : '🎧'}';
      
      // Enviar mensaje al canal actual
      ircService.sendMessage(currentChannel, message);
      
      // Mostrar confirmación
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Canción enviada a $currentChannel',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: appTheme.accent,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      
      // Cerrar el perfil después de enviar
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar canción: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Detectar si un usuario es un robot basándose en su información de whois
  bool _isRobotUser(WhoisInfo? whoisInfo) {
    final nick = widget.nick.toLowerCase();
    
    // Verificar si el nick contiene indicadores MUY específicos de bot
    // Ser MUY restrictivo: solo detectar si el nick TERMINA en "bot" o EMPIEZA con "radio"
    // NO usar "contains" porque puede dar falsos positivos
    final isBotByNick = nick.endsWith('bot') ||
                        nick.startsWith('radio') ||
                        nick == 'robot' ||
                        nick == 'bot';
    
    if (whoisInfo == null) {
      // Si no hay información de whois, solo verificar el nick (muy restrictivo)
      return isBotByNick;
    }
    
    final username = whoisInfo.username?.toLowerCase() ?? '';
    final host = whoisInfo.host?.toLowerCase() ?? '';
    final realName = whoisInfo.realName?.toLowerCase() ?? '';
    final server = whoisInfo.server?.toLowerCase() ?? '';
    
    // Verificar host de forma MUY restrictiva (solo robots de GlobalChat)
    // SOLO detectar si el host es EXACTAMENTE de robots de GlobalChat
    final isBotByHost = host == 'robot.globalchat.org' ||
                        host.endsWith('.robot.globalchat.org') ||
                        (host.startsWith('robot.') && host.contains('globalchat.org') && !host.contains('netadmin') && !host.contains('admin'));
    
    // Verificar otros campos de forma MUY restrictiva
    // Solo si AMBOS campos contienen "robot" Y "globalchat"
    final isBotByOther = (username.contains('robot') && username.contains('globalchat')) ||
                         (realName.contains('robot') && realName.contains('globalchat')) ||
                         (server.contains('robot') && server.contains('globalchat'));
    
    return isBotByNick || isBotByHost || isBotByOther;
  }

  // Misma paleta que la lista de usuarios para avatar consistente
  Color _getUserColor(int hash) {
    final colors = [
      const Color(0xFFFFA500),
      const Color(0xFFFFD700),
      const Color(0xFFFF8C00),
      const Color(0xFFFFE4B5),
      Colors.orange,
      Colors.amber,
      const Color(0xFFFFB347),
      const Color(0xFFFFCC00),
      Colors.deepOrange,
      const Color(0xFFFFE135),
    ];
    return colors[hash.abs() % colors.length];
  }
}

// Widget para editar perfil personal
class _PersonalProfileEditor extends StatefulWidget {
  final AppTheme appTheme;
  final UserProfile profile;
  final Function(UserProfile) onProfileUpdated;

  const _PersonalProfileEditor({
    required this.appTheme,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<_PersonalProfileEditor> createState() => _PersonalProfileEditorState();
}

class _PersonalProfileEditorState extends State<_PersonalProfileEditor> {
  late String? _selectedGender;
  late TextEditingController _ageController;
  late TextEditingController _interestsController;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.profile.gender;
    _ageController = TextEditingController(
      text: widget.profile.age?.toString() ?? '',
    );
    _interestsController = TextEditingController(
      text: widget.profile.interests.join(', '),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final age = _ageController.text.trim().isEmpty 
        ? null 
        : int.tryParse(_ageController.text.trim());
    
    final interests = _interestsController.text
        .split(',')
        .map((i) => i.trim())
        .where((i) => i.isNotEmpty)
        .toList();
    
    final updatedProfile = widget.profile.copyWith(
      gender: _selectedGender,
      age: age,
      interests: interests,
    );
    
    widget.onProfileUpdated(updatedProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sexo
        Text(
          'Sexo',
          style: TextStyle(
            color: widget.appTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _GenderChip(
              label: 'Masculino',
              value: 'M',
              selected: _selectedGender == 'M',
              onSelected: (selected) {
                setState(() {
                  _selectedGender = selected ? 'M' : null;
                });
              },
              appTheme: widget.appTheme,
            ),
            _GenderChip(
              label: 'Femenino',
              value: 'F',
              selected: _selectedGender == 'F',
              onSelected: (selected) {
                setState(() {
                  _selectedGender = selected ? 'F' : null;
                });
              },
              appTheme: widget.appTheme,
            ),
            _GenderChip(
              label: 'Otro',
              value: 'O',
              selected: _selectedGender == 'O',
              onSelected: (selected) {
                setState(() {
                  _selectedGender = selected ? 'O' : null;
                });
              },
              appTheme: widget.appTheme,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Edad
        Text(
          'Edad',
          style: TextStyle(
            color: widget.appTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ej: 25',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.appTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: widget.appTheme.background,
          ),
          style: TextStyle(color: widget.appTheme.textPrimary),
        ),
        const SizedBox(height: 16),
        // Intereses
        Text(
          'Intereses',
          style: TextStyle(
            color: widget.appTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _interestsController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ej: Música, Deportes, Tecnología (separados por comas)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.appTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: widget.appTheme.background,
          ),
          style: TextStyle(color: widget.appTheme.textPrimary),
        ),
        const SizedBox(height: 24),
        // Botón de guardar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _saveProfile();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Perfil guardado correctamente'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.appTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save, size: 20),
                SizedBox(width: 8),
                Text(
                  'Guardar Perfil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Widget para chips de género
class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Function(bool) onSelected;
  final AppTheme appTheme;

  const _GenderChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: appTheme.primary.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: selected ? appTheme.primary : appTheme.textPrimary,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
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
    // debugLog('🔄 [ChangeNickWidget] build() - currentNickFromProvider: "$currentNickFromProvider", _lastKnownNick: "$_lastKnownNick", _isEditing: $_isEditing');
    
    // Actualizar el controlador si el nick cambió desde el provider
    if (currentNickFromProvider != _lastKnownNick && !_isEditing) {
      // debugLog('🔄 [ChangeNickWidget] ✅ Actualizando controlador de "$_lastKnownNick" a "$currentNickFromProvider"');
      _lastKnownNick = currentNickFromProvider;
      _nickController.text = currentNickFromProvider;
    } else if (currentNickFromProvider != _lastKnownNick && _isEditing) {
      // debugLog('🔄 [ChangeNickWidget] ⚠️  Nick cambió pero estamos editando, no actualizamos el controlador');
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

