import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';

/// Estado de las actualizaciones
class UpdateState {
  final bool isChecking;
  final UpdateInfo? updateAvailable;
  final String? error;
  final bool isDownloading;
  
  const UpdateState({
    this.isChecking = false,
    this.updateAvailable,
    this.error,
    this.isDownloading = false,
  });
  
  UpdateState copyWith({
    bool? isChecking,
    UpdateInfo? updateAvailable,
    String? error,
    bool? isDownloading,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      error: error ?? this.error,
      isDownloading: isDownloading ?? this.isDownloading,
    );
  }
}

/// Notifier para gestionar actualizaciones
class UpdateNotifier extends Notifier<UpdateState> {
  final UpdateService _updateService = UpdateService();
  
  @override
  UpdateState build() {
    // Verificar actualizaciones al iniciar (después de 5 segundos)
    Future.delayed(const Duration(seconds: 5), () {
      checkForUpdates();
    });
    return const UpdateState();
  }
  
  /// Verificar si hay actualizaciones disponibles
  Future<void> checkForUpdates({bool forceCheck = false}) async {
    if (state.isChecking) return;
    
    state = state.copyWith(isChecking: true, error: null);
    
    try {
      final updateInfo = await _updateService.checkForUpdates(forceCheck: forceCheck);
      
      if (updateInfo != null) {
        state = state.copyWith(
          isChecking: false,
          updateAvailable: updateInfo,
        );
      } else {
        state = state.copyWith(isChecking: false);
      }
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
    }
  }
  
  /// Descargar e instalar actualización
  Future<void> downloadAndInstall() async {
    if (state.updateAvailable == null || state.isDownloading) return;
    
    state = state.copyWith(isDownloading: true);
    
    try {
      final success = await _updateService.downloadUpdate(state.updateAvailable!);
      
      if (success) {
        // Éxito - el navegador se abrió o la descarga comenzó
        state = state.copyWith(isDownloading: false);
      } else {
        state = state.copyWith(
          isDownloading: false,
          error: 'No se pudo iniciar la descarga',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }
  
  /// Descargar en segundo plano e instalar automáticamente
  Future<void> downloadInBackgroundAndInstall() async {
    if (state.updateAvailable == null || state.isDownloading) return;
    
    state = state.copyWith(isDownloading: true);
    
    try {
      final installerPath = await _updateService.downloadUpdateInBackground(state.updateAvailable!);
      
      if (installerPath != null) {
        // Instalar
        await _updateService.installUpdate(installerPath);
      } else {
        // Si falla la descarga en segundo plano, abrir navegador
        await _updateService.downloadUpdate(state.updateAvailable!);
        state = state.copyWith(isDownloading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }
  
  /// Descartar notificación de actualización
  void dismissUpdate() {
    state = state.copyWith(updateAvailable: null);
  }
}

/// Provider para gestionar las actualizaciones
final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});

