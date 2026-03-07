import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RustDeskSupportDialog extends StatelessWidget {
  final dynamic appTheme;
  final VoidCallback? onJoinHelpChannel;

  const RustDeskSupportDialog({
    super.key,
    required this.appTheme,
    this.onJoinHelpChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              appTheme.primary.withOpacity(0.95),
              appTheme.secondary.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
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
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  colors: [
                    appTheme.accent.withOpacity(0.3),
                    appTheme.secondary.withOpacity(0.3),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [appTheme.accent, appTheme.secondary],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '🖥️',
                        style: TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Soporte Remoto con RustDesk',
                          style: TextStyle(
                            color: appTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Conecta con nuestro equipo de soporte',
                          style: TextStyle(
                            color: appTheme.textSecondary.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: appTheme.textPrimary.withOpacity(0.7)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      '📥 Paso 1: Descargar RustDesk',
                      'Descarga RustDesk para tu sistema operativo:',
                      [
                        _buildDownloadButton(
                          context,
                          'Windows (64-bit)',
                          'https://github.com/rustdesk/rustdesk/releases/download/1.4.5/rustdesk-1.4.5-x86_64.exe',
                          Icons.desktop_windows,
                        ),
                        _buildDownloadButton(
                          context,
                          'macOS (Intel)',
                          'https://github.com/rustdesk/rustdesk/releases/download/1.4.5/rustdesk-1.4.5-x86_64.dmg',
                          Icons.laptop_mac,
                        ),
                        _buildDownloadButton(
                          context,
                          'macOS (Apple Silicon)',
                          'https://github.com/rustdesk/rustdesk/releases/download/1.4.5/rustdesk-1.4.5-aarch64.dmg',
                          Icons.laptop_mac,
                        ),
                        _buildDownloadButton(
                          context,
                          'Linux (Ubuntu/Debian)',
                          'https://github.com/rustdesk/rustdesk/releases/download/1.4.5/rustdesk-1.4.5-x86_64.deb',
                          Icons.computer,
                        ),
                        _buildDownloadButton(
                          context,
                          'Android',
                          'https://github.com/rustdesk/rustdesk/releases/download/1.4.5/rustdesk-1.4.5-universal-signed.apk',
                          Icons.android,
                        ),
                        _buildDownloadButton(
                          context,
                          'Ver todas las descargas',
                          'https://github.com/rustdesk/rustdesk/releases/tag/1.4.5',
                          Icons.download,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      '🔧 Paso 2: Instalar RustDesk',
                      _getInstallInstructions(),
                      [],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      '🔑 Paso 3: Obtener tu ID de RustDesk',
                      'Una vez instalado RustDesk:\n\n'
                      '1. Abre RustDesk\n'
                      '2. En la pantalla principal verás tu "ID" (número de 9 dígitos)\n'
                      '3. También verás una "Contraseña" temporal\n'
                      '4. Comparte ambos con nuestro equipo de soporte en el canal #ayuda o #cau',
                      [],
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      '📞 Paso 4: Conectarte con Soporte',
                      'Para recibir soporte remoto:\n\n'
                      '1. Ve al canal #ayuda o #cau\n'
                      '2. Indica que necesitas soporte remoto\n'
                      '3. Proporciona tu ID de RustDesk\n'
                      '4. Un miembro del equipo te contactará\n'
                      '5. Cuando te pidan, comparte tu contraseña temporal',
                      [],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: appTheme.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: appTheme.accent.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: appTheme.accent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '💡 Consejo: Mantén RustDesk abierto mientras recibes soporte. La contraseña cambia cada vez que reinicias la aplicación.',
                              style: TextStyle(
                                color: appTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                color: appTheme.primary.withOpacity(0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: appTheme.textPrimary.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cerrar',
                        style: TextStyle(color: appTheme.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (onJoinHelpChannel != null) {
                            onJoinHelpChannel!();
                          }
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ir a #ayuda',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildSection(String title, String content, List<Widget> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: appTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            color: appTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        if (buttons.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buttons,
          ),
        ],
      ],
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    String label,
    String url,
    IconData icon,
  ) {
    return ElevatedButton.icon(
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo abrir: $url'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: appTheme.accent.withOpacity(0.2),
        foregroundColor: appTheme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _getInstallInstructions() {
    if (kIsWeb) {
      return 'Para instalar RustDesk en tu dispositivo:\n\n'
          '1. Descarga la versión correspondiente a tu sistema operativo desde los botones de arriba\n'
          '2. Sigue las instrucciones específicas según tu plataforma:\n\n'
          '• Windows: Ejecuta el .exe y sigue el asistente\n'
          '• macOS: Abre el .dmg y arrastra a Aplicaciones\n'
          '• Linux: Instala el .deb con: sudo dpkg -i rustdesk-1.4.5-x86_64.deb\n'
          '• Android: Abre el .apk y permite la instalación\n\n'
          '3. Una vez instalado, abre RustDesk y verás tu ID';
    } else {
      // Para plataformas nativas, intentar detectar la plataforma
      // Como no podemos usar Platform en web, mostramos instrucciones generales
      return 'Para instalar RustDesk:\n\n'
          '1. Descarga la versión correspondiente a tu sistema operativo\n'
          '2. Sigue las instrucciones de instalación:\n\n'
          '• Windows: Ejecuta el .exe descargado y sigue el asistente\n'
          '• macOS: Abre el .dmg y arrastra RustDesk a Aplicaciones\n'
          '• Linux: Instala con: sudo dpkg -i rustdesk-1.4.5-x86_64.deb\n'
          '• Android: Abre el .apk y permite la instalación\n\n'
          '3. Una vez instalado, abre RustDesk desde el menú de aplicaciones';
    }
  }
}
