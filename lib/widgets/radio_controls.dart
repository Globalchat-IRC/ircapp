import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/radio_provider.dart';
import '../providers/irc_provider.dart';
import '../providers/qualia_radio_dj_provider.dart';
import '../providers/qualia_radio_status_provider.dart';
import '../models/qualia_radio_status.dart';
import '../models/radio_station.dart';
import '../models/app_theme.dart';
import '../providers/theme_provider.dart';
import 'radio_stations_list.dart';
import '../utils/platform_utils.dart';
import '../config/debug_config.dart';

class RadioControls extends ConsumerStatefulWidget {
  const RadioControls({super.key});

  @override
  ConsumerState<RadioControls> createState() => _RadioControlsState();
}

class _RadioControlsState extends ConsumerState<RadioControls> {
  @override
  void initState() {
    super.initState();
    // debugLog('📻 RadioControls initState');

    // Cargar estaciones al iniciar si no hay ninguna
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = ref.read(radioProvider);
      if (state.stations.isEmpty) {
        // debugLog('📻 No hay estaciones, cargando desde RadioControls...');
        ref.read(radioProvider.notifier).loadStations();
      }
      // Aplicar volumen guardado al servicio de audio.
      final radioService = ref.read(radioServiceProvider);
      await radioService.initialize();
      await radioService.setVolume(state.volume);
    });
  }

  Future<void> _setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    ref.read(radioProvider.notifier).setVolume(clamped);
    await ref.read(radioServiceProvider).setVolume(clamped);
  }

  IconData _volumeIcon(double volume) {
    if (volume <= 0) return Icons.volume_off;
    if (volume < 0.35) return Icons.volume_mute;
    if (volume < 0.7) return Icons.volume_down;
    return Icons.volume_up;
  }

  /// En movil el slider en linea (80px) compite con los gestos de los drawers
  /// y es dificil de arrastrar; abrimos un dialogo con un slider ancho.
  void _showVolumeDialog(AppTheme appTheme) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appTheme.surface,
          title: Text(
            'Volumen',
            style: TextStyle(color: appTheme.textPrimary),
          ),
          content: Consumer(
            builder: (context, ref, _) {
              final volume = ref.watch(radioProvider).volume;
              return Row(
                children: [
                  IconButton(
                    icon: Icon(_volumeIcon(volume), color: appTheme.primary),
                    onPressed: () =>
                        _setVolume(volume <= 0 ? 0.85 : 0.0),
                  ),
                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(volume * 100).round()}%',
                      activeColor: appTheme.primary,
                      onChanged: (v) => _setVolume(v),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(volume * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: appTheme.textPrimary),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _playStation([RadioStation? station]) async {
    final radioState = ref.read(radioProvider);
    final radioService = ref.read(radioServiceProvider);
    final stationToPlay = station ?? radioState.activeStation;
    
    // debugLog('📻 _playStation llamado');
    // debugLog('📻 Estaciones disponibles: ${radioState.stations.length}');
    // debugLog('📻 Estación a reproducir: ${stationToPlay?.name ?? "ninguna"}');
    
    // Asegurar que el RadioService esté inicializado
    await radioService.initialize();
    
    // Aplicar volumen desde el estado antes de reproducir
    await radioService.setVolume(radioState.volume);
    
    if (stationToPlay == null) {
      // debugLog('📻 No hay estación seleccionada');
      // Si no hay estación activa, elegir la primera disponible
      if (radioState.stations.isNotEmpty) {
        final firstStation = radioState.stations.first;
        // debugLog('📻 Seleccionando primera estación: ${firstStation.name}');
        await ref.read(radioProvider.notifier).setActiveStation(firstStation);
        
        // IMPORTANTE: Esperar un frame para que el estado se propague
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Obtener la estación actualizada del estado
        final updatedState = ref.read(radioProvider);
        final updatedStation = updatedState.activeStation;
        
        debugLog('🎵 [RadioControls] Estación actualizada (primera): ${updatedStation?.name}');
        debugLog('🎵 [RadioControls] URL a reproducir: ${updatedStation?.source}');
        
        if (updatedStation != null) {
          try {
            await radioService.playStation(updatedStation);
          // debugLog('📻 Reproducción iniciada exitosamente');
          ref.read(radioProvider.notifier).setPlaying(true);
          ref.read(radioProvider.notifier).setError(false);
        } catch (e) {
          // debugLog('❌ Error al reproducir: $e');
          ref.read(radioProvider.notifier).setError(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al reproducir la radio: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
    );
        }
      }
        }
      } else {
        // debugLog('❌ No hay estaciones disponibles');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay estaciones de radio disponibles. Cargando...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Intentar cargar estaciones
        ref.read(radioProvider.notifier).loadStations();
      }
      return;
    }

    // debugLog('📻 Reproduciendo: ${stationToPlay?.name}');
    await ref.read(radioProvider.notifier).setActiveStation(stationToPlay!);
    ref.read(radioProvider.notifier).setError(false);
    
    // IMPORTANTE: Esperar un frame para que el estado se propague
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Obtener la estación actualizada del estado
    final updatedState = ref.read(radioProvider);
    final updatedStation = updatedState.activeStation;
    
    debugLog('🎵 [RadioControls] Estación actualizada: ${updatedStation?.name}');
    debugLog('🎵 [RadioControls] URL a reproducir: ${updatedStation?.source}');
    
    // Log también en la consola del navegador directamente
    if (PlatformUtils.isWeb) {
      // ignore: avoid_web_libraries_in_flutter
      debugLog('🎵 [RadioControls] Estación: ${updatedStation?.name}');
      // ignore: avoid_web_libraries_in_flutter
      debugLog('🎵 [RadioControls] URL: ${updatedStation?.source}');
    }
    
    if (updatedStation != null) {
      try {
        debugLog('🎵 [RadioControls] Llamando a radioService.playStation...');
        // ignore: avoid_web_libraries_in_flutter
        if (PlatformUtils.isWeb) debugLog('🎵 [RadioControls] Llamando playStation...');
        await radioService.playStation(updatedStation);
      ref.read(radioProvider.notifier).setPlaying(true);
      ref.read(radioProvider.notifier).setError(false);
    } catch (e) {
      ref.read(radioProvider.notifier).setError(true);
      ref.read(radioProvider.notifier).setPlaying(false);
      
      // Mostrar mensaje al usuario con información útil
      if (mounted) {
          String errorMessage = 'No se pudo reproducir ${updatedStation.name}';
        if (e.toString().contains('CORS') || e.toString().contains('Failed to load')) {
          errorMessage += '\n\nEl servidor de radio puede tener restricciones de CORS.\nIntenta con otra estación.';
        } else {
          errorMessage += '\n\nError: ${e.toString().split(':').last.trim()}\nIntenta con otra estación.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Cerrar',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        }
      }
    }
  }

  void _pauseStation() {
    final radioService = ref.read(radioServiceProvider);
    radioService.pause();
    ref.read(radioProvider.notifier).setPlaying(false);
  }

  void _stopStation() async {
    final radioService = ref.read(radioServiceProvider);
    await radioService.stop();
    ref.read(radioProvider.notifier).setPlaying(false);
    // No limpiar la estación activa, solo detener la reproducción
    // El usuario puede querer volver a reproducir la misma estación
  }

  void _skipStation(int direction) {
    final radioState = ref.read(radioProvider);
    final stations = radioState.getStarredStations();
    final stationList = stations.length > 1 ? stations : radioState.stations;
    
    if (stationList.isEmpty) return;

    int currentIdx = -1;
    if (radioState.activeStation != null) {
      for (int i = 0; i < stationList.length; i++) {
        if (stationList[i].name == radioState.activeStation!.name) {
          currentIdx = i;
          break;
        }
      }
    }

    int nextIdx;
    if (currentIdx == -1) {
      nextIdx = direction > 0 ? 0 : stationList.length - 1;
    } else {
      nextIdx = currentIdx + direction;
      if (nextIdx >= stationList.length) {
        nextIdx = 0;
      } else if (nextIdx < 0) {
        nextIdx = stationList.length - 1;
      }
    }

    final nextStation = stationList[nextIdx];
    if (radioState.isPlaying) {
      _playStation(nextStation);
    } else {
      ref.read(radioProvider.notifier).setActiveStation(nextStation);
    }
  }


  @override
  Widget build(BuildContext context) {
    final radioState = ref.watch(radioProvider);
    final appTheme = ref.watch(themeProvider);
    final currentChannel = ref.watch(currentChannelProvider);
    final isQualiaRadio = currentChannel?.toLowerCase() == '#qualiaradio';

    // Al entrar en #QualiaRadio, refrescar estado y canción en curso.
    ref.listen<String?>(currentChannelProvider, (previous, next) {
      final statusNotifier = ref.read(qualiaRadioStatusProvider.notifier);
      if (next?.toLowerCase() == '#qualiaradio') {
        ref.read(radioProvider.notifier).refreshNowPlaying();
        statusNotifier.startPolling();
      } else {
        statusNotifier.stopPolling();
      }
    });

    if (isQualiaRadio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(currentChannelProvider)?.toLowerCase() == '#qualiaradio') {
          ref.read(qualiaRadioStatusProvider.notifier).startPolling();
        }
      });
    }
    
    // Debug: mostrar estado actual
    if (radioState.stations.isEmpty) {
      // debugLog('📻 [build] No hay estaciones cargadas aún');
      // Intentar cargar si aún no se han cargado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(radioProvider).stations.isEmpty) {
          // debugLog('📻 [build] Forzando carga de estaciones...');
          ref.read(radioProvider.notifier).loadStations();
        }
      });
    } else {
      // debugLog('📻 [build] Estaciones: ${radioState.stations.length}, Activa: ${radioState.activeStation?.name ?? "ninguna"}, Reproduciendo: ${radioState.isPlaying}');
    }

    final apiState = ref.watch(qualiaRadioStatusProvider);
    final ircLiveDj = ref.watch(qualiaRadioLiveDjProvider);
    final fallbackSong = radioState.activeStation?.currentArtistSong?.trim();

    // En #QualiaRadio la botonera usa el mismo diseño negro que el marquee.
    final controlColor =
        isQualiaRadio ? Colors.white : appTheme.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isQualiaRadio ? const Color(0xFF1A1A1A) : appTheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón anterior
          _buildControlButton(
            icon: Icons.skip_previous,
            onPressed: () => _skipStation(-1),
            tooltip: 'Anterior Radio',
            appTheme: appTheme,
            color: controlColor,
          ),
          const SizedBox(width: 4),
          
          // Botón play/pause
          _buildControlButton(
            icon: radioState.isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: radioState.isPlaying ? _pauseStation : () => _playStation(),
            tooltip: radioState.isPlaying ? 'Pausa' : 'Reproducir',
            appTheme: appTheme,
            color: controlColor,
          ),
          const SizedBox(width: 4),
          
          // Botón stop
          _buildControlButton(
            icon: Icons.stop,
            onPressed: radioState.isPlaying || radioState.activeStation != null ? _stopStation : null,
            tooltip: 'Detener',
            appTheme: appTheme,
            color: controlColor,
          ),
          const SizedBox(width: 4),
          
          // Botón siguiente
          _buildControlButton(
            icon: Icons.skip_next,
            onPressed: () => _skipStation(1),
            tooltip: 'Siguiente Radio',
            appTheme: appTheme,
            color: controlColor,
          ),
          const SizedBox(width: 4),

          // Control de volumen. En movil: boton que abre dialogo con slider
          // ancho (evita el conflicto de gestos del slider diminuto). En
          // escritorio/web: boton mute + slider en linea.
          _buildControlButton(
            icon: _volumeIcon(radioState.volume),
            onPressed: PlatformUtils.isMobile
                ? () => _showVolumeDialog(appTheme)
                : () => _setVolume(radioState.volume <= 0 ? 0.85 : 0.0),
            tooltip: PlatformUtils.isMobile
                ? 'Ajustar volumen'
                : (radioState.volume <= 0 ? 'Activar sonido' : 'Silenciar'),
            appTheme: appTheme,
            color: controlColor,
          ),
          if (!PlatformUtils.isMobile) ...[
            SizedBox(
              width: 80,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(
                  value: radioState.volume,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '${(radioState.volume * 100).round()}%',
                  activeColor: isQualiaRadio ? Colors.white : appTheme.primary,
                  inactiveColor:
                      (isQualiaRadio ? Colors.white : appTheme.textSecondary)
                          .withValues(alpha: 0.25),
                  onChanged: (v) => _setVolume(v),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          
          // Botón lista
          _buildControlButton(
            icon: Icons.list,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const RadioStationsList(),
              );
            },
            tooltip: 'Buscar Radios',
            appTheme: appTheme,
            color: controlColor,
          ),
        ],
      ),
    ),
        _QualiaNowPlayingMarquee(
          status: apiState.status,
          ircLiveDj: ircLiveDj,
          fallbackSong: fallbackSong,
          loading: apiState.loading && apiState.status == null,
          stationName: radioState.activeStation?.name ?? 'Qualia Radio',
          hasError: radioState.hasError,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required AppTheme appTheme,
    Color? color,
  }) {
    final baseColor = color ?? appTheme.textPrimary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 18,
              color: onPressed != null
                  ? baseColor
                  : baseColor.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}



