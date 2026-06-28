import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_theme.dart';
import '../models/qualia_radio_status.dart';
import '../providers/qualia_radio_status_provider.dart';
import '../providers/theme_provider.dart';

/// Panel piloto de estado Qualia Radio (solo lectura, vía backend).
class QualiaRadioStatusPanel extends ConsumerStatefulWidget {
  const QualiaRadioStatusPanel({super.key});

  @override
  ConsumerState<QualiaRadioStatusPanel> createState() =>
      _QualiaRadioStatusPanelState();
}

class _QualiaRadioStatusPanelState extends ConsumerState<QualiaRadioStatusPanel> {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(qualiaRadioStatusProvider.notifier).startPolling();
    });
  }

  @override
  void dispose() {
    ref.read(qualiaRadioStatusProvider.notifier).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final state = ref.watch(qualiaRadioStatusProvider);
    final status = state.status;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        decoration: BoxDecoration(
          color: appTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: appTheme.textSecondary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (status?.isLive ?? false)
                            ? Colors.red.withValues(alpha: 0.9)
                            : Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (status?.isLive ?? false) ? 'EN VIVO' : 'AUTO DJ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status?.nowPlayingDisplay.isNotEmpty == true
                            ? status!.nowPlayingDisplay
                            : 'Qualia Radio — cargando estado…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (state.loading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: appTheme.primary,
                        ),
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Actualizar',
                        onPressed: () => ref
                            .read(qualiaRadioStatusProvider.notifier)
                            .refresh(),
                        icon: Icon(Icons.refresh, size: 18, color: appTheme.primary),
                      ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: appTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: state.error != null && status == null
                    ? _buildError(appTheme, state.error!)
                    : status == null
                        ? Text(
                            'Consultando estado de la radio…',
                            style: TextStyle(color: appTheme.textSecondary),
                          )
                        : _buildContent(context, appTheme, status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(AppTheme appTheme, String error) {
    return Text(
      'No se pudo cargar el estado: $error',
      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppTheme appTheme,
    QualiaRadioStatus status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status.artUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  status.artUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _artPlaceholder(appTheme),
                ),
              )
            else
              _artPlaceholder(appTheme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.liveLabel,
                    style: TextStyle(
                      color: status.isLive ? Colors.red.shade700 : appTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.nowPlayingDisplay,
                    style: TextStyle(
                      color: appTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (status.playlist.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Lista: ${status.playlist}',
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
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip(appTheme, Icons.headphones, '${status.listenersCurrent} oyentes'),
            if (status.bitrate != null)
              _chip(appTheme, Icons.speed, '${status.bitrate} kbps ${status.streamFormat.toUpperCase()}'),
            if (status.elapsedLabel != null && status.remainingLabel != null)
              _chip(
                appTheme,
                Icons.timer_outlined,
                '${status.elapsedLabel} / quedan ${status.remainingLabel}',
              ),
            _chip(
              appTheme,
              Icons.playlist_add,
              status.requestsEnabled ? 'Peticiones ON' : 'Peticiones OFF',
            ),
            if (status.isRequest) _chip(appTheme, Icons.favorite, 'Petición'),
          ],
        ),
        if (status.nextDisplay != null) ...[
          const SizedBox(height: 8),
          Text(
            'Siguiente: ${status.nextDisplay}',
            style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Comandos Orion (piloto)',
          style: TextStyle(
            color: appTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: status.orionCommands
              .map(
                (cmd) => ActionChip(
                  label: Text(
                    cmd.command,
                    style: const TextStyle(fontSize: 11),
                  ),
                  tooltip: cmd.description,
                  onPressed: () {},
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Sala DJs: ${status.djRoom}',
              style: TextStyle(color: appTheme.textSecondary, fontSize: 11),
            ),
            const Spacer(),
            if (status.publicPlayerUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(status.publicPlayerUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Player web'),
              ),
          ],
        ),
        Text(
          'Backend de solo lectura · no interrumpe la emisión',
          style: TextStyle(
            color: appTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _artPlaceholder(AppTheme appTheme) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: appTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note, color: appTheme.primary),
    );
  }

  Widget _chip(AppTheme appTheme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appTheme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: appTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: appTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
