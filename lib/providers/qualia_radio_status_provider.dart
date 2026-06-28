import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/qualia_radio_status.dart';
import '../services/qualia_radio_api_service.dart';
import 'qualia_radio_dj_provider.dart';

final qualiaRadioApiServiceProvider = Provider<QualiaRadioApiService>(
  (ref) => QualiaRadioApiService(),
);

class QualiaRadioStatusState {
  const QualiaRadioStatusState({
    this.status,
    this.loading = false,
    this.error,
    this.lastUpdated,
  });

  final QualiaRadioStatus? status;
  final bool loading;
  final String? error;
  final DateTime? lastUpdated;

  QualiaRadioStatusState copyWith({
    QualiaRadioStatus? status,
    bool? loading,
    String? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return QualiaRadioStatusState(
      status: status ?? this.status,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class QualiaRadioStatusNotifier extends Notifier<QualiaRadioStatusState> {
  Timer? _pollTimer;

  @override
  QualiaRadioStatusState build() {
    ref.onDispose(() => _pollTimer?.cancel());
    return const QualiaRadioStatusState();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final status =
          await ref.read(qualiaRadioApiServiceProvider).fetchStatus();
      // Detectar quién emite en directo desde el stream y reflejarlo en el
      // tag de DJ de la lista de usuarios (persiste al reentrar al canal).
      ref.read(qualiaRadioLiveDjProvider.notifier).applyLiveStreamer(
            status.isLive ? status.streamerName : null,
          );
      state = QualiaRadioStatusState(
        status: status,
        loading: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
      );
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 30)}) {
    _pollTimer?.cancel();
    refresh();
    _pollTimer = Timer.periodic(interval, (_) => refresh(showLoading: false));
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

final qualiaRadioStatusProvider =
    NotifierProvider<QualiaRadioStatusNotifier, QualiaRadioStatusState>(
  QualiaRadioStatusNotifier.new,
);
