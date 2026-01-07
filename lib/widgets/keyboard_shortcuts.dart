import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Intents para atajos de teclado
class FindIntent extends Intent {
  const FindIntent();
}

class FindNextIntent extends Intent {
  const FindNextIntent();
}

class NewChannelIntent extends Intent {
  const NewChannelIntent();
}

class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

class PreferencesIntent extends Intent {
  const PreferencesIntent();
}

class ExportLogsIntent extends Intent {
  const ExportLogsIntent();
}

// Acciones para los intents
class FindAction extends Action<FindIntent> {
  final VoidCallback onFind;

  FindAction({required this.onFind});

  @override
  Object? invoke(FindIntent intent) {
    onFind();
    return null;
  }
}

class FindNextAction extends Action<FindNextIntent> {
  final VoidCallback onFindNext;

  FindNextAction({required this.onFindNext});

  @override
  Object? invoke(FindNextIntent intent) {
    onFindNext();
    return null;
  }
}

class NewChannelAction extends Action<NewChannelIntent> {
  final VoidCallback onNewChannel;

  NewChannelAction({required this.onNewChannel});

  @override
  Object? invoke(NewChannelIntent intent) {
    onNewChannel();
    return null;
  }
}

class CloseTabAction extends Action<CloseTabIntent> {
  final VoidCallback onCloseTab;

  CloseTabAction({required this.onCloseTab});

  @override
  Object? invoke(CloseTabIntent intent) {
    onCloseTab();
    return null;
  }
}

class PreferencesAction extends Action<PreferencesIntent> {
  final VoidCallback onPreferences;

  PreferencesAction({required this.onPreferences});

  @override
  Object? invoke(PreferencesIntent intent) {
    onPreferences();
    return null;
  }
}

class ExportLogsAction extends Action<ExportLogsIntent> {
  final VoidCallback onExportLogs;

  ExportLogsAction({required this.onExportLogs});

  @override
  Object? invoke(ExportLogsIntent intent) {
    onExportLogs();
    return null;
  }
}

/// Widget que envuelve la aplicación con atajos de teclado macOS
class MacOSKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback? onFind;
  final VoidCallback? onFindNext;
  final VoidCallback? onNewChannel;
  final VoidCallback? onCloseTab;
  final VoidCallback? onPreferences;
  final VoidCallback? onExportLogs;

  const MacOSKeyboardShortcuts({
    Key? key,
    required this.child,
    this.onFind,
    this.onFindNext,
    this.onNewChannel,
    this.onCloseTab,
    this.onPreferences,
    this.onExportLogs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        // Cmd+F: Buscar
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const FindIntent(),
        // Cmd+G: Buscar siguiente
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true): const FindNextIntent(),
        // Shift+Cmd+G: Buscar anterior (se maneja en el diálogo)
        // Cmd+K: Nuevo canal/privado
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const NewChannelIntent(),
        // Cmd+W: Cerrar pestaña
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): const CloseTabIntent(),
        // Cmd+,: Preferencias
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): const PreferencesIntent(),
        // Cmd+E: Exportar logs
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true): const ExportLogsIntent(),
      },
      child: Actions(
        actions: {
          FindIntent: FindAction(onFind: onFind ?? () {}),
          FindNextIntent: FindNextAction(onFindNext: onFindNext ?? () {}),
          NewChannelIntent: NewChannelAction(onNewChannel: onNewChannel ?? () {}),
          CloseTabIntent: CloseTabAction(onCloseTab: onCloseTab ?? () {}),
          PreferencesIntent: PreferencesAction(onPreferences: onPreferences ?? () {}),
          ExportLogsIntent: ExportLogsAction(onExportLogs: onExportLogs ?? () {}),
        },
        child: child,
      ),
    );
  }
}


