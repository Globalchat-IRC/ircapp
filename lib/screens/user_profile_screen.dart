import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../widgets/user_avatar.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String nick;

  const UserProfileScreen({Key? key, required this.nick}) : super(key: key);

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Solicitar información de whois
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔍 [PROFILE] Requesting whois for: ${widget.nick}');
      ref.read(whoisProvider.notifier).requestWhois(widget.nick);
      // Esperar más tiempo para que llegue la información (el servidor puede tardar)
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          final whoisInfo = ref.read(whoisProvider)[widget.nick.toLowerCase()];
          print('🔍 [PROFILE] After delay, whoisInfo: ${whoisInfo != null ? "found" : "null"}');
          setState(() {
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final whoisMap = ref.watch(whoisProvider);
    final whoisInfo = whoisMap[widget.nick.toLowerCase()];
    
    // Debug: verificar qué hay en el mapa
    if (whoisInfo == null) {
      print('🔍 [PROFILE] No whois info found for ${widget.nick.toLowerCase()}');
      print('🔍 [PROFILE] Available whois keys: ${whoisMap.keys.toList()}');
    } else {
      print('🔍 [PROFILE] Found whois info for ${widget.nick}: ${whoisInfo.username}@${whoisInfo.host}');
    }

    return Scaffold(
      backgroundColor: appTheme.background,
      appBar: AppBar(
        title: Text('Perfil de ${widget.nick}'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: appTheme.primary,
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
                                  Text(
                                    widget.nick,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: appTheme.textPrimary,
                                    ),
                                  ),
                                  // Indicador de staff / operador de la red
                                  if (whoisInfo.isStaff) ...[
                                    const SizedBox(height: 8),
                                    Container(
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
                                          Text(
                                            'Staff GlobalChat',
                                            style: TextStyle(
                                              color: appTheme.textPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (whoisInfo.staffRole != null &&
                                              whoisInfo.staffRole!.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '· ${whoisInfo.staffRole}',
                                              style: TextStyle(
                                                color: appTheme.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
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
                    ],
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
}

