import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/user_role.dart';
import '../services/video_database_service.dart';
import '../providers/video_provider.dart';
import 'reputation_badge.dart';
import 'email_verification_dialog.dart';

/// Diálogo de perfil de usuario completo
class UserProfileDialog extends ConsumerStatefulWidget {
  final String nick;
  
  const UserProfileDialog({
    super.key,
    required this.nick,
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
      print('❌ Error al cargar perfil: $e');
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
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

