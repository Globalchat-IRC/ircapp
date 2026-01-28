import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/user_role.dart';
import '../models/radio_station.dart';
import '../services/video_database_service.dart';
import '../providers/video_provider.dart';
import '../providers/irc_provider.dart';
import '../providers/radio_provider.dart';
import '../services/irc_service.dart';
import 'reputation_badge.dart';
import 'email_verification_dialog.dart';

/// Diálogo de perfil de usuario completo
class UserProfileDialog extends ConsumerStatefulWidget {
  final String nick;
  final String? currentChannel; // Canal actual para detectar si es el robot oficial
  
  const UserProfileDialog({
    super.key,
    required this.nick,
    this.currentChannel,
  });
  
  @override
  ConsumerState<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends ConsumerState<UserProfileDialog> with SingleTickerProviderStateMixin {
  UserProfile? _profile;
  List<Map<String, dynamic>> _reputationHistory = [];
  List<Map<String, dynamic>> _conferences = [];
  bool _isLoading = true;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final db = ref.read(videoDatabaseProvider);
      final profile = await db.getUserProfile(widget.nick);
      final history = await db.getReputationHistory(widget.nick, limit: 20);
      final conferences = await db.getConferencesHistory(nick: widget.nick, limit: 20);
      
      setState(() {
        _profile = profile;
        _reputationHistory = history;
        _conferences = conferences;
        _isLoading = false;
      });
    } catch (e) {
      // print('❌ Error al cargar perfil: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 700,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profile == null
                ? _buildNoProfile()
                : _buildProfileContent(),
      ),
    );
  }
  
  Widget _buildNoProfile() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Perfil no encontrado',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Este usuario aún no tiene perfil'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileContent() {
    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReputationTab(),
              _buildActivityTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(_profile!.role.color),
            Color(_profile!.role.color).withOpacity(0.7),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              _profile!.nick[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _profile!.nick,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _profile!.role.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    if (_profile!.verificationBadge.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        _profile!.verificationBadge,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _profile!.role.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ReputationBadge(
                  reputation: _profile!.reputation,
                  size: 16,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Info', icon: Icon(Icons.info_outline)),
        Tab(text: 'Reputación', icon: Icon(Icons.star_outline)),
        Tab(text: 'Actividad', icon: Icon(Icons.history)),
      ],
    );
  }
  
  Widget _buildInfoTab() {
    // Detectar si es el robot oficial de GlobalChat
    final isGlobalChatBot = widget.nick.toLowerCase() == 'globalchat' && 
                          widget.currentChannel?.toLowerCase() == '#globalchat';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiqueta de Robot Oficial de GlobalChat
          if (isGlobalChatBot) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.2),
                    const Color(0xFFFFA500).withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '🤖',
                      style: TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Robot Oficial del Canal GlobalChat',
                          style: TextStyle(
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bot oficial de la red GlobalChat que gestiona el canal #globalchat',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          _buildInfoCard(
            '📅 Registro',
            _profile!.registrationDate != null
                ? DateFormat('dd/MM/yyyy').format(_profile!.registrationDate!)
                : 'Desconocido',
            subtitle: '${_profile!.daysRegistered} días en el sistema',
          ),
          _buildInfoCard(
            '✉️ Email',
            _profile!.emailVerified ? 'Verificado' : 'No verificado',
            subtitle: _profile!.emailVerified ? 'Email confirmado' : 'Click para verificar',
            trailing: _profile!.emailVerified
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.email),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => EmailVerificationDialog(
                          nick: widget.nick,
                          onVerified: _loadProfile,
                        ),
                      );
                    },
                  ),
          ),
          _buildInfoCard(
            '📱 Teléfono',
            _profile!.phoneVerified ? 'Verificado' : 'No verificado',
            trailing: _profile!.phoneVerified
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.grey),
          ),
          _buildInfoCard(
            '🆔 Identidad',
            _profile!.idVerified ? 'Verificada' : 'No verificada',
            trailing: _profile!.idVerified
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.cancel, color: Colors.grey),
          ),
          const Divider(height: 32),
          _buildInfoCard(
            '📊 Reputación',
            '${_profile!.reputation}/100',
            subtitle: _getReputationDescription(),
          ),
          _buildInfoCard(
            '🎥 Videoconferencias',
            _profile!.hasAcceptedVideoTerms ? 'Términos aceptados' : 'No aceptados',
            subtitle: _profile!.canEnableVideo
                ? '✅ Puede usar video'
                : '❌ ${_profile!.videoRestrictionReason ?? "Restricciones activas"}',
          ),
          _buildInfoCard(
            '🎙️ Audioconferencias',
            _profile!.hasAcceptedVideoTerms ? 'Disponible' : 'Términos no aceptados',
            subtitle: _profile!.canEnableVideo
                ? '✅ Puede usar audio'
                : '❌ ${_profile!.videoRestrictionReason ?? "Restricciones activas"}',
          ),
          // Botón para compartir canción (solo si es el propio perfil y la radio está encendida)
          Consumer(
            builder: (context, ref, _) {
              final currentNick = ref.watch(currentNicknameProvider);
              final isOwnProfile = currentNick != null && 
                  currentNick.toLowerCase() == widget.nick.toLowerCase();
              
              // Debug logs
              print('🎵 [DIALOGO] isOwnProfile: $isOwnProfile, currentNick: $currentNick, widget.nick: ${widget.nick}');
              
              if (!isOwnProfile) {
                return const SizedBox.shrink();
              }
              
              final radioState = ref.watch(radioProvider);
              final isPlaying = radioState.isPlaying;
              final activeStation = radioState.activeStation;
              
              // Debug logs
              print('🎵 [DIALOGO] Radio state - isPlaying: $isPlaying, activeStation: ${activeStation?.name ?? "null"}');
              
              // Mostrar siempre la sección de radio, pero con diferentes contenidos según el estado
              return Column(
                children: [
                  const Divider(height: 32),
                  if (!isPlaying || activeStation == null)
                    _buildRadioOffCard()
                  else
                    _buildShareSongCard(ref, activeStation),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Mensaje cuando la radio está apagada
  Widget _buildRadioOffCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.radio,
            color: Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Radio apagada',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enciende la radio para compartir la canción que estás escuchando',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mapear estación de radio al canal correspondiente
  String? _getChannelForStation(String stationName) {
    final name = stationName.toLowerCase();
    if (name == 'nuestrasvoces') {
      return '#nuestrasvoces';
    } else if (name == 'soundmusic') {
      return '#soundmusic';
    } else if (name == 'urbanflow') {
      return '#urbanflow';
    }
    return null;
  }
  
  // Construir tarjeta para compartir canción
  Widget _buildShareSongCard(WidgetRef ref, RadioStation activeStation) {
    final currentSong = activeStation.currentArtistSong ?? 'Sin información';
    final stationName = activeStation.name ?? 'Radio';
    final channelName = _getChannelForStation(stationName);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.music_note,
                color: Colors.purple,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reproduciendo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentSong,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'En $stationName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (channelName != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendSongToChannel(context, ref, channelName, stationName, currentSong),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Enviar canción al canal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta estación no tiene canal asociado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Enviar canción al canal correspondiente
  Future<void> _sendSongToChannel(
    BuildContext context,
    WidgetRef ref,
    String channelName,
    String stationName,
    String currentSong,
  ) async {
    try {
      final ircService = ref.read(ircServiceProvider);
      final channels = ref.read(channelsProvider);
      
      // Verificar si el usuario está en el canal
      final normalizedChannel = channelName.toLowerCase();
      final isInChannel = channels.containsKey(normalizedChannel);
      
      // Si no está en el canal, unirse primero
      if (!isInChannel) {
        ircService.joinChannel(channelName);
        // Esperar un poco para que el servidor procese el JOIN
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Crear mensaje moderno y atractivo
      final message = '🎵 🎶 ¡Escuchando ahora en $stationName! 🎶 🎵\n'
          '▶️ **$currentSong**\n'
          '📻 ¡Únete a escuchar en $channelName! 🎧';
      
      // Enviar mensaje al canal
      ircService.sendMessage(channelName, message);
      
      // Mostrar confirmación
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Canción enviada a $channelName',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      
      // Cerrar el diálogo después de enviar
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar canción: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Widget _buildReputationTab() {
    return _reputationHistory.isEmpty
        ? const Center(child: Text('Sin historial de reputación'))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _reputationHistory.length,
            itemBuilder: (context, index) {
              final entry = _reputationHistory[index];
              final change = entry['change_amount'] as int;
              final isPositive = change > 0;
              
              return Card(
                child: ListTile(
                  leading: Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                  title: Text(entry['reason'] as String),
                  subtitle: Text(
                    '${entry['old_reputation']} → ${entry['new_reputation']}',
                  ),
                  trailing: Text(
                    '${isPositive ? "+" : ""}$change',
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildActivityTab() {
    return _conferences.isEmpty
        ? const Center(child: Text('Sin actividad de conferencias'))
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _conferences.length,
            itemBuilder: (context, index) {
              final conf = _conferences[index];
              final startTime = DateTime.parse(conf['start_time'] as String);
              final duration = conf['duration_seconds'] as int?;
              
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.blue),
                  title: Text(conf['channel'] as String),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Iniciado: ${DateFormat('dd/MM HH:mm').format(startTime)}'),
                      if (duration != null)
                        Text('Duración: ${_formatDuration(duration)}'),
                    ],
                  ),
                  trailing: Text(
                    '${conf['total_participants']} 👥',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildInfoCard(
    String title,
    String value, {
    String? subtitle,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
  
  String _getReputationDescription() {
    final rep = _profile!.reputation;
    if (rep >= 80) return 'Excelente comportamiento';
    if (rep >= 60) return 'Buen comportamiento';
    if (rep >= 40) return 'Comportamiento regular';
    if (rep >= 20) return 'Comportamiento cuestionable';
    return 'Múltiples infracciones';
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes % 60}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds % 60}s';
    } else {
      return '${seconds}s';
    }
  }
}