/// Marquee Qualia Radio con estado en vivo, canción e info del backend.
class _QualiaNowPlayingMarquee extends ConsumerStatefulWidget {
  const _QualiaNowPlayingMarquee({
    required this.status,
    required this.ircLiveDj,
    required this.fallbackSong,
    this.loading = false,
    required this.stationName,
    this.hasError = false,
  });

  final QualiaRadioStatus? status;
  final String? ircLiveDj;
  final String? fallbackSong;
  final bool loading;
  final String stationName;
  final bool hasError;

  @override
  ConsumerState<_QualiaNowPlayingMarquee> createState() =>
      _QualiaNowPlayingMarqueeState();
}

class _QualiaNowPlayingMarqueeState
    extends ConsumerState<_QualiaNowPlayingMarquee>
    with SingleTickerProviderStateMixin {
  static const _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  AnimationController? _controller;
  double _scrollDistance = 0;
  String _lastMarqueeKey = '';

  bool get _isLive {
    if (widget.ircLiveDj != null && widget.ircLiveDj!.trim().isNotEmpty) {
      return true;
    }
    return widget.status?.isLive == true;
  }

  String _buildMarqueeText() {
    final status = widget.status;
    final station = widget.stationName.trim().isNotEmpty
        ? widget.stationName.trim()
        : 'Qualia Radio';
    final parts = <String>[];

    final song = (status?.nowPlayingDisplay.trim().isNotEmpty == true)
        ? status!.nowPlayingDisplay.trim()
        : (widget.fallbackSong?.trim().isNotEmpty == true
            ? widget.fallbackSong!.trim()
            : '');
    if (song.isNotEmpty) {
      parts.add('♪ $song');
    }

    if (status != null && status.isRequest) {
      parts.add('Petición');
    }

    if (parts.isEmpty) {
      if (widget.hasError) return '$station — sin conexión';
      if (widget.loading) return '$station — cargando estado…';
      return '$station — En directo';
    }
    return '$station · ${parts.join('   ·   ')}';
  }

  @override
  void didUpdateWidget(covariant _QualiaNowPlayingMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey =
        '${widget.status?.fetchedAt}_${widget.ircLiveDj}_${widget.fallbackSong}';
    if (_lastMarqueeKey != newKey) {
      _lastMarqueeKey = newKey;
      _controller?.dispose();
      _controller = null;
      _scrollDistance = 0;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _ensureAnimation(double containerWidth, double textWidth) {
    final distance = textWidth - containerWidth + 32;
    if (distance <= 0) {
      if (_controller != null) {
        _controller!.dispose();
        _controller = null;
        _scrollDistance = 0;
      }
      return;
    }
    if (_controller != null && _scrollDistance == distance) return;

    _controller?.dispose();
    _scrollDistance = distance;
    final durationMs = (distance / 35 * 1000).clamp(8000, 28000).round();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final text = _buildMarqueeText();
    final isLive = _isLive;

    return Container(
      width: double.infinity,
      height: 24,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF000000), Color(0xFF1A1A1A), Color(0xFF2B2B2B)],
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isLive
                        ? Colors.red.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isLive ? 'EN VIVO' : 'AUTO DJ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  isLive ? Icons.headphones : Icons.music_note,
                  color: Colors.white,
                  size: 14,
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: _textStyle),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                )..layout(maxWidth: double.infinity);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final hadController = _controller != null;
                  _ensureAnimation(constraints.maxWidth, painter.width);
                  final hasController = _controller != null;
                  if (hadController != hasController ||
                      (hasController && !_controller!.isAnimating)) {
                    setState(() {});
                    _controller?.repeat();
                  }
                });

                if (_controller == null ||
                    painter.width <= constraints.maxWidth) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      style: _textStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _controller!,
                    builder: (context, child) {
                      final offset = _controller!.value * _scrollDistance;
                      return Transform.translate(
                        offset: Offset(-offset, 0),
                        child: Text(text, style: _textStyle, maxLines: 1),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (widget.loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

