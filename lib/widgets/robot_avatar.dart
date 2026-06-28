import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';

/// Avatar moderno para robots/bots.
///
/// Dibuja un fondo circular con el degradado del tema actual (cambia
/// automáticamente al cambiar el theme del webchat) y encima la imagen del
/// robot de GlobalChat (con el logo en el pecho).
class RobotAvatar extends ConsumerWidget {
  static const String asset = 'assets/branding/robot_globalchat.png';

  final double size;

  /// Se mantiene por compatibilidad con las llamadas existentes.
  final String seed;

  const RobotAvatar({super.key, required this.size, this.seed = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [appTheme.primary, appTheme.secondary],
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.06),
          child: Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.smart_toy,
                  size: size * 0.55,
                  color: appTheme.textPrimary,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
