import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';

class ConnectedTimePanel extends ConsumerStatefulWidget {
  const ConnectedTimePanel({super.key});

  @override
  ConsumerState<ConnectedTimePanel> createState() => _ConnectedTimePanelState();
}

class _ConnectedTimePanelState extends ConsumerState<ConnectedTimePanel> {
  Timer? _timer;
  DateTime? _connectTime;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ircService = ref.read(ircServiceProvider);
    final isConnected = ircService.isConnected;
    final appTheme = ref.watch(themeProvider);

    if (!isConnected) {
      _connectTime = null;
      return const SizedBox.shrink();
    }

    _connectTime ??= DateTime.now();

    final elapsed = DateTime.now().difference(_connectTime!);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;

    final timeStr = hours > 0
        ? '${hours}h ${minutes}m ${seconds}s'
        : '${minutes}m ${seconds.toString().padLeft(2, '0')}s';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: appTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 14, color: appTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            timeStr,
            style: TextStyle(
              color: appTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.circle, size: 8, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'Online',
            style: TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
