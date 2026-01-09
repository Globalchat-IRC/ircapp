import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/radio_provider.dart';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../models/app_theme.dart';
import '../providers/theme_provider.dart';
import 'radio_stations_list.dart';

class RadioControls extends ConsumerStatefulWidget {
  const RadioControls({Key? key}) : super(key: key);

  @override
  ConsumerState<RadioControls> createState() => _RadioControlsState();
}

class _RadioControlsState extends ConsumerState<RadioControls> {
  bool _showVolumeSlider = false;

  @override
  void initState() {
    super.initState();
    // print('📻 RadioControls initState');
    // Verificar estado actual
    final currentState = ref.read(radioProvider);
    // print('📻 Estado actual: ${currentState.stations.length} estaciones');
    
    // Cargar estaciones al iniciar si no hay ninguna
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(radioProvider);
      if (state.stations.isEmpty) {
        // print('📻 No hay estaciones, cargando desde RadioControls...');
        ref.read(radioProvider.notifier).loadStations();
      } else {
        // print('📻 Ya hay ${state.stations.length} estaciones cargadas');
      }
    });
  }

  void _playStation([RadioStation? station]) async {
    final radioState = ref.read(radioProvider);
    final radioService = ref.read(radioServiceProvider);
    final stationToPlay = station ?? radioState.activeStation;
    
    // print('📻 _playStation llamado');
    // print('📻 Estaciones disponibles: ${radioState.stations.length}');
    // print('📻 Estación a reproducir: ${stationToPlay?.name ?? "ninguna"}');
    
    // Asegurar que el RadioService esté inicializado
    await radioService.initialize();
    
    // Aplicar volumen desde el estado antes de reproducir
    await radioService.setVolume(radioState.volume);
    
    if (stationToPlay == null) {
      // print('📻 No hay estación seleccionada');
      // Si no hay estación activa, elegir la primera disponible
      if (radioState.stations.isNotEmpty) {
        final firstStation = radioState.stations.first;
        // print('📻 Seleccionando primera estación: ${firstStation.name}');
        ref.read(radioProvider.notifier).setActiveStation(firstStation);
        try {
          await radioService.playStation(firstStation);
          // print('📻 Reproducción iniciada exitosamente');
          ref.read(radioProvider.notifier).setPlaying(true);
          ref.read(radioProvider.notifier).setError(false);
        } catch (e) {
          // print('❌ Error al reproducir: $e');
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
      } else {
        // print('❌ No hay estaciones disponibles');
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

    // print('📻 Reproduciendo: ${stationToPlay.name}');
    ref.read(radioProvider.notifier).setActiveStation(stationToPlay);
    ref.read(radioProvider.notifier).setError(false);
    
    try {
      await radioService.playStation(stationToPlay);
      ref.read(radioProvider.notifier).setPlaying(true);
      ref.read(radioProvider.notifier).setError(false);
    } catch (e) {
      ref.read(radioProvider.notifier).setError(true);
      ref.read(radioProvider.notifier).setPlaying(false);
      
      // Mostrar mensaje al usuario con información útil
      if (mounted) {
        String errorMessage = 'No se pudo reproducir ${stationToPlay.name}';
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

  void _changeVolume(double volume) async {
    final radioService = ref.read(radioServiceProvider);
    await radioService.setVolume(volume);
    ref.read(radioProvider.notifier).setVolume(volume);
    // Forzar actualización del estado
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final radioState = ref.watch(radioProvider);
    final appTheme = ref.watch(themeProvider);
    
    // Debug: mostrar estado actual
    if (radioState.stations.isEmpty) {
      // print('📻 [build] No hay estaciones cargadas aún');
      // Intentar cargar si aún no se han cargado
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(radioProvider).stations.isEmpty) {
          // print('📻 [build] Forzando carga de estaciones...');
          ref.read(radioProvider.notifier).loadStations();
        }
      });
    } else {
      // print('📻 [build] Estaciones: ${radioState.stations.length}, Activa: ${radioState.activeStation?.name ?? "ninguna"}, Reproduciendo: ${radioState.isPlaying}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appTheme.surface,
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
          ),
          const SizedBox(width: 4),
          
          // Botón play/pause
          _buildControlButton(
            icon: radioState.isPlaying ? Icons.pause : Icons.play_arrow,
            onPressed: radioState.isPlaying ? _pauseStation : () => _playStation(),
            tooltip: radioState.isPlaying ? 'Pausa' : 'Reproducir',
            appTheme: appTheme,
          ),
          const SizedBox(width: 4),
          
          // Botón stop
          _buildControlButton(
            icon: Icons.stop,
            onPressed: radioState.isPlaying || radioState.activeStation != null ? _stopStation : null,
            tooltip: 'Detener',
            appTheme: appTheme,
          ),
          const SizedBox(width: 4),
          
          // Botón siguiente
          _buildControlButton(
            icon: Icons.skip_next,
            onPressed: () => _skipStation(1),
            tooltip: 'Siguiente Radio',
            appTheme: appTheme,
          ),
          const SizedBox(width: 4),
          
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
          ),
          const SizedBox(width: 4),
          
          // Control de volumen
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _buildControlButton(
                icon: radioState.volume == 0
                    ? Icons.volume_off
                    : radioState.volume >= 0.5
                        ? Icons.volume_up
                        : Icons.volume_down,
                onPressed: () {
                  setState(() {
                    _showVolumeSlider = !_showVolumeSlider;
                  });
                },
                tooltip: 'Volumen: ${(radioState.volume * 100).toInt()}%',
                appTheme: appTheme,
              ),
              if (_showVolumeSlider)
                Positioned(
                  bottom: 45,
                  left: -35,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _showVolumeSlider = true),
                    onExit: (_) {
                      // No ocultar inmediatamente, dar tiempo para interactuar
                      Future.delayed(const Duration(milliseconds: 800), () {
                        if (mounted) {
                          setState(() => _showVolumeSlider = false);
                        }
                      });
                    },
                    child: Material(
                      elevation: 12,
                      borderRadius: BorderRadius.circular(8),
                      shadowColor: appTheme.primary.withOpacity(0.5),
                      child: Container(
                        width: 120,
                        height: 220,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                        decoration: BoxDecoration(
                          color: appTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: appTheme.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: appTheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 6.0, // Más grueso para mejor interacción
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0), // Más grande
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0), // Área de toque más grande
                            ),
                            child: Slider(
                              value: radioState.volume,
                              onChanged: (value) {
                                _changeVolume(value);
                              },
                              onChangeStart: (_) {
                                // Mantener el slider visible mientras se arrastra
                                setState(() => _showVolumeSlider = true);
                              },
                              onChangeEnd: (_) {
                                // Mantener visible un poco más después de soltar
                                Future.delayed(const Duration(milliseconds: 1500), () {
                                  if (mounted) {
                                    setState(() => _showVolumeSlider = false);
                                  }
                                });
                              },
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              activeColor: appTheme.primary,
                              inactiveColor: appTheme.primary.withOpacity(0.3),
                              label: '${(radioState.volume * 100).toInt()}%',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 8),
          
          // Nombre de la estación
          Expanded(
            child: Text(
              radioState.activeStation?.name ?? 'Radio Nuestras Voces',
              style: TextStyle(
                color: radioState.hasError
                    ? Colors.red
                    : appTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required AppTheme appTheme,
  }) {
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
                  ? appTheme.textPrimary 
                  : appTheme.textPrimary.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }
}



