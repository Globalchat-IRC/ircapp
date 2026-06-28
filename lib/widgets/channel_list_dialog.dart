import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/irc_service.dart';
import '../providers/theme_provider.dart';
import '../providers/irc_provider.dart';
import '../models/app_theme.dart';

enum ChannelSortType {
  users,      // Ordenar por número de usuarios
  name,       // Ordenar por nombre alfabético
  topic,      // Ordenar por temática (topic)
}

class ChannelListDialog extends ConsumerStatefulWidget {
  final IRCService ircService;

  const ChannelListDialog({
    super.key,
    required this.ircService,
  });

  @override
  ConsumerState<ChannelListDialog> createState() => _ChannelListDialogState();
}

class _ChannelListDialogState extends ConsumerState<ChannelListDialog> {
  List<Map<String, dynamic>> _allChannels = [];
  List<Map<String, dynamic>> _filteredChannels = [];
  ChannelSortType _sortType = ChannelSortType.users;
  bool _sortAscending = false; // false = descendente (más usuarios primero)
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterChannels);
    _loadChannelList();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterChannels);
    _searchController.dispose();
    super.dispose();
  }

  void _loadChannelList() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Listener para recibir resultados
    void listListener(List<Map<String, dynamic>> results) {
      if (mounted) {
        widget.ircService.removeListListener(listListener);
        setState(() {
          // Filtrar canales con nombres inválidos (vacíos, solo asteriscos, etc.)
          _allChannels = results.where((channel) {
            final channelName = (channel['channel'] as String? ?? '').trim();
            // Filtrar nombres vacíos, solo asteriscos, o que no empiecen con #
            return channelName.isNotEmpty && 
                   channelName != '*' && 
                   channelName != '**' &&
                   channelName.startsWith('#') &&
                   channelName.length > 1; // Al menos # + 1 carácter
          }).toList();
          _isLoading = false;
        });
        _filterChannels();
      }
    }

    widget.ircService.addListListener(listListener);
    widget.ircService.sendList();
  }

  void _filterChannels() {
    final searchTerm = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredChannels = List.from(_allChannels);
      } else {
        _filteredChannels = _allChannels.where((channel) {
          final channelName = (channel['channel'] as String? ?? '').toLowerCase();
          final topic = (channel['topic'] as String? ?? '').toLowerCase();
          return channelName.contains(searchTerm) || topic.contains(searchTerm);
        }).toList();
      }
      _sortChannels();
    });
  }

  void _sortChannels() {
    setState(() {
      _filteredChannels.sort((a, b) {
        int comparison = 0;
        
        switch (_sortType) {
          case ChannelSortType.users:
            final usersA = a['users'] as int? ?? 0;
            final usersB = b['users'] as int? ?? 0;
            comparison = usersA.compareTo(usersB);
            break;
          case ChannelSortType.name:
            final nameA = (a['channel'] as String? ?? '').toLowerCase();
            final nameB = (b['channel'] as String? ?? '').toLowerCase();
            comparison = nameA.compareTo(nameB);
            break;
          case ChannelSortType.topic:
            final topicA = (a['topic'] as String? ?? '').toLowerCase();
            final topicB = (b['topic'] as String? ?? '').toLowerCase();
            comparison = topicA.compareTo(topicB);
            break;
        }
        
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  void _changeSortType(ChannelSortType newType) {
    setState(() {
      if (_sortType == newType) {
        _sortAscending = !_sortAscending;
      } else {
        _sortType = newType;
        _sortAscending = false; // Por defecto descendente
      }
      _sortChannels();
    });
  }

  void _joinChannel(String channelName) {
    final normalizedChannel = (channelName.startsWith('#') 
        ? channelName 
        : '#$channelName').toLowerCase();
    
    // Unirse al canal
    widget.ircService.joinChannel(normalizedChannel);
    
    // Cambiar el foco al canal seleccionado
    ref.read(currentChannelProvider.notifier).state = normalizedChannel;
    ref.read(lastChannelProvider.notifier).state = normalizedChannel;
    ref.read(recentChannelsProvider.notifier).addRecent(normalizedChannel);
    
    // Cerrar el diálogo
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    return Dialog(
      backgroundColor: appTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header con título y botón cerrar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    appTheme.primary,
                    appTheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.list,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lista de Canales',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_filteredChannels.length} canales disponibles',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
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
            ),
            
            // Botonera de ordenamiento
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: appTheme.background,
                border: Border(
                  bottom: BorderSide(
                    color: appTheme.textSecondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Botón: Ordenar por usuarios
                  Expanded(
                    child: _buildSortButton(
                      appTheme,
                      'Usuarios',
                      Icons.people,
                      ChannelSortType.users,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón: Ordenar por nombre
                  Expanded(
                    child: _buildSortButton(
                      appTheme,
                      'Nombre',
                      Icons.sort_by_alpha,
                      ChannelSortType.name,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón: Ordenar por temática
                  Expanded(
                    child: _buildSortButton(
                      appTheme,
                      'Temática',
                      Icons.topic,
                      ChannelSortType.topic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón: Recargar
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: appTheme.textPrimary,
                    ),
                    tooltip: 'Recargar lista',
                    onPressed: _isLoading ? null : _loadChannelList,
                  ),
                ],
              ),
            ),
            
            // Barra de búsqueda y botón para unirse manualmente
            Container(
              padding: const EdgeInsets.all(16),
              color: appTheme.background,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o temática...',
                      hintStyle: TextStyle(color: appTheme.textSecondary),
                      prefixIcon: Icon(Icons.search, color: appTheme.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: appTheme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: appTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: appTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: appTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: appTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: TextStyle(color: appTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  // Botón para unirse a un canal manualmente (incluyendo tu propio canal)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showManualJoinDialog(context, appTheme);
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Unirse a canal manualmente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Lista de canales
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(appTheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando canales...',
                            style: TextStyle(color: appTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: TextStyle(color: appTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadChannelList,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        )
                      : _filteredChannels.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    color: appTheme.textSecondary,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No se encontraron canales'
                                        : 'No hay canales disponibles',
                                    style: TextStyle(color: appTheme.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              child: ListView.builder(
                                itemCount: _filteredChannels.length,
                                padding: const EdgeInsets.all(8),
                                itemBuilder: (context, index) {
                                  final channel = _filteredChannels[index];
                                  final channelName = channel['channel'] as String? ?? '';
                                  final userCount = channel['users'] as int? ?? 0;
                                  final topic = channel['topic'] as String? ?? '';
                                  
                                  return _buildChannelItem(
                                    appTheme,
                                    channelName,
                                    userCount,
                                    topic,
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton(
    AppTheme appTheme,
    String label,
    IconData icon,
    ChannelSortType sortType,
  ) {
    final isActive = _sortType == sortType;
    final isAscending = isActive && _sortAscending;
    
    return InkWell(
      onTap: () => _changeSortType(sortType),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? appTheme.primary.withValues(alpha: 0.2)
              : appTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? appTheme.primary
                : appTheme.textSecondary.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? appTheme.primary : appTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? appTheme.primary : appTheme.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
                color: appTheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChannelItem(
    AppTheme appTheme,
    String channelName,
    int userCount,
    String topic,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: appTheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: appTheme.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: () => _joinChannel(channelName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono de canal
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appTheme.primary,
                      appTheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tag,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // Información del canal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  channelName,
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (channelName.toLowerCase() == '#globalchat') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        size: 12,
                                        color: Colors.amber.shade700,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Canal Oficial',
                                        style: TextStyle(
                                          color: Colors.amber.shade700,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: appTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people,
                                size: 14,
                                color: appTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$userCount',
                                style: TextStyle(
                                  color: appTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (topic.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        topic,
                        style: TextStyle(
                          color: appTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Botón Unirse (más visible)
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _joinChannel(channelName),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Unirse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualJoinDialog(BuildContext context, AppTheme appTheme) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Unirse a Canal',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '#canal',
            prefixIcon: const Icon(Icons.tag),
            hintStyle: TextStyle(color: appTheme.textSecondary),
            filled: true,
            fillColor: appTheme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: appTheme.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: appTheme.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: appTheme.primary,
                width: 2,
              ),
            ),
          ),
          style: TextStyle(color: appTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final channel = controller.text.trim();
              if (channel.isNotEmpty) {
                _joinChannel(channel);
                Navigator.pop(context); // Cerrar diálogo manual
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }
}

