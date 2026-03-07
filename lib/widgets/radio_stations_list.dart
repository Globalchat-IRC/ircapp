import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/radio_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/irc_provider.dart';
import '../config/debug_config.dart';

class RadioStationsList extends ConsumerStatefulWidget {
  const RadioStationsList({super.key});

  @override
  ConsumerState<RadioStationsList> createState() => _RadioStationsListState();
}

class _RadioStationsListState extends ConsumerState<RadioStationsList> {
  @override
  void initState() {
    super.initState();
    // Cargar estaciones al abrir el diálogo si no hay ninguna
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final radioState = ref.read(radioProvider);
      if (radioState.stations.isEmpty) {
        ref.read(radioProvider.notifier).loadStations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final radioState = ref.watch(radioProvider);
    final appTheme = ref.watch(themeProvider);
    final ircService = ref.read(ircServiceProvider);

    return Dialog(
      backgroundColor: appTheme.background,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estaciones de Radio',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh, color: appTheme.textPrimary),
                      onPressed: () {
                        ref.read(radioProvider.notifier).loadStations();
                      },
                      tooltip: 'Recargar estaciones',
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: appTheme.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: radioState.stations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando estaciones...',
                            style: TextStyle(color: appTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              ref.read(radioProvider.notifier).loadStations();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Recargar'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: radioState.stations.length,
                      itemBuilder: (context, index) {
                        final station = radioState.stations[index];
                        final isStarred = radioState.isStarred(station);
                        final isActive =
                            radioState.activeStation?.name == station.name;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? appTheme.primary.withValues(alpha: 0.2)
                                : appTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? appTheme.primary
                                  : appTheme.surface,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isStarred
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: isStarred
                                          ? Colors.amber
                                          : appTheme.textSecondary,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(radioProvider.notifier)
                                          .toggleStarred(station);
                                    },
                                    tooltip: isStarred
                                        ? 'Quitar de favoritos'
                                        : 'Añadir a favoritos',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.play_arrow,
                                      color: appTheme.primary,
                                    ),
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      final radioService =
                                          ref.read(radioServiceProvider);
                                      
                                      // Primero, establecer la estación activa
                                      // (esto verifica el stream en vivo si es UrbanFlow)
                                      await ref
                                          .read(radioProvider.notifier)
                                          .setActiveStation(station);
                                      
                                      // IMPORTANTE: Esperar un frame para que el estado se propague
                                      await Future.delayed(const Duration(milliseconds: 100));
                                      
                                      // Luego, obtener la estación actualizada del estado
                                      final radioState = ref.read(radioProvider);
                                      final updatedStation = radioState.activeStation;
                                      
                                      debugLog('🎵 [RadioStationsList] Estación actualizada: ${updatedStation?.name}');
                                      debugLog('🎵 [RadioStationsList] URL a reproducir: ${updatedStation?.source}');
                                      
                                      if (updatedStation != null) {
                                        // Reproducir con la URL actualizada
                                      radioService
                                            .playStation(updatedStation)
                                          .then((_) {
                                        ref
                                            .read(radioProvider.notifier)
                                            .setPlaying(true);
                                      }).catchError((e) {
                                        ref
                                            .read(radioProvider.notifier)
                                            .setError(true);
                                      });
                                      }
                                    },
                                    tooltip: 'Reproducir',
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${station.name} - ${station.description}',
                                          style: TextStyle(
                                            color: appTheme.textPrimary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (station.currentArtistSong != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              station.currentArtistSong!,
                                              style: TextStyle(
                                                color: appTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (station.namesite != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: InkWell(
                                    onTap: () async {
                                      final uri =
                                          Uri.parse(station.namesite!);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode
                                              .externalApplication,
                                        );
                                      }
                                    },
                                    child: Text(
                                      station.namesite!,
                                      style: TextStyle(
                                        color: appTheme.primary,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              if (station.salon != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: InkWell(
                                    onTap: () {
                                      final channel = station.salon!;
                                      ircService.joinChannel(channel);
                                      Navigator.of(context).pop();
                                    },
                                    child: Text(
                                      'Canal: ${station.salon}',
                                      style: TextStyle(
                                        color: appTheme.secondary,
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


