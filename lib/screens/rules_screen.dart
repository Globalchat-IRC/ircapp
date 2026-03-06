import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../providers/theme_provider.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme appTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglas de GlobalChat'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      backgroundColor: appTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appTheme.primary.withOpacity(0.08),
              appTheme.secondary.withOpacity(0.06),
              appTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: appTheme.surface.withOpacity(0.96),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: appTheme.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reglas básicas del canal y de la red',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: appTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'El uso de GlobalChat implica la aceptación de estas normas. '
                            'El staff podrá tomar medidas (avisos, expulsiones temporales o permanentes) '
                            'cuando se incumplan.',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '1. Respeto y convivencia',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• No se permiten insultos, acoso, amenazas ni ataques personales.\n'
                            '• No se toleran comentarios racistas, sexistas, homófobos o de odio.\n'
                            '• Respeta a otros usuarios, al staff y a los canales.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '2. Contenido inapropiado',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• Prohibido contenido ilegal, violento o que promueva actividades delictivas.\n'
                            '• El contenido sexual explícito solo está permitido en canales marcados +18.\n'
                            '• No se permite compartir datos personales de terceros sin su consentimiento.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '3. SPAM, publicidad y flood',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• No hagas spam de webs, servicios o canales sin permiso de la administración.\n'
                            '• Evita repetir el mismo mensaje muchas veces (flood) o escribir en mayúsculas de forma abusiva.\n'
                            '• No se permiten bots no autorizados.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '4. Nicks, identidades y suplantaciones',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• No uses nicks ofensivos o que puedan inducir a error (por ejemplo, nicks similares a los del staff).\n'
                            '• Está prohibido suplantar a otros usuarios o a miembros del equipo.\n'
                            '• Se recomienda registrar tu nick para proteger tu identidad.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '5. Menores de edad',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• El acceso a canales +18 está restringido a usuarios mayores de edad.\n'
                            '• Cualquier conducta de riesgo con menores será motivo de expulsión inmediata '
                            'y, si procede, de denuncia ante las autoridades.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '6. Seguridad y sentido común',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• No compartas tus contraseñas ni datos sensibles.\n'
                            '• Desconfía de enlaces sospechosos o ficheros que te envíen usuarios desconocidos.\n'
                            '• Si detectas comportamientos peligrosos o ilegales, avisa al staff.',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '7. Autoridad del staff',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: appTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '• Los operadores de canal y administradores de la red pueden tomar decisiones '
                            'para garantizar el buen ambiente.\n'
                            '• Sus indicaciones deben respetarse. Si no estás de acuerdo, puedes exponerlo '
                            'con educación o contactar con otro miembro del staff.',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Estas normas pueden ampliarse o modificarse. Consulta periódicamente la web oficial '
                            'de GlobalChat para la versión actualizada.',
                            style: TextStyle(
                              fontSize: 13,
                              color: appTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

