import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/whois_info.dart';
import '../models/app_theme.dart';
import '../providers/theme_provider.dart';
import '../config/debug_config.dart';

/// Diálogo modal para mostrar información WHOIS de un usuario
class WhoisDialog extends ConsumerWidget {
  final WhoisInfo info;
  final bool isRobot;
  final bool isGlobalChatBot; // Si es el robot oficial de GlobalChat

  const WhoisDialog({
    super.key,
    required this.info,
    this.isRobot = false,
    this.isGlobalChatBot = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.read(themeProvider);
    
    debugLog('🔍 [WHOIS DIALOG] Construyendo diálogo para: ${info.nick}');
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 700,
        ),
        decoration: BoxDecoration(
          color: appTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: appTheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRobot ? Colors.orange : appTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isRobot ? Icons.smart_toy : Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              info.nick,
                              style: TextStyle(
                                color: appTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isRobot) ...[
                              const SizedBox(width: 8),
                              const Text('🤖', style: TextStyle(fontSize: 20)),
                            ],
                          ],
                        ),
                        if (info.realName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            info.realName!,
                            style: TextStyle(
                              color: appTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: appTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información básica
                    _buildSection(
                      context,
                      appTheme,
                      'Información de conexión',
                      [
                        if (info.username != null || info.host != null)
                          _buildInfoRow(
                            appTheme: appTheme,
                            label: 'Usuario',
                            value: '${info.username ?? "N/A"}@${info.host ?? "N/A"}',
                            icon: Icons.account_circle,
                          ),
                        if (info.isSecureConnection)
                          _buildInfoRow(
                            appTheme: appTheme,
                            label: 'Conexión',
                            value: 'Segura (SSL/TLS)',
                            icon: Icons.lock,
                            valueColor: Colors.green,
                          ),
                      ],
                    ),
                    
                    // Información del servidor
                    if (info.server != null || info.serverInfo != null) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        appTheme,
                        'Servidor',
                        [
                          if (info.server != null)
                            _buildInfoRow(
                              appTheme: appTheme,
                              label: 'Servidor',
                              value: info.server!,
                              icon: Icons.dns,
                            ),
                          if (info.serverInfo != null)
                            _buildInfoRow(
                              appTheme: appTheme,
                              label: 'Información',
                              value: info.serverInfo!,
                              icon: Icons.info_outline,
                            ),
                        ],
                      ),
                    ],
                    
                    // Estado y actividad
                    if (info.idleSeconds != null || info.signonTime != null || info.isAway) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        appTheme,
                        'Estado y actividad',
                        [
                          if (info.isAway)
                            _buildInfoRow(
                              appTheme: appTheme,
                              label: 'Estado',
                              value: 'Ausente',
                              icon: Icons.person_off,
                              valueColor: Colors.orange,
                            ),
                          if (info.awayMessage != null)
                            _buildInfoRow(
                              appTheme: appTheme,
                              label: 'Mensaje ausente',
                              value: info.awayMessage!,
                              icon: Icons.message,
                            ),
                          if (info.idleSeconds != null)
                            _buildInfoRow(
                              appTheme: appTheme,
                              label: 'Tiempo inactivo',
                              value: _formatDuration(info.idleSeconds!),
                              icon: Icons.timer_outlined,
                            ),
                          if (info.signonTime != null)
                            _buildInfoRow(
                              appTheme: appTheme,
                              label: 'Conectado desde',
                              value: _formatDateTime(info.signonTime!),
                              icon: Icons.access_time,
                            ),
                        ],
                      ),
                    ],
                    
                    // Robot Oficial de GlobalChat
                    if (isGlobalChatBot) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFFD700).withValues(alpha: 0.2),
                              const Color(0xFFFFA500).withValues(alpha: 0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '🤖',
                                style: TextStyle(fontSize: 28),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Robot Oficial del Canal GlobalChat',
                                    style: TextStyle(
                                      color: const Color(0xFFFFD700),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Bot oficial de la red GlobalChat que gestiona el canal #globalchat',
                                    style: TextStyle(
                                      color: appTheme.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Staff/Operador
                    if (info.isStaff) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield,
                              color: Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Staff / Operador IRC',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (info.staffRole != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      info.staffRole!,
                                      style: TextStyle(
                                        color: appTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Canales
                    if (info.channels.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSection(
                        context,
                        appTheme,
                        'Canales (${info.channels.length})',
                        [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: info.channels.map((channel) {
                              return Chip(
                                label: Text(
                                  channel,
                                  style: TextStyle(
                                    color: appTheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: appTheme.primary.withValues(alpha: 0.1),
                                side: BorderSide(
                                  color: appTheme.primary.withValues(alpha: 0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appTheme.surface.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cerrar',
                      style: TextStyle(color: appTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    AppTheme appTheme,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: appTheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow({
    required AppTheme appTheme,
    required String label,
    required String value,
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: appTheme.textSecondary,
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? appTheme.textPrimary,
                fontSize: 13,
              ),
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
      return '$minutes minuto${minutes != 1 ? 's' : ''}';
    } else if (seconds < 86400) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (minutes == 0) {
        return '$hours hora${hours != 1 ? 's' : ''}';
      }
      return '$hours hora${hours != 1 ? 's' : ''} $minutes minuto${minutes != 1 ? 's' : ''}';
    } else {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      if (hours == 0) {
        return '$days día${days != 1 ? 's' : ''}';
      }
      return '$days día${days != 1 ? 's' : ''} $hours hora${hours != 1 ? 's' : ''}';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    try {
      if (difference.inDays == 0) {
        // Hoy
        return 'Hoy a las ${DateFormat('HH:mm').format(dateTime)}';
      } else if (difference.inDays == 1) {
        // Ayer
        return 'Ayer a las ${DateFormat('HH:mm').format(dateTime)}';
      } else if (difference.inDays < 7) {
        // Esta semana
        try {
          return DateFormat('EEEE d \'de\' MMMM \'a las\' HH:mm', 'es_ES').format(dateTime);
        } catch (e) {
          return DateFormat('EEEE d MMMM \'a las\' HH:mm', 'es_ES').format(dateTime);
        }
      } else {
        // Más de una semana
        try {
          return DateFormat('d \'de\' MMMM \'de\' yyyy \'a las\' HH:mm', 'es_ES').format(dateTime);
        } catch (e) {
          return DateFormat('d MMMM yyyy \'a las\' HH:mm', 'es_ES').format(dateTime);
        }
      }
    } catch (e) {
      // Fallback a formato simple si hay problemas con el locale
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }
}
