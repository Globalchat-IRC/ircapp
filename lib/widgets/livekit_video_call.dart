import 'dart:async';
import 'dart:convert';
// Web-only: uses dart:html for video element management. Not compilable on non-web platforms.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../services/livekit_service.dart';
import '../services/irc_service.dart';
import '../providers/video_provider.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/video_report_dialog.dart';
import '../models/video_report.dart';
import '../models/irc_message.dart';
import '../utils/video_room_url.dart';

enum _VideoLayout { auto, mosaic, focus, sidebar }

class LiveKitVideoCallScreen extends ConsumerStatefulWidget {
  final String roomName;
  final String identity;
  final bool audioOnly;

  const LiveKitVideoCallScreen({
    super.key,
    required this.roomName,
    required this.identity,
    this.audioOnly = false,
  });

  @override
  ConsumerState<LiveKitVideoCallScreen> createState() => _LiveKitVideoCallScreenState();
}

class _LiveKitVideoCallScreenState extends ConsumerState<LiveKitVideoCallScreen> {
  final LiveKitService _service = LiveKitService();
  lk.Room? _room;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _connectionFailed = false;
  bool _isBrave = false;
  lk.CancelListenFunc? _roomEventSub;

  @override
  void initState() {
    super.initState();
    _detectBrowser();
    _connect();
  }

  Future<void> _detectBrowser() async {
    try {
      final nav = html.window.navigator as dynamic;
      if (nav.brave != null) {
        final brave = nav.brave;
        if (brave != null) {
          final b = await brave.isBrave();
          if (mounted) setState(() => _isBrave = b == true);
        }
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    if (mounted) setState(() => _connectionFailed = false);
    final connected = await _service.connectToRoom(widget.roomName, widget.identity);
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _connectionFailed = !connected;
        _room = _service.room;
      });
      if (connected && _service.localParticipant != null) {
        try {
          await _service.localParticipant!.setMicrophoneEnabled(true);
          if (!widget.audioOnly) {
            await _service.localParticipant!.setCameraEnabled(true);
          } else {
            await _service.localParticipant!.setCameraEnabled(false);
            setState(() => _isVideoOff = true);
          }
        } catch (_) {}
      }
      _roomEventSub = _room?.events.listen((event) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _roomEventSub?.call();
    super.dispose();
  }

  void _toggleMute() {
    final muted = !_isMuted;
    _service.localParticipant?.setMicrophoneEnabled(!muted);
    setState(() => _isMuted = muted);
  }

  void _toggleVideo() {
    if (widget.audioOnly) return;
    final off = !_isVideoOff;
    _service.localParticipant?.setCameraEnabled(!off);
    setState(() => _isVideoOff = off);
  }

  Future<void> _hangUp() async {
    await _service.leaveConference();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _hangUp,
        ),
        title: Text(
          widget.roomName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: _isConnected && _room != null
          ? _buildVideoGrid()
          : _connectionFailed
              ? _buildConnectionError()
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
      bottomNavigationBar: _buildControls(),
    );
  }

  Widget _buildConnectionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No se pudo conectar a la videoconferencia',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_isBrave)
              const Text(
                'Brave bloquea WebRTC por privacidad.\n'
                'Abre el menú de Shields (icono 🛡️)\n'
                'y desactívalas para este sitio.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _connect(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid() {
    final participants = <lk.Participant>[
      if (_room?.localParticipant != null) _room!.localParticipant!,
      ...?_room?.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Esperando participantes...', style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (participants.length == 1) {
          return _buildParticipantTile(participants[0], fullscreen: true);
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: participants.length,
          itemBuilder: (context, index) => _buildParticipantTile(participants[index]),
        );
      },
    );
  }

  Widget _buildParticipantTile(lk.Participant participant, {bool fullscreen = false}) {
    final videoPub = participant.videoTrackPublications.firstOrNull;
    final isLocal = participant is lk.LocalParticipant;
    final isVideoMuted = isLocal ? _isVideoOff : (videoPub?.muted ?? true);
    final videoTrack = videoPub?.track as lk.VideoTrack?;

    Widget videoWidget;
    if (videoTrack != null && !isVideoMuted) {
      videoWidget = lk.VideoTrackRenderer(
        videoTrack,
        fit: lk.VideoViewFit.contain,
        mirrorMode: isLocal ? lk.VideoViewMirrorMode.mirror : lk.VideoViewMirrorMode.auto,
      );
    } else {
      videoWidget = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: fullscreen ? 80 : 40,
              height: fullscreen ? 80 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.blue.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: fullscreen ? 40 : 20,
              ),
            ),
            if (fullscreen) ...[
              const SizedBox(height: 12),
              Text(participant.identity ?? '', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          videoWidget,
          if (!fullscreen)
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  participant.identity ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          if (!isLocal && _service.isOwner)
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => _showFullscreenModeration(participant),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black87,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            color: _isMuted ? Colors.red : Colors.white,
            onPressed: _toggleMute,
          ),
          if (!widget.audioOnly)
            _controlButton(
              icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
              color: _isVideoOff ? Colors.red : Colors.white,
              onPressed: _toggleVideo,
            ),
          _controlButton(
            icon: Icons.call_end,
            color: Colors.red,
            iconSize: 36,
            onPressed: _hangUp,
          ),
        ],
      ),
    );
  }

  void _showFullscreenModeration(lk.Participant participant) {
    final identity = participant.identity;
    if (identity == null) return;
    final audioSid = participant.audioTrackPublications.firstOrNull?.sid;
    final videoSid = participant.videoTrackPublications.firstOrNull?.sid;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Moderar: $identity', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (audioSid != null)
              ListTile(
                leading: const Icon(Icons.mic_off, color: Colors.orange),
                title: const Text('Silenciar micrófono', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _service.muteParticipant(widget.roomName, identity, audioSid, muted: true);
                },
              ),
            if (videoSid != null)
              ListTile(
                leading: const Icon(Icons.videocam_off, color: Colors.orange),
                title: const Text('Apagar cámara', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _service.muteParticipant(widget.roomName, identity, videoSid, muted: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Expulsar (KICK)', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _service.kickParticipant(widget.roomName, identity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Bloquear (Ban)', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _service.banParticipant(widget.roomName, identity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Reportar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (ctx2) => VideoReportDialog(
                    reportedNick: identity,
                    onSubmit: (type, desc) {
                      _service.reports.add(VideoReport(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        conferenceId: widget.roomName,
                        channel: widget.roomName,
                        reporterNick: widget.identity,
                        reportedNick: identity,
                        type: type,
                        description: desc,
                        timestamp: DateTime.now(),
                        status: ReportStatus.pending,
                      ));
                      Navigator.pop(ctx2);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reporte enviado'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double iconSize = 28,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color == Colors.red ? Colors.red : Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color == Colors.red ? Colors.white : color, size: iconSize),
        ),
      ),
    );
  }
}

// Overlay flotante para videollamada que no oculta el chat
class FloatingVideoOverlay {
  FloatingVideoOverlay._();

  static OverlayEntry? _entry;
  static OverlayEntry? _deviceSelectorEntry;
  static LiveKitService? _service;
  static lk.Room? _room;
  static bool _isConnected = false;
  static bool _isMuted = false;
  static bool _isVideoOff = false;
  static String _roomName = '';
  static String _identity = '';
  static bool _audioOnly = false;
  static lk.CancelListenFunc? _roomEventSub;
  static bool _isOwner = false;
  static BuildContext? _overlayContext;
  static IRCService? _ircService;
  static bool _roomLocked = false;
  static bool _connectionFailed = false;
  static bool _isBrave = false;
  static bool _deviceConfigured = false;
  static bool _isExpandedDialogOpen = false;
  static bool _muteOnEntry = false;
  static bool _soundsEnabled = true;
  static bool _screenSharing = false;
  static int _videoQuality = 0; // 0=auto, 1=low, 2=medium, 3=high

  static void show(BuildContext context, String roomName, String identity, {bool audioOnly = false, bool isOwner = false, IRCService? ircService}) {
    hide();
    _roomName = roomName;
    _identity = identity;
    _audioOnly = audioOnly;
    _isConnected = false;
    _isMuted = false;
    _isVideoOff = false;
    _isOwner = isOwner;
    _ircService = ircService;
    _connectionFailed = false;
    _service = LiveKitService();

    _detectBrowser();

    _entry = OverlayEntry(
      builder: (ctx) => _buildOverlayContent(ctx),
    );

    Overlay.of(context).insert(_entry!);

    if (_deviceConfigured) {
      _connect();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_entry != null) _showExpandedDialog();
      });
    } else {
      _showDeviceSelector(context, () {
        _connect();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_entry != null) _showExpandedDialog();
        });
      });
    }
  }

  static Future<void> _detectBrowser() async {
    try {
      final nav = html.window.navigator as dynamic;
      if (nav.brave != null) {
        final brave = nav.brave;
        if (brave != null) {
          final isBrave = await brave.isBrave();
          _isBrave = isBrave == true;
        }
      }
    } catch (_) {}
  }

  static void _showDeviceSelector(BuildContext context, VoidCallback onDone) {
    String? selectedMic;
    String? selectedCam;
    List<html.MediaDeviceInfo> mics = [];
    List<html.MediaDeviceInfo> cams = [];

    html.window.navigator.mediaDevices!.enumerateDevices().then((devices) {
      final all = devices.cast<html.MediaDeviceInfo>();
      mics = all.where((d) => d.kind == 'audioinput').toList();
      cams = all.where((d) => d.kind == 'videoinput').toList();
      selectedMic = mics.isNotEmpty ? mics.first.deviceId : null;
      selectedCam = cams.isNotEmpty ? cams.first.deviceId : null;

      _deviceSelectorEntry?.remove();
      _deviceSelectorEntry = OverlayEntry(
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {}, // consume taps; barrier is modal
                  child: Container(color: Colors.black54),
                ),
              ),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    title: const Text('Configurar dispositivos', style: TextStyle(color: Colors.white)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Micrófono:', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: selectedMic,
                          dropdownColor: const Color(0xFF16213E),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(),
                          ),
                          items: mics.map((m) => DropdownMenuItem(
                            value: m.deviceId,
                            child: Text((m.label ?? '').isNotEmpty ? m.label! : 'Micrófono ${mics.indexOf(m) + 1}', style: const TextStyle(color: Colors.white)),
                          )).toList(),
                          onChanged: (v) => setDialogState(() => selectedMic = v),
                        ),
                        if (!_audioOnly) ...[
                          const SizedBox(height: 12),
                          const Text('Cámara:', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: selectedCam,
                            dropdownColor: const Color(0xFF16213E),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(),
                            ),
                            items: cams.map((c) => DropdownMenuItem(
                              value: c.deviceId,
                              child: Text((c.label ?? '').isNotEmpty ? c.label! : 'Cámara ${cams.indexOf(c) + 1}', style: const TextStyle(color: Colors.white)),
                            )).toList(),
                            onChanged: (v) => setDialogState(() => selectedCam = v),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text('Espacio: mantener presionado para hablar', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          _deviceConfigured = true;
                          _deviceSelectorEntry?.remove();
                          _deviceSelectorEntry = null;
                          onDone();
                        },
                        child: const Text('Unirse', style: TextStyle(color: Colors.cyan)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_deviceSelectorEntry!);
    });
  }

  static Widget _buildOverlayContent(BuildContext ctx) {
    _overlayContext = ctx;
    final participants = _room != null
        ? [_room!.localParticipant!, ..._room!.remoteParticipants.values]
        : <lk.Participant>[];
    final count = participants.length;

    final bottomInset = MediaQuery.of(ctx).size.height < 700 ? 60.0 : 120.0;

    return Positioned(
      right: 12,
      bottom: MediaQuery.of(ctx).padding.bottom + bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _showExpandedDialog,
            child: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 28),
                ),
                if (count > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: hide,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  static void _showExpandedDialog() {
    if (_overlayContext == null) return;
    _isExpandedDialogOpen = true;
    showDialog(
      context: _overlayContext!,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _ExpandedVideoDialog(
        onMinimize: () {
          _isExpandedDialogOpen = false;
          Navigator.of(_overlayContext!).pop();
        },
        onHangUp: () {
          _isExpandedDialogOpen = false;
          final navigator = Navigator.of(_overlayContext!);
          if (navigator.canPop()) navigator.pop();
          hide();
        },
      ),
    ).then((_) => _isExpandedDialogOpen = false);
  }

  static Widget _buildOverlayVideo(List<lk.Participant> participants) {
    if (participants.isEmpty) {
      return const Center(
        child: Text('Esperando...', style: TextStyle(color: Colors.white54)),
      );
    }

    if (participants.length <= 2) {
      return Row(
        children: participants.map((p) {
          final videoPub = p.videoTrackPublications.firstOrNull;
          final isLocal = p is lk.LocalParticipant;
          final isVideoMuted = isLocal ? _isVideoOff : (videoPub?.muted ?? true);
          final videoTrack = videoPub?.track as lk.VideoTrack?;
          return Expanded(
            child: _buildOverlayTile(p, videoTrack, isVideoMuted, isLocal),
          );
        }).toList(),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.5,
      ),
      itemCount: participants.length,
      itemBuilder: (_, i) {
        final p = participants[i];
        final videoPub = p.videoTrackPublications.firstOrNull;
        final isLocal = p is lk.LocalParticipant;
        final isVideoMuted = isLocal ? _isVideoOff : (videoPub?.muted ?? true);
        final videoTrack = videoPub?.track as lk.VideoTrack?;
        return _buildOverlayTile(p, videoTrack, isVideoMuted, isLocal);
      },
    );
  }

  static Widget _buildOverlayTile(lk.Participant p, lk.VideoTrack? videoTrack, bool isVideoMuted, bool isLocal) {
    final identity = p.identity ?? '?';
    final isOwner = _isOwner && !isLocal;
    final isTargetOwner = _isOwner && isLocal;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: p.isSpeaking
            ? Border.all(color: Colors.greenAccent.withOpacity(0.6), width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          videoTrack != null && !isVideoMuted
              ? lk.VideoTrackRenderer(
                  videoTrack,
                  fit: lk.VideoViewFit.contain,
                  mirrorMode: isLocal ? lk.VideoViewMirrorMode.mirror : lk.VideoViewMirrorMode.auto,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        identity,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
          if (!isLocal && _isOwner)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _showModerationMenu(p),
                child: _overlayBadge(Icons.more_vert, Colors.amber, 'Moderar'),
              ),
            ),
          if (isLocal && _isOwner)
            Positioned(
              top: 4,
              left: 4,
              child: _overlayBadge(Icons.shield, Colors.amber, 'Tú (Dueño)'),
            ),
        ],
      ),
    );
  }

  static Widget _overlayBadge(IconData icon, Color color, String tooltip) {
    return Container(
      margin: const EdgeInsets.only(left: 2),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color, size: 14),
      ),
    );
  }

  static OverlayEntry? _menuEntry;

  /// Extract IRC channel name from video room name (e.g. "channel_mexico_123" -> "#mexico")
  static String? _getChannelFromRoomName() {
    if (_roomName.startsWith('channel_')) {
      final withoutPrefix = _roomName.substring(8);
      final lastUnderscore = withoutPrefix.lastIndexOf('_');
      if (lastUnderscore > 0) {
        return '#${withoutPrefix.substring(0, lastUnderscore)}';
      }
    }
    return null;
  }

  static bool _isPrivateCall() => _roomName.startsWith('globalchat-private-');

  static void _showModerationMenu(lk.Participant participant) {
    if (_entry == null || _overlayContext == null) return;
    final identity = participant.identity;
    if (identity == null) return;
    final videoTrackSid = participant.videoTrackPublications.firstOrNull?.sid;
    final audioTrackSid = participant.audioTrackPublications.firstOrNull?.sid;
    final isPrivate = _isPrivateCall();
    final channel = isPrivate ? null : _getChannelFromRoomName();

    _menuEntry?.remove();
    _menuEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        onTap: _hideModerationMenu,
        child: Material(
          color: Colors.black38,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Moderar: $identity',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (audioTrackSid != null)
                    ListTile(
                      leading: const Icon(Icons.mic_off, color: Colors.orange),
                      title: const Text('Silenciar micrófono', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _hideModerationMenu();
                        _service?.muteParticipant(_roomName, identity, audioTrackSid, muted: true);
                      },
                    ),
                  if (videoTrackSid != null)
                    ListTile(
                      leading: const Icon(Icons.videocam_off, color: Colors.orange),
                      title: const Text('Apagar cámara', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        _hideModerationMenu();
                        _service?.muteParticipant(_roomName, identity, videoTrackSid, muted: true);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.person_remove, color: Colors.red),
                    title: Text(isPrivate ? 'Desconectar' : 'Expulsar (KICK)', style: const TextStyle(color: Colors.red)),
                    onTap: () {
                      _hideModerationMenu();
                      _service?.kickParticipant(_roomName, identity);
                      if (!isPrivate && channel != null && _ircService != null) {
                        _ircService!.kickUser(channel, identity, 'Expulsado de la videoconferencia');
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: Text(isPrivate ? 'Bloquear' : 'Bloquear (Ban + KICK)', style: const TextStyle(color: Colors.red)),
                    onTap: () {
                      _hideModerationMenu();
                      _service?.banParticipant(_roomName, identity);
                      if (!isPrivate && channel != null && _ircService != null) {
                        _ircService!.banUser(channel, identity);
                        _ircService!.kickUser(channel, identity, 'Baneado de la videoconferencia');
                      }
                    },
                  ),
                  if (!isPrivate)
                    ListTile(
                      leading: const Icon(Icons.list, color: Colors.white54),
                      title: const Text('Ver baneados', style: TextStyle(color: Colors.white70)),
                      onTap: () {
                        _hideModerationMenu();
                        _showBannedUsers();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.flag, color: Colors.orange),
                    title: const Text('Reportar', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      _hideModerationMenu();
                      if (_overlayContext == null) return;
                      showDialog(
                        context: _overlayContext!,
                        builder: (ctx) => VideoReportDialog(
                          reportedNick: identity,
                          onSubmit: (type, desc) {
                            if (_service != null) {
                              _service!.reports.add(VideoReport(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                conferenceId: _roomName,
                                channel: _roomName,
                                reporterNick: _identity,
                                reportedNick: identity,
                                type: type,
                                description: desc,
                                timestamp: DateTime.now(),
                                status: ReportStatus.pending,
                              ));
                            }
                            Navigator.pop(ctx);
                            if (_overlayContext != null) {
                              ScaffoldMessenger.of(_overlayContext!).showSnackBar(
                                const SnackBar(content: Text('Reporte enviado'), duration: Duration(seconds: 2)),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(_overlayContext!).insert(_menuEntry!);
  }

  static void _showBannedUsers() {
    if (_overlayContext == null) return;
    final channel = _getChannelFromRoomName();
    if (channel == null) return;
    showDialog(
      context: _overlayContext!,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Baneados de la videoconferencia', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<String>>(
            future: _service?.listBans(_roomName) ?? Future.value(<String>[]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final bans = snapshot.data ?? [];
              if (bans.isEmpty) {
                return const Text('No hay usuarios baneados', style: TextStyle(color: Colors.white54));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final nick in bans)
                    ListTile(
                      dense: true,
                      title: Text(nick, style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.lock_open, color: Colors.orange, size: 20),
                        tooltip: 'Desbanear',
                        onPressed: () {
                          _service?.unbanParticipant(_roomName, nick);
                          if (_ircService != null) _ircService!.unbanUser(channel, nick);
                          Navigator.pop(ctx);
                          _showBannedUsers();
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  static void _hideModerationMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  static Widget _overlayBtn(IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color == Colors.red ? Colors.red : Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color == Colors.red ? Colors.white : color, size: 20),
        ),
      ),
    );
  }

  static Future<void> reconnectIfNeeded() async {
    if (_roomName.isEmpty || _identity.isEmpty) return;
    if (_isConnected) return;
    if (_service == null) _service = LiveKitService();
    await _connect();
    _isReconnecting = false;
    if (_entry != null) _entry!.markNeedsBuild();
  }

  static void hide() {
    _hideModerationMenu();
    _roomEventSub?.call();
    _roomEventSub = null;
    if (_isExpandedDialogOpen && _overlayContext != null) {
      _isExpandedDialogOpen = false;
      try {
        final navigator = Navigator.of(_overlayContext!);
        if (navigator.canPop()) navigator.pop();
      } catch (_) {}
    }
    _entry?.remove();
    _entry = null;
    _deviceSelectorEntry?.remove();
    _deviceSelectorEntry = null;
    _isConnected = false;
    _isOwner = false;
    _connectionFailed = false;
    _roomLocked = false;
    if (_service != null) {
      try {
        _service!.leaveConference().catchError((_) {});
      } catch (_) {}
      _service = null;
    }
    _room = null;
  }

  static bool _isReconnecting = false;

  static Future<void> _connect() async {
    if (_service == null) return;
    _connectionFailed = false;
    _isReconnecting = false;
    try {
      final connected = await _service!.connectToRoom(_roomName, _identity, isOwner: _isOwner);
      _isConnected = connected;
      _connectionFailed = !connected;
      _room = _service!.room;
      if (connected && _service!.localParticipant != null) {
        try {
          final shouldMute = _service!.defaultMute;
          await _service!.localParticipant!.setMicrophoneEnabled(!shouldMute);
          _isMuted = shouldMute;
          if (!_audioOnly) {
            await _service!.localParticipant!.setCameraEnabled(true);
          } else {
            await _service!.localParticipant!.setCameraEnabled(false);
            _isVideoOff = true;
          }
        } catch (_) {}
      }
      _syncMuteState();
      _roomEventSub?.call();
      _roomEventSub = _room?.events.listen((event) {
        _syncMuteState();
        _entry?.markNeedsBuild();
        if (event is lk.RoomDisconnectedEvent && _isConnected && !_isReconnecting) {
          _isReconnecting = true;
          _isConnected = false;
          _connectionFailed = true;
          _entry?.markNeedsBuild();
          Future.delayed(const Duration(seconds: 3), () {
            if (!_isConnected && !_isReconnecting && _roomName.isNotEmpty) {
              _isReconnecting = false;
              reconnectIfNeeded();
            }
          });
        }
      });
    } catch (e) {
      _isConnected = false;
      _connectionFailed = true;
    }
    _entry?.markNeedsBuild();
  }

  static void _syncMuteState() {
    final local = _service?.localParticipant;
    if (local == null) return;
    final audioPub = local.audioTrackPublications.firstOrNull;
    if (audioPub != null) {
      _isMuted = audioPub.muted;
    }
    final videoPub = local.videoTrackPublications.firstOrNull;
    if (videoPub != null) {
      _isVideoOff = videoPub.muted;
    }
  }

  static void _toggleMute() {
    _isMuted = !_isMuted;
    _service?.localParticipant?.setMicrophoneEnabled(!_isMuted);
    _entry?.markNeedsBuild();
  }

  static void _toggleVideo() {
    if (_audioOnly) return;
    _isVideoOff = !_isVideoOff;
    _service?.localParticipant?.setCameraEnabled(!_isVideoOff);
    _entry?.markNeedsBuild();
  }
}

class _ExpandedVideoDialog extends StatefulWidget {
  final VoidCallback onMinimize;
  final VoidCallback onHangUp;

  const _ExpandedVideoDialog({
    required this.onMinimize,
    required this.onHangUp,
  });

  @override
  State<_ExpandedVideoDialog> createState() => _ExpandedVideoDialogState();
}

class _ExpandedVideoDialogState extends State<_ExpandedVideoDialog> with TickerProviderStateMixin {
  lk.CancelListenFunc? _roomSub;
  _VideoLayout _layout = _VideoLayout.auto;
  bool _hideNoVideo = false;
  bool _showPanel = false;
  bool _showChat = true;
  bool _showEmojiPicker = false;
  bool _isScreenSharing = false;
  bool _handRaised = false;
  bool _showStats = false;
  bool _backgroundBlurEnabled = false;
  int? _focusedIndex;
  final TextEditingController _chatMessageController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();

  // Timer
  final DateTime _callStart = DateTime.now();
  Timer? _callTimer;
  Timer? _durationNotifTimer;
  Timer? _statsTimer;
  Duration _callDuration = Duration.zero;
  Map<String, dynamic> _networkStats = {};

  // Reactions
  final List<_ReactionBubble> _reactions = [];
  final GlobalKey _scaffoldKey = GlobalKey();

  // Remote hands (identity -> raised)
  final Map<String, bool> _remoteHands = {};

  void _playSound(String action) {
    try {
      final audio = html.AudioElement();
      final joinB64 = 'UklGRkQDAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YSADAAB/uub26L2CRhkHFD13s+L268SKTR0HEDZvrN317sqRVCIIDjFopdn08c+ZWycKCythntPy89WgYiwMCSZZl87w9NqnajIOCCFSj8jt9t6ucTgRBxxLiMLq9uO1eT4UBxhFgLzn9+e8gEUYBxQ+ebXj9urCiEscBxE4ca7e9u3Ij1IhCA4yaqfa9PDOl1kmCQwsYqDV8/LTnmErCwonW5nP8fTZpWgxDggiVJHK7vXdrG82EAcdTYrE6/bis3c9FAcZRoK96Pbmun9DFwcVQHu35PbpwIZKGwcSOXOw4Pbtx45RIAgPM2yp2/XvzJVYJAkMLmSi1vPy0pxfKgsKKF2b0fH016RmLw0JI1aTy+/13KtuNRAHH0+Mxez24bJ1OxMHGkiEv+n25bh9QRYHFkF9uOX26b+ESBoHEzt1suH27MWMTx8HEDVuq9z178uTViMJDS9mpNf08dGbXSgKCypfnNLy89aiZC4MCSRYlczv9dupbDMPCCBRjsft9uCwczkSBxtKhsDp9uS3e0AVBxdDfrrm9ui9gkYZBxQ9d7Pi9uvEik0dBxA2b6zd9e7KkVQiCA4xaKXZ9PHPmVsnCgsrYZ7T8vPVoGIsDAkmWZfO8PTap2oyDgghUo/I7fbernE4EQccS4jC6vbjtXk+FAcYRYC85/fnvIBFGAcUPnm14/bqwohLHAcROHGu3fbtyI9SIQgOMmqn2vTwzpdZJgkMLGKg1fPy055hKwsKJ1uZz/H02aVoMQ4IIlSRyu713axvNhAHHU2KxOv24rN3PRQHGUaCvej25rp/QxcHFUB7t+T26cCGShsHEjlzsOD27ceOUSAIDzNsqdv178yVWCQJDC5kotbz8tKcXyoLCihdm9Hx9NekZi8NCSNWk8vv9dyrbjUQBx9PjMXs9uGydTsTBxpIhL/p9uW4fUEWBxZBfbjl9um/hEgaBxM7dbLh9uzFjE8fBxA1bqvc9e/Lk1YjCQ0vZqTX9PHRm10oCgsqX5zS8vPWomQuDAkkWJXM7/XbqWwzDwggUY7H7fbgsHM5EgcbSobA6fbkt3tAFQcXQw==';
      final leaveB64 = 'UklGRkQDAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YSADAAB/p8vm9PXozquCWTUZCQcULE93oMXi8/br07KKYTsdCwcQJ0hvmb/d8fbu2biRaEEiDgcOIkFokbjZ7vbx3b+Zb0gnEAcLHTthirLT6/bz4sWgd08sFAcJGTVZgqvO6PX05sunflYyFwkIFS9Se6TI5PT26dGuhl04GwoHEipLc5zC4PL27da1jmQ+IAwHDyRFbJW82+/379u8lWxFJA8HDCA+ZI611u328uDCnHNLKhIHChs4XYau0en29OTIpHtSLxUICRcyVn+ny+b09ejOq4JZNRkJBxQsT3egxeLz9uvTsophOx0LBxAnSG+Zv93x9u7ZuJFoQSIOBw4iQWiRuNnu9vHdv5lvSCcQBwsdO2GKstPr9vPixaB3TywUBwkZNVmCq87o9fTmy6d/VjIXCQgVL1J7pMjk9Pbp0a6GXTgbCgcSKktznMLg8vbt1rWOZD4gDAcPJEVslbzb7/fv27yVbEUkDwcMID5kjrXW7fby4MKcc0sqEgcKGzhdhq7R6fb05Mike1IvFQgJFzJWf6fL5vT16M6rglk1GQkHFCxPd6DF4vP269OyimE7HQsHECdIb5m/3fH27tm4kWhBIg4HDiJBaJG42e728d2/mW9IJxAHCx07YYqy0+v28+LFoHdPLBQHCRk1WYKrzuj19ObLp35WMhcJCBUvUnukyOT09unRroZdOBsKBxIqS3OcwuDy9u3WtY5kPiAMBw8kRWyVvNvv9+/bvJVsRSQPBwwgPmSOtdbt9vLgwpxzSyoSBwobOF2GrtHp9vTkyKR7Ui8VCAkXMlZ+p8vm9PXozquCWTUZCQcULE93oMXi8/br07KKYTsdCwcQJ0hvmb/d8fbu2biRaEEiDgcOIkFokbjZ7vbx3b+Zb0gnEAcLHTthirLT6/bz4sWgd08sFAcJGTVZgqvO6PX05sunflYyFwkIFS9Se6TI5PT26dGuhl04GwoHEipLc5zC4PL27da1jmQ+IAwHDyRFbJW82+/379u8lWxFJA8HDCA+ZI611u328uDCnHNLKhIHChs4XYau0en29OTIpHtSLxUICRcyVg==';
      audio.src = 'data:audio/wav;base64,${action == 'join' ? joinB64 : leaveB64}';
      if (!FloatingVideoOverlay._soundsEnabled) return;
      audio.volume = 0.15;
      audio.play();
    } catch (_) {}
  }

  String? _lastDominantSpeaker;
  html.EventListener? _keyDownListener;
  html.EventListener? _keyUpListener;

  @override
  void initState() {
    super.initState();

    _keyDownListener = (e) {
      if ((e as html.KeyboardEvent).key == ' ' && !_chatFocusNode.hasFocus) {
        FloatingVideoOverlay._isMuted = false;
        FloatingVideoOverlay._service?.localParticipant?.setMicrophoneEnabled(true);
        setState(() {});
      }
    };
    _keyUpListener = (e) {
      if ((e as html.KeyboardEvent).key == ' ' && !_chatFocusNode.hasFocus) {
        FloatingVideoOverlay._isMuted = true;
        FloatingVideoOverlay._service?.localParticipant?.setMicrophoneEnabled(false);
        setState(() {});
      }
    };
    html.window.addEventListener('keydown', _keyDownListener!);
    html.window.addEventListener('keyup', _keyUpListener!);

    _syncScreenShare();
    if (FloatingVideoOverlay._isConnected) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _chatFocusNode.requestFocus());
    }
    _roomSub = FloatingVideoOverlay._room?.events.listen((event) {
      FloatingVideoOverlay._syncMuteState();
      _syncScreenShare();
      if (event is lk.DataReceivedEvent) {
        _handleDataReceived(event);
      }
      if (event is lk.ParticipantConnectedEvent) {
        if (FloatingVideoOverlay._roomLocked) {
          final newP = event.participant;
          if (newP.identity != null) {
            FloatingVideoOverlay._service?.kickParticipant(
              FloatingVideoOverlay._roomName, newP.identity!,
            );
          }
        } else {
          _playSound('join');
          if (FloatingVideoOverlay._muteOnEntry) {
            final audioSid = event.participant.audioTrackPublications.firstOrNull?.sid;
            if (audioSid != null && event.participant.identity != null) {
              FloatingVideoOverlay._service?.muteParticipant(
                FloatingVideoOverlay._roomName, event.participant.identity!, audioSid, muted: true,
              );
            }
          }
        }
      }
      if (event is lk.ParticipantDisconnectedEvent) {
        _playSound('leave');
      }
      if (event is lk.ActiveSpeakersChangedEvent) {
        final nonLocal = event.speakers.where((p) => p is! lk.LocalParticipant).toList();
        if (nonLocal.isNotEmpty) {
          final speaker = nonLocal.first;
          if (speaker.identity != _lastDominantSpeaker) {
            _lastDominantSpeaker = speaker.identity;
            final room = FloatingVideoOverlay._room;
            if (room != null) {
              final participants = <lk.Participant>[
                if (room.localParticipant != null) room.localParticipant!,
                ...?room.remoteParticipants.values,
              ];
              _focusedIndex = participants.indexOf(speaker);
            }
          }
        }
      }
      if (mounted) setState(() {});
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration = DateTime.now().difference(_callStart));
    });
    _durationNotifTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (!mounted) return;
      final mins = DateTime.now().difference(_callStart).inMinutes;
      if (mounted && _scaffoldKey.currentContext != null) {
        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('Llamada en curso: $mins minutos'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final stats = await FloatingVideoOverlay._service?.getNetworkStats() ?? {};
      if (mounted) setState(() => _networkStats = stats);
    });
  }

  @override
  void dispose() {
    if (_keyDownListener != null) html.window.removeEventListener('keydown', _keyDownListener!);
    if (_keyUpListener != null) html.window.removeEventListener('keyup', _keyUpListener!);
    _roomSub?.call();
    _callTimer?.cancel();
    _durationNotifTimer?.cancel();
    _statsTimer?.cancel();
    _chatMessageController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = FloatingVideoOverlay._room;
    final connected = FloatingVideoOverlay._isConnected;
    final mins = _callDuration.inMinutes;
    final secs = _callDuration.inSeconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.keyM): () {
          if (!_chatFocusNode.hasFocus) {
            FloatingVideoOverlay._toggleMute();
            setState(() {});
          }
        },
        SingleActivator(LogicalKeyboardKey.keyV): () {
          if (!_chatFocusNode.hasFocus && !FloatingVideoOverlay._audioOnly) {
            FloatingVideoOverlay._toggleVideo();
            setState(() {});
          }
        },
        SingleActivator(LogicalKeyboardKey.keyS): () {
          if (!_chatFocusNode.hasFocus) _toggleScreenShare();
        },
        SingleActivator(LogicalKeyboardKey.escape): () => widget.onMinimize(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.minimize, color: Colors.white),
              tooltip: 'Minimizar (Esc)',
              onPressed: widget.onMinimize,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _connectionQualityIcon(),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        FloatingVideoOverlay._roomName,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                  ],
                ),
                Text(
                  _layoutLabel(_layout),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white70),
                tooltip: 'Pantalla completa',
                onPressed: _toggleFullScreen,
              ),
              IconButton(
                icon: Icon(
                  _hideNoVideo ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                tooltip: 'Ocultar recuadros sin video',
                onPressed: () => setState(() => _hideNoVideo = !_hideNoVideo),
              ),
              IconButton(
                icon: const Icon(Icons.grid_view, color: Colors.white70),
                tooltip: 'Cambiar diseño',
                onPressed: _nextLayout,
              ),
              IconButton(
                icon: Icon(Icons.people, color: _showPanel ? Colors.amber : Colors.white70),
                tooltip: 'Participantes',
                onPressed: () => setState(() => _showPanel = !_showPanel),
              ),
              IconButton(
                icon: const Icon(Icons.call_end, color: Colors.red),
                tooltip: 'Colgar',
                onPressed: widget.onHangUp,
              ),
            ],
          ),
          body: connected && room != null
              ? Stack(
                  children: [
                    LayoutBuilder(builder: (ctx, c) => _buildVideoGrid(room, c)),
                    if (_showStats)
                      _buildStatsPanel(),
                    if (_showPanel)
                      _buildParticipantsPanel(room),
                    if (_showChat)
                      _buildChatPanel(),
                    ..._reactions.map((r) => _buildReactionBubble(r)),
                  ],
                )
              : _buildConnectionStatus(),
          bottomNavigationBar: _buildControls(),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (FloatingVideoOverlay._connectionFailed) {
      final isBrave = FloatingVideoOverlay._isBrave;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 64),
              const SizedBox(height: 16),
              Text(
                'No se pudo conectar a la videoconferencia',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (isBrave)
                const Text(
                  'Brave bloquea WebRTC por privacidad.\n'
                  'Abre el menú de Shields (icono 🛡️)\n'
                  'y desactívalas para este sitio.',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  FloatingVideoOverlay._connectionFailed = false;
                  FloatingVideoOverlay._connect();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  // --- Chat panel ---
  Widget _buildChatPanel() {
    return Positioned(
      right: 0, top: 0, bottom: 0,
      child: Material(
        elevation: 8,
        child: Consumer(
          builder: (context, ref, _) {
            final currentChannel = ref.watch(currentChannelProvider);
            final allMessages = ref.watch(messagesProvider);
            final ircService = ref.watch(ircServiceProvider);

            // Detect private call: use remote participant's nick as chat target
            final isPrivate = FloatingVideoOverlay._roomName.startsWith('globalchat-private-');
            final remoteNick = isPrivate
                ? FloatingVideoOverlay._room?.remoteParticipants.values.firstOrNull?.identity
                : null;
            final chatTarget = remoteNick ?? currentChannel;

            final channelMessages = chatTarget != null
                ? allMessages
                    .where((m) =>
                        m.channel.toLowerCase().trim() == chatTarget.toLowerCase().trim())
                    .toList()
                : <IRCMessage>[];

            return Container(
              width: 460,
              color: const Color(0xFF16213E),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.chat, color: Colors.white54, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            chatTarget ?? 'Chat',
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 22),
                          onPressed: () => setState(() => _showChat = false),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 12),
                  // Messages list
                  Expanded(
                    child: channelMessages.isEmpty
                        ? const Center(
                            child: Text(
                              'Sin mensajes',
                              style: TextStyle(color: Colors.white24, fontSize: 15),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: channelMessages.length,
                            itemBuilder: (_, i) {
                              final msg = channelMessages[channelMessages.length - 1 - i];
                              return _buildChatMessage(msg);
                            },
                          ),
                  ),
                  const Divider(color: Colors.white12, height: 4),
                  // Input
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatMessageController,
                            focusNode: _chatFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: chatTarget != null
                                  ? (isPrivate ? 'Mensaje a $chatTarget...' : 'Enviar a $chatTarget...')
                                  : 'Selecciona un canal...',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
                              filled: true,
                              fillColor: Colors.white10,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: chatTarget != null
                                ? (value) => _sendChatMessage(ircService, chatTarget, isPrivate)
                                : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: Colors.white70, size: 24),
                          onPressed: chatTarget != null
                              ? () => _sendFile(ircService, chatTarget, isPrivate)
                              : null,
                        ),
                        IconButton(
                          icon: Icon(
                            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                            color: _showEmojiPicker ? Colors.amber : Colors.white70,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() => _showEmojiPicker = !_showEmojiPicker);
                            if (_showEmojiPicker) {
                              Future.delayed(const Duration(milliseconds: 100), () {
                                _chatFocusNode.requestFocus();
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white70, size: 24),
                          onPressed: chatTarget != null
                              ? () => _sendChatMessage(ircService, chatTarget, isPrivate)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 300,
                      child: EmojiPicker(
                        appTheme: ref.watch(themeProvider),
                        onEmojiSelected: (emojiCode) {
                          final currentText = _chatMessageController.text;
                          final cursorPosition = _chatMessageController.selection.baseOffset;
                          final newText = cursorPosition >= 0
                              ? '${currentText.substring(0, cursorPosition)}$emojiCode${currentText.substring(cursorPosition)}'
                              : '$currentText$emojiCode';
                          _chatMessageController.text = newText;
                          _chatMessageController.selection = TextSelection.collapsed(
                            offset: (cursorPosition >= 0 ? cursorPosition : currentText.length) + emojiCode.length,
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_chatFocusNode.canRequestFocus) {
                              _chatFocusNode.requestFocus();
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _sendChatMessage(IRCService ircService, String target, [bool isPrivate = false]) {
    final text = _chatMessageController.text.trim();
    if (text.isEmpty) return;
    if (isPrivate) {
      ircService.sendPrivateMessage(target, text);
    } else {
      ircService.sendMessage(target, text);
    }
    _chatMessageController.clear();
  }

  Future<void> _sendFile(IRCService ircService, String target, bool isPrivate) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final sizeStr = file.size > 1024 * 1024
          ? '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '${(file.size / 1024).toStringAsFixed(1)} KB';
      final msg = '📁 ${file.name} ($sizeStr)';
      if (isPrivate) {
        ircService.sendPrivateMessage(target, msg);
      } else {
        ircService.sendMessage(target, msg);
      }
    } catch (_) {}
  }

  Widget _buildChatMessage(IRCMessage msg) {
    final time = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$time ',
              style: const TextStyle(color: Colors.white24, fontSize: 13),
            ),
            if (!msg.isSystem)
              TextSpan(
                text: '<${msg.nick}> ',
                style: TextStyle(
                  color: Colors.primaries[msg.nick.hashCode.abs() % Colors.primaries.length].shade200,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            TextSpan(
              text: msg.isSystem ? '${msg.nick} ${msg.message}' : msg.message,
              style: TextStyle(
                color: msg.isSystem ? Colors.white38 : Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Keyboard shortcuts label ---
  String get _shortcutsHint => 'M:mic V:cam S:pantalla Esc:minimizar';

  // --- Fullscreen ---
  void _toggleFullScreen() {
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    } else {
      html.document.documentElement?.requestFullscreen();
    }
  }

  // --- Timer ---
  void _syncScreenShare() {
    final local = FloatingVideoOverlay._room?.localParticipant;
    if (local == null) return;
    final screenPub = local.videoTrackPublications.where((pub) => pub.isScreenShare).firstOrNull;
    _isScreenSharing = screenPub != null && !screenPub.muted;
  }

  void _toggleScreenShare() async {
    final local = FloatingVideoOverlay._room?.localParticipant;
    if (local == null) return;
    try {
      if (_isScreenSharing) {
        await local.setSourceEnabled(lk.TrackSource.screenShareVideo, false);
        await local.setSourceEnabled(lk.TrackSource.screenShareAudio, false);
        setState(() => _isScreenSharing = false);
      } else {
        await local.setSourceEnabled(lk.TrackSource.screenShareVideo, true);
        await local.setSourceEnabled(lk.TrackSource.screenShareAudio, true);
        setState(() => _isScreenSharing = true);
      }
    } catch (e) {
      debugPrint('Screen share error: $e');
    }
  }

  // --- Raise hand ---
  void _toggleHand() {
    setState(() {
      _handRaised = !_handRaised;
      // Broadcast via data channel
      try {
        FloatingVideoOverlay._room?.localParticipant?.publishData(
          utf8.encode(json.encode({'type': 'hand', 'raised': _handRaised})),
          topic: 'hand',
        );
      } catch (_) {}
    });
  }

  // --- Reactions ---
  static const _reactionEmojis = ['👍', '❤️', '😮', '😂', '🎉', '👏'];

  void _addReaction(String emoji) {
    final id = DateTime.now().millisecondsSinceEpoch;
    final bubble = _ReactionBubble(id: id, emoji: emoji, createdAt: DateTime.now());
    setState(() => _reactions.add(bubble));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _reactions.removeWhere((r) => r.id == id));
    });
    // Broadcast via LiveKit data channel
    try {
      FloatingVideoOverlay._room?.localParticipant?.publishData(
        utf8.encode(json.encode({'type': 'reaction', 'emoji': emoji})),
        topic: 'reaction',
      );
    } catch (_) {}
  }

  // --- Data channel receive ---
  void _handleDataReceived(lk.DataReceivedEvent e) {
    final data = String.fromCharCodes(e.data);
    final from = e.participant?.identity;
    if (from == null) return;
    try {
      final msg = json.decode(data) as Map<String, dynamic>;
      switch (msg['type'] as String?) {
        case 'reaction':
          final emoji = msg['emoji'] as String?;
          if (emoji != null) _addReaction(emoji);
        case 'hand':
          final raised = msg['raised'] as bool? ?? false;
          if (raised && from != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✋ $from levantó la mano'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _remoteHands[from] = raised;
      }
    } catch (_) {}
  }

  // --- Invite to channel ---
  void _sendInvite() {
    final ircService = FloatingVideoOverlay._ircService;
    final roomName = FloatingVideoOverlay._roomName;
    final identity = FloatingVideoOverlay._identity;
    if (ircService == null) return;

    final isPrivate = roomName.startsWith('globalchat-private-');
    if (isPrivate) return;

    try {
      final channel = FloatingVideoOverlay._getChannelFromRoomName();
      if (channel == null) return;
      ircService.sendMessage(
        channel,
        '🎥  $identity está en videoconferencia  ·  [room:$roomName] · ${getVideoRoomUrl(roomName)}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitación enviada al canal'), duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {}
  }

  // --- Copy meeting link ---
  void _copyMeetingLink() {
    final roomName = FloatingVideoOverlay._roomName;
    final url = getVideoRoomUrl(roomName);
    try {
      Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enlace copiado al portapapeles'), duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo copiar el enlace'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  // --- Toggle sounds ---
  void _toggleSounds() {
    FloatingVideoOverlay._soundsEnabled = !FloatingVideoOverlay._soundsEnabled;
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FloatingVideoOverlay._soundsEnabled ? 'Sonidos activados' : 'Sonidos desactivados'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Toggle mute on entry (owner only) ---
  void _toggleMuteOnEntry() async {
    final service = FloatingVideoOverlay._service;
    final roomName = FloatingVideoOverlay._roomName;
    final identity = FloatingVideoOverlay._identity;
    if (service == null || roomName.isEmpty || identity.isEmpty) return;
    final newValue = !FloatingVideoOverlay._muteOnEntry;
    final ok = await service.setDefaultMute(roomName, newValue, identity: identity);
    if (ok && mounted) {
      setState(() => FloatingVideoOverlay._muteOnEntry = newValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue
            ? 'Nuevos participantes entrarán muteados'
            : 'Nuevos participantes entrarán con micrófono activo'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Cycle video quality ---
  void _cycleVideoQuality() async {
    final next = (FloatingVideoOverlay._videoQuality + 1) % 4;
    final room = FloatingVideoOverlay._room;
    if (room == null) return;
    final quality = switch (next) {
      1 => lk.VideoQuality.LOW,
      2 => lk.VideoQuality.MEDIUM,
      3 => lk.VideoQuality.HIGH,
      _ => null,
    };
    if (quality != null) {
      for (final p in room.remoteParticipants.values) {
        for (final pub in p.videoTrackPublications.where((pub) => !pub.isScreenShare)) {
          if (pub is lk.RemoteTrackPublication) {
            await pub.setVideoQuality(quality);
          }
        }
      }
    }
    if (mounted) {
      setState(() => FloatingVideoOverlay._videoQuality = next);
      final label = next == 0 ? 'Auto' : next == 1 ? 'Baja' : next == 2 ? 'Media' : 'Alta';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calidad de video: $label'), duration: const Duration(seconds: 1)),
      );
    }
  }

  // --- Toggle background blur ---
  void _toggleBackgroundBlur() async {
    final enabled = await FloatingVideoOverlay._service?.toggleBackgroundBlur() ?? false;
    if (mounted) setState(() => _backgroundBlurEnabled = enabled);
  }

  // --- Toggle stats panel ---
  void _toggleStatsPanel() => setState(() => _showStats = !_showStats);

  // --- End call for all (owner only) ---
  void _endCallForAll() {
    final room = FloatingVideoOverlay._room;
    if (room == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Finalizar llamada', style: TextStyle(color: Colors.white)),
        content: const Text('¿Finalizar la llamada para todos los participantes?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Mute local tracks first so the owner disconnects cleanly.
              final local = FloatingVideoOverlay._service?.localParticipant;
              try {
                final audioPub = local?.audioTrackPublications.firstOrNull;
                if (audioPub != null) await audioPub.mute();
              } catch (_) {}
              try {
                final videoPub = local?.videoTrackPublications.firstOrNull;
                if (videoPub != null) await videoPub.mute();
              } catch (_) {}
              // Ask the server to remove everyone and end the room.
              await FloatingVideoOverlay._service?.endRoomForAll(FloatingVideoOverlay._roomName);
              // Give the server a moment, then force-hide locally.
              await Future.delayed(const Duration(milliseconds: 300));
              FloatingVideoOverlay.hide();
            },
            child: const Text('Finalizar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- Mute all participants ---
  void _muteAll() {
    final room = FloatingVideoOverlay._room;
    if (room == null) return;
    for (final p in room.remoteParticipants.values) {
      final sid = p.audioTrackPublications.firstOrNull?.sid;
      if (sid != null) {
        FloatingVideoOverlay._service?.muteParticipant(
          FloatingVideoOverlay._roomName, p.identity ?? '', sid, muted: true,
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos silenciados'), duration: Duration(seconds: 1)),
      );
    }
  }

  // --- Disable camera for all participants ---
  void _cameraAll() {
    final room = FloatingVideoOverlay._room;
    if (room == null) return;
    for (final p in room.remoteParticipants.values) {
      final sid = p.videoTrackPublications.firstOrNull?.sid;
      if (sid != null) {
        FloatingVideoOverlay._service?.muteParticipant(
          FloatingVideoOverlay._roomName, p.identity ?? '', sid, muted: true,
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cámaras apagadas'), duration: Duration(seconds: 1)),
      );
    }
  }

  // --- Toggle room lock ---
  void _toggleLock() {
    FloatingVideoOverlay._roomLocked = !FloatingVideoOverlay._roomLocked;
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FloatingVideoOverlay._roomLocked ? 'Sala bloqueada' : 'Sala abierta'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // --- Remove room password ---
  void _removePassword() {
    FloatingVideoOverlay._service?.removeRoomPassword(
      FloatingVideoOverlay._roomName,
      identity: FloatingVideoOverlay._identity,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña eliminada'), duration: Duration(seconds: 1)),
      );
    }
  }

  // --- Small icon button for global actions ---
  Widget _smallBtn(IconData icon, String tooltip, VoidCallback onPressed, {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color ?? Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
      ),
    );
  }

  void _nextLayout() {
    setState(() {
      _layout = _VideoLayout.values[(_layout.index + 1) % _VideoLayout.values.length];
      _focusedIndex = null;
    });
  }

  Widget _connectionQualityIcon() {
    final quality = FloatingVideoOverlay._room?.localParticipant?.connectionQuality;
    if (quality == null) return const SizedBox.shrink();
    IconData icon;
    Color color;
    switch (quality) {
      case lk.ConnectionQuality.excellent:
        icon = Icons.signal_cellular_4_bar; color = Colors.greenAccent;
      case lk.ConnectionQuality.good:
        icon = Icons.signal_cellular_4_bar; color = Colors.lime;
      case lk.ConnectionQuality.poor:
        icon = Icons.signal_cellular_0_bar; color = Colors.orange;
      case lk.ConnectionQuality.unknown:
        icon = Icons.signal_cellular_off; color = Colors.white24;
      case lk.ConnectionQuality.lost:
        icon = Icons.signal_cellular_off; color = Colors.red;
    }
    return Tooltip(
      message: 'Calidad: ${quality.name}',
      child: Icon(icon, color: color, size: 16),
    );
  }

  String _layoutLabel(_VideoLayout l) {
    switch (l) {
      case _VideoLayout.auto: return 'Auto';
      case _VideoLayout.mosaic: return 'Mosaico';
      case _VideoLayout.focus: return 'Foco';
      case _VideoLayout.sidebar: return 'Barra lateral';
    }
  }

  List<lk.Participant> _getParticipants(lk.Room room) {
    final list = <lk.Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...?room.remoteParticipants.values,
    ];
    if (!_hideNoVideo) return list;
    return list.where((p) {
      if (p is lk.LocalParticipant) return true;
      final pub = p.videoTrackPublications.firstOrNull;
      return pub != null && !pub.muted;
    }).toList();
  }

  Widget _buildVideoGrid(lk.Room room, BoxConstraints constraints) {
    final participants = _getParticipants(room);

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Esperando participantes...', style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    final effectiveLayout = _resolveLayout(participants.length);

    switch (effectiveLayout) {
      case _VideoLayout.mosaic:
        return _buildMosaic(participants, constraints);
      case _VideoLayout.focus:
        return _buildFocus(participants, constraints);
      case _VideoLayout.sidebar:
        return _buildSidebar(participants, constraints);
      case _VideoLayout.auto:
        return _buildMosaic(participants, constraints);
    }
  }

  _VideoLayout _resolveLayout(int count) {
    if (_layout != _VideoLayout.auto) return _layout;
    if (count <= 4) return _VideoLayout.mosaic;
    return _VideoLayout.focus;
  }

  // --- Mosaic / Grid ---
  Widget _buildMosaic(List<lk.Participant> participants, BoxConstraints constraints) {
    final count = participants.length;
    final cols = _gridColumns(count, constraints.maxWidth);
    final tileSize = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: count,
      itemBuilder: (_, i) => _buildTile(participants[i], tileWidth: tileSize, tileHeight: tileSize),
    );
  }

  int _gridColumns(int count, double width) {
    if (count <= 1) return 1;
    if (count <= 4) return 2;
    if (width < 500) return 2;
    if (count <= 6) return 3;
    return 4;
  }

  // --- Focus (main participant full-area, switch via panel or sidebar) ---
  Widget _buildFocus(List<lk.Participant> participants, BoxConstraints constraints) {
    final idx = _focusedIndex ?? _dominantSpeaker(participants);
    final focus = participants[idx.clamp(0, participants.length - 1)];
    final others = participants.where((p) => p.identity != focus.identity).toList();

    return Row(
      children: [
        Expanded(
          child: _buildTile(focus,
            tileWidth: constraints.maxWidth - (others.isNotEmpty ? 160 : 0) - (_showPanel ? 260 : 0) - 16,
            tileHeight: constraints.maxHeight - 16),
        ),
        if (others.isNotEmpty)
          SizedBox(
            width: 150,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: others.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _focusedIndex = participants.indexOf(others[i])),
                child: SizedBox(
                  height: 110,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildTile(others[i], tileWidth: 140, tileHeight: 100),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- Sidebar (main large + vertical strip) ---
  Widget _buildSidebar(List<lk.Participant> participants, BoxConstraints constraints) {
    final idx = _focusedIndex ?? _dominantSpeaker(participants);
    final focus = participants[idx.clamp(0, participants.length - 1)];
    final others = participants.where((p) => p.identity != focus.identity).toList();

    return Row(
      children: [
        Expanded(
          child: _buildTile(focus,
            tileWidth: constraints.maxWidth - (others.isNotEmpty ? 160 : 0) - 16,
            tileHeight: constraints.maxHeight - 16),
        ),
        if (others.isNotEmpty)
          SizedBox(
            width: 150,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: others.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _focusedIndex = participants.indexOf(others[i])),
                child: SizedBox(
                  height: 110,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildTile(others[i], tileWidth: 140, tileHeight: 100),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _dominantSpeaker(List<lk.Participant> participants) {
    for (int i = 0; i < participants.length; i++) {
      if (participants[i] is! lk.LocalParticipant && participants[i].isSpeaking) {
        return i;
      }
    }
    return participants.length > 1 ? 1 : 0;
  }

  // --- Reaction bubble overlay ---
  Widget _buildReactionBubble(_ReactionBubble r) {
    return Positioned(
      bottom: 160,
      right: 40 + (r.id % 3) * 60.0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (_, value, __) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -20 * (1 - value)),
            child: Text(r.emoji, style: TextStyle(fontSize: 32 + value * 8)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPanel() {
    final pubRtt = (_networkStats['pubRtt'] as double?) ?? 0.0;
    final subRtt = (_networkStats['subRtt'] as double?) ?? 0.0;
    final pubJitter = (_networkStats['pubJitter'] as double?) ?? 0.0;
    final subJitter = (_networkStats['subJitter'] as double?) ?? 0.0;
    final pubLost = _networkStats['pubPacketsLost'] as int? ?? 0;
    final subLost = _networkStats['subPacketsLost'] as int? ?? 0;
    return Positioned(
      left: 0, top: 0, bottom: 0,
      child: Material(
        elevation: 8,
        child: Container(
          width: 220,
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Red', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => setState(() => _showStats = false),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Text('RTT publicación: ${pubRtt > 0 ? '${(pubRtt * 1000).toStringAsFixed(0)} ms' : '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('RTT suscripción: ${subRtt > 0 ? '${(subRtt * 1000).toStringAsFixed(0)} ms' : '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Jitter publicación: ${pubJitter > 0 ? '${(pubJitter * 1000).toStringAsFixed(1)} ms' : '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Jitter suscripción: ${subJitter > 0 ? '${(subJitter * 1000).toStringAsFixed(1)} ms' : '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Pérdida publicación: $pubLost pkts', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text('Pérdida suscripción: $subLost pkts', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Participants panel ---
  Widget _buildParticipantsPanel(lk.Room room) {
    final participants = <lk.Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...?room.remoteParticipants.values,
    ];

    return Positioned(
      right: 0, top: 0, bottom: 0,
      child: Material(
        elevation: 8,
        child: Container(
          width: 260,
          color: const Color(0xFF1A1A2E),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
                child: Row(
                  children: [
                    Text(
                      'Participantes (${participants.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => setState(() => _showPanel = false),
                    ),
                  ],
                ),
              ),
              if (FloatingVideoOverlay._isOwner)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _smallBtn(Icons.mic_off, 'Silenciar todos', () => _muteAll()),
                      _smallBtn(
                        FloatingVideoOverlay._muteOnEntry ? Icons.mic_off : Icons.mic,
                        FloatingVideoOverlay._muteOnEntry ? 'Mute al entrar: ON' : 'Mute al entrar: OFF',
                        () => _toggleMuteOnEntry(),
                      ),
                      _smallBtn(Icons.videocam_off, 'Apagar cámaras', () => _cameraAll()),
                      _smallBtn(
                        FloatingVideoOverlay._roomLocked ? Icons.lock : Icons.lock_open,
                        FloatingVideoOverlay._roomLocked ? 'Sala bloqueada' : 'Bloquear sala',
                        () => _toggleLock(),
                      ),
                      _smallBtn(Icons.call_end, 'Finalizar sala', () => _endCallForAll(), color: Colors.red),
                      if (!FloatingVideoOverlay._isPrivateCall())
                        _smallBtn(Icons.password, 'Quitar contraseña', () => _removePassword()),
                    ],
                  ),
                ),
              const Divider(color: Colors.white12, height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (_, i) => _buildParticipantItem(participants[i], participants),
                ),
              ),
              const Divider(color: Colors.white12, height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(_shortcutsHint, style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantItem(lk.Participant p, List<lk.Participant> all) {
    final isLocal = p is lk.LocalParticipant;
    final cameraPub = p.videoTrackPublications.where((pub) => !pub.isScreenShare).firstOrNull;
    final screenPub = p.videoTrackPublications.where((pub) => pub.isScreenShare).firstOrNull;
    final audioPub = p.audioTrackPublications.firstOrNull;
    final hasVideo = !(isLocal ? FloatingVideoOverlay._isVideoOff : (cameraPub?.muted ?? true));
    final isSharing = screenPub != null && !screenPub.muted;
    final hasAudio = !(isLocal ? FloatingVideoOverlay._isMuted : (audioPub?.muted ?? true));
    final handUp = isLocal ? _handRaised : (_remoteHands[p.identity] ?? false);

    return InkWell(
      onTap: () {
        setState(() => _focusedIndex = all.indexOf(p));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.blue.shade500],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  (p.identity ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.identity ?? '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: p.isSpeaking ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(hasVideo ? Icons.videocam : Icons.videocam_off,
                        size: 14, color: hasVideo ? Colors.green : Colors.red),
                      if (isSharing) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.monitor, size: 14, color: Colors.green),
                      ],
                      const SizedBox(width: 6),
                      Icon(hasAudio ? Icons.mic : Icons.mic_off,
                        size: 14, color: hasAudio ? Colors.green : Colors.red),
                      if (p.isSpeaking) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.record_voice_over, size: 14, color: Colors.greenAccent),
                      ],
                      if (handUp) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.pan_tool, size: 14, color: Colors.amber),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!isLocal && FloatingVideoOverlay._isOwner)
              IconButton(
                icon: const Icon(Icons.shield, color: Colors.amber, size: 18),
                tooltip: 'Moderar',
                onPressed: () => FloatingVideoOverlay._showModerationMenu(p),
              ),
            if (!isLocal)
              IconButton(
                icon: Icon(Icons.push_pin,
                  size: 18,
                  color: all.indexOf(p) == (_focusedIndex ?? _dominantSpeaker(all))
                      ? Colors.amber : Colors.white24),
                onPressed: () => setState(() => _focusedIndex = all.indexOf(p)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(lk.Participant p, {required double tileWidth, required double tileHeight}) {
    final screenPub = p.videoTrackPublications.where((pub) => pub.isScreenShare).firstOrNull;
    final hasScreenShare = screenPub != null && !screenPub.muted;
    final cameraPub = p.videoTrackPublications.where((pub) => !pub.isScreenShare).firstOrNull;
    final videoPub = hasScreenShare ? screenPub : cameraPub;
    final isLocal = p is lk.LocalParticipant;
    final isVideoMuted = isLocal
        ? FloatingVideoOverlay._isVideoOff
        : (cameraPub?.muted ?? true);
    final videoTrack = videoPub?.track as lk.VideoTrack?;
    final handUp = isLocal ? _handRaised : (_remoteHands[p.identity] ?? false);

    final nameFont = tileHeight > 100 ? 14.0 : 10.0;
    final avatarSize = tileHeight > 100 ? 60.0 : 32.0;

    Widget videoWidget;
    if (videoTrack != null && !isVideoMuted) {
      videoWidget = lk.VideoTrackRenderer(
        videoTrack,
        fit: lk.VideoViewFit.contain,
        mirrorMode: isLocal ? lk.VideoViewMirrorMode.mirror : lk.VideoViewMirrorMode.auto,
      );
    } else {
      videoWidget = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: avatarSize, height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.blue.shade500],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Icon(Icons.person, color: Colors.white, size: avatarSize * 0.5),
            ),
            if (tileHeight > 100) ...[
              const SizedBox(height: 8),
              Text(p.identity ?? '', style: TextStyle(color: Colors.white70, fontSize: nameFont)),
            ],
          ],
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () {
        final room = FloatingVideoOverlay._room;
        if (room == null) return;
        final all = <lk.Participant>[
          if (room.localParticipant != null) room.localParticipant!,
          ...?room.remoteParticipants.values,
        ];
        setState(() => _focusedIndex = all.indexOf(p));
      },
      child: Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: p.isSpeaking
            ? Border.all(color: Colors.greenAccent.withOpacity(0.6), width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: videoWidget),
          if (tileHeight > 60)
            Positioned(
              bottom: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  p.identity ?? '',
                  style: TextStyle(color: Colors.white, fontSize: nameFont - 2),
                ),
              ),
            ),
          if (!isLocal && FloatingVideoOverlay._isOwner)
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () => FloatingVideoOverlay._showModerationMenu(p),
                child: FloatingVideoOverlay._overlayBadge(Icons.more_vert, Colors.amber, 'Moderar'),
              ),
            ),
          if (isLocal && FloatingVideoOverlay._isOwner)
            Positioned(
              top: hasScreenShare ? 24 : 4, left: 4,
              child: FloatingVideoOverlay._overlayBadge(Icons.shield, Colors.amber, 'Tú (Dueño)'),
            ),
          if (hasScreenShare)
            Positioned(
              top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monitor, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text('Pantalla', style: TextStyle(color: Colors.white, fontSize: 9)),
                  ],
                ),
              ),
            ),
          if (handUp)
            Positioned(
              top: hasScreenShare ? 24 : (isLocal && FloatingVideoOverlay._isOwner ? 24 : 4),
              right: 4,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 500),
                builder: (_, value, __) => Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pan_tool, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ),
            if (p.isSpeaking)
            Positioned(
              bottom: tileHeight > 60 ? 24 : 4, right: handUp ? 30 : 4,
              child: Icon(Icons.record_voice_over, color: Colors.greenAccent, size: tileHeight > 80 ? 20 : 14),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black87,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji reactions row
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in _reactionEmojis)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _addReaction(e),
                        child: Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white12,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(e, style: const TextStyle(fontSize: 16))),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _btn(
                  icon: FloatingVideoOverlay._isMuted ? Icons.mic_off : Icons.mic,
                  color: FloatingVideoOverlay._isMuted ? Colors.red : Colors.white,
                  onPressed: () {
                    FloatingVideoOverlay._toggleMute();
                    setState(() {});
                  },
                ),
                if (!FloatingVideoOverlay._audioOnly)
                  _btn(
                    icon: FloatingVideoOverlay._isVideoOff ? Icons.videocam_off : Icons.videocam,
                    color: FloatingVideoOverlay._isVideoOff ? Colors.red : Colors.white,
                    onPressed: () {
                      FloatingVideoOverlay._toggleVideo();
                      setState(() {});
                    },
                  ),
                if (!FloatingVideoOverlay._audioOnly)
                  _btn(
                    icon: _isScreenSharing ? Icons.monitor : Icons.monitor_outlined,
                    color: _isScreenSharing ? Colors.green : Colors.white,
                    onPressed: _toggleScreenShare,
                  ),
                _btn(
                  icon: _handRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                  color: _handRaised ? Colors.amber : Colors.white,
                  onPressed: _toggleHand,
                ),
                _btn(
                  icon: Icons.share,
                  color: Colors.white,
                  onPressed: _sendInvite,
                ),
                _btn(
                  icon: Icons.link,
                  color: Colors.white,
                  onPressed: _copyMeetingLink,
                ),
                _btn(
                  icon: FloatingVideoOverlay._soundsEnabled ? Icons.volume_up : Icons.volume_off,
                  color: FloatingVideoOverlay._soundsEnabled ? Colors.white : Colors.red,
                  onPressed: _toggleSounds,
                ),
                if (!FloatingVideoOverlay._audioOnly)
                  _btn(
                    icon: FloatingVideoOverlay._videoQuality == 0
                      ? Icons.auto_mode
                      : FloatingVideoOverlay._videoQuality == 1
                        ? Icons.sd
                        : FloatingVideoOverlay._videoQuality == 2
                          ? Icons.sd
                          : Icons.hd,
                    color: FloatingVideoOverlay._videoQuality == 3 ? Colors.green : Colors.white,
                    onPressed: _cycleVideoQuality,
                  ),
                if (!FloatingVideoOverlay._audioOnly)
                  _btn(
                    icon: _backgroundBlurEnabled ? Icons.blur_on : Icons.blur_off,
                    color: _backgroundBlurEnabled ? Colors.cyan : Colors.white,
                    onPressed: _toggleBackgroundBlur,
                  ),
                _btn(
                  icon: Icons.network_check,
                  color: _showStats ? Colors.green : Colors.white70,
                  onPressed: _toggleStatsPanel,
                ),
                _btn(
                  icon: _showChat ? Icons.chat : Icons.chat_outlined,
                  color: _showChat ? Colors.cyan : Colors.white,
                  onPressed: () => setState(() => _showChat = !_showChat),
                ),
                _btn(
                  icon: Icons.minimize,
                  color: Colors.white,
                  onPressed: widget.onMinimize,
                ),
                _btn(
                  icon: Icons.call_end,
                  color: Colors.red,
                  iconSize: 36,
                  onPressed: widget.onHangUp,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn({required IconData icon, required Color color, required VoidCallback onPressed, double iconSize = 28}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: color == Colors.red ? Colors.red : Colors.white12,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color == Colors.red ? Colors.white : color, size: iconSize),
        ),
      ),
    );
  }
}

class _ReactionBubble {
  final int id;
  final String emoji;
  final DateTime createdAt;
  const _ReactionBubble({required this.id, required this.emoji, required this.createdAt});
}
