import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../models/channel_info.dart';
import 'chat_screen.dart';
import '../main.dart' show globalLog;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _hostController = TextEditingController(text: 'ceres.globalchat.org');
  final _portController = TextEditingController(text: '6667');
  late final TextEditingController _nickController;
  final _channelController = TextEditingController(); // Vacío por defecto
  final _channelFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  List<ChannelInfo> _channels = [];
  bool _loadingChannels = false;
  
  // Lista de canales prohibidos que no se mostrarán en el combo
  static const List<String> _prohibitedChannels = ['#opers', '#services'];

  @override
  void initState() {
    super.initState();
    // Generar un nickname aleatorio: GlobalChat-XXXXX (número aleatorio de 4-5 dígitos)
    final random = Random();
    final randomNumber = random.nextInt(90000) + 10000; // Número entre 10000 y 99999
    _nickController = TextEditingController(text: 'GlobalChat-$randomNumber');
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loadingChannels = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://canales.globalchat.org/proxy/channels.php'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['channels'] != null) {
          final List<dynamic> channelsJson = data['channels'];
          setState(() {
            _channels = channelsJson
                .map((json) => ChannelInfo.fromJson(json))
                .where((channel) {
                  // Filtrar canales prohibidos (case-insensitive)
                  final channelNameLower = channel.name.toLowerCase();
                  return !_prohibitedChannels.any(
                    (prohibited) => channelNameLower == prohibited.toLowerCase()
                  );
                })
                .toList()
              ..sort((a, b) => b.users.compareTo(a.users)); // Ordenar por usuarios (mayor a menor)
            _loadingChannels = false;
          });
          print('🔍 [DEBUG] Canales cargados: ${_channels.length}');
          for (var channel in _channels.take(5)) {
            print('🔍 [DEBUG]   - ${channel.name} (${channel.users} usuarios)');
          }
        }
      }
    } catch (e) {
      print('Error cargando canales: $e');
      setState(() {
        _loadingChannels = false;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _nickController.dispose();
    _channelController.dispose();
    _channelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostController.text;
    final port = int.tryParse(_portController.text) ?? 6667;
    final nick = _nickController.text;
    final channel = _channelController.text;

    if (host.isEmpty || nick.isEmpty || channel.isEmpty) {
      setState(() => _errorMessage = 'Por favor completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      globalLog('========================================');
      globalLog('🔵 [LOGIN] Starting connection');
      globalLog('========================================');
      
      final ircService = ref.read(ircServiceProvider);
      
      globalLog('🔵 [LOGIN] Got IRCService instance');
      globalLog('🔵 [LOGIN] Calling connect() with $host:$port as $nick');
      
      // Detectar automáticamente SSL basado en el puerto
      // Puerto 6697 es estándar para IRC SSL/TLS
      final useSSL = port == 6697;
      
      await ircService.connect(
        host: host,
        port: port,
        nickname: nick,
        useSSL: useSSL,
      );

      globalLog('🔵 [LOGIN] connect() returned successfully');
      
      ref.read(currentNicknameProvider.notifier).state = nick;
      globalLog('🔵 [LOGIN] Set nickname in provider');
      
      // Normalizar el nombre del canal antes de guardarlo
      String normalizedChannel = channel.trim();
      
      // Remover ':' si está al inicio
      if (normalizedChannel.startsWith(':')) {
        normalizedChannel = normalizedChannel.substring(1).trim();
      }
      
      // Remover # duplicados al inicio
      while (normalizedChannel.startsWith('##')) {
        normalizedChannel = normalizedChannel.substring(1);
      }
      
      // Asegurar que empiece con # (solo uno)
      if (!normalizedChannel.startsWith('#')) {
        normalizedChannel = '#$normalizedChannel';
      }
      
      // Normalizar a minúsculas para consistencia
      normalizedChannel = normalizedChannel.toLowerCase();
      
      // Set the channel to join (normalizado)
      ref.read(currentChannelProvider.notifier).state = normalizedChannel;
      globalLog('🔵 [LOGIN] Set channel in provider: "$channel" -> normalized: "$normalizedChannel"');

      globalLog('🔵 [LOGIN] About to navigate to ChatScreen');
      
      if (mounted) {
        globalLog('🔵 [LOGIN] Widget is mounted, navigating...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ChatScreen(),
          ),
        );
        globalLog('🔵 [LOGIN] Navigation completed');
      } else {
        globalLog('❌ [LOGIN] Widget not mounted, cannot navigate');
      }
    } catch (e, stack) {
      globalLog('❌ [LOGIN] EXCEPTION: $e');
      globalLog('❌ [LOGIN] STACK: $stack');
      String errorMessage = 'Error de conexión: $e';
      
      // Mensajes de error más amigables
      if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        errorMessage = 'No se pudo conectar al servidor. Verifica el host y puerto.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Tiempo de espera agotado. El servidor no respondió.';
      } else if (e.toString().contains('TlsException') || e.toString().contains('SSL')) {
        errorMessage = 'Error SSL/TLS. Verifica que el servidor soporte conexiones seguras en el puerto 6697.';
      }
      
      setState(() => _errorMessage = errorMessage);
      setState(() => _isLoading = false);
    }
    
    globalLog('========================================');
    globalLog('🔵 [LOGIN] _connect() method finished');
    globalLog('========================================');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente IRC'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: 'Cambiar tema',
            color: appTheme.textPrimary,
            onPressed: () => _showThemeSelector(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              appTheme.primary.withOpacity(0.1),
              appTheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              color: appTheme.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      appTheme.background,
                      appTheme.background.withOpacity(0.95),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedLogo(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Conectar a GlobalChat IRC Network',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: appTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
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
                          boxShadow: [
                            BoxShadow(
                              color: appTheme.primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showThemeSelector(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.palette,
                                size: 32,
                                color: appTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _hostController,
                    style: TextStyle(color: appTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Servidor',
                      hintText: 'ceres.globalchat.org',
                      prefixIcon: Icon(Icons.language, color: appTheme.primary),
                      labelStyle: TextStyle(color: appTheme.primary),
                      hintStyle: TextStyle(color: appTheme.textSecondary),
                      filled: true,
                      fillColor: appTheme.surface.withOpacity(0.9),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.6), width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.4), width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    style: TextStyle(color: appTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Puerto',
                      hintText: '6667',
                      prefixIcon: Icon(Icons.vpn_lock, color: appTheme.primary),
                      labelStyle: TextStyle(color: appTheme.primary),
                      hintStyle: TextStyle(color: appTheme.textSecondary),
                      filled: true,
                      fillColor: appTheme.surface.withOpacity(0.9),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.6), width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.4), width: 1),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nickController,
                    style: TextStyle(color: appTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Apodo',
                      hintText: 'FlutterUser',
                      prefixIcon: Icon(Icons.person, color: appTheme.primary),
                      labelStyle: TextStyle(color: appTheme.primary),
                      hintStyle: TextStyle(color: appTheme.textSecondary),
                      filled: true,
                      fillColor: appTheme.surface.withOpacity(0.9),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.6), width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.4), width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ChannelSelector(
                    controller: _channelController,
                    channels: _channels,
                    loadingChannels: _loadingChannels,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _connect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appTheme.primary,
                        disabledBackgroundColor: Colors.grey,
                        foregroundColor: appTheme.textPrimary,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(appTheme.textPrimary),
                              ),
                            )
                          : Text(
                              'Conectar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: appTheme.textPrimary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    final currentTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    currentTheme.primary,
                    currentTheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.palette,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Seleccionar Tema',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppTheme.themes.length,
            itemBuilder: (context, index) {
              final theme = AppTheme.themes[index];
              final isSelected = theme.name == currentTheme.name;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.primary : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2.5 : 1,
                  ),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            theme.primary.withOpacity(0.1),
                            theme.secondary.withOpacity(0.1),
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primary,
                          theme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    theme.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 16,
                      color: isSelected ? theme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        )
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(theme);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Widget animado para el logo de GlobalChat
class _AnimatedLogo extends StatefulWidget {
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Image.network(
                  'https://registro-chan.globalchat.org/gc/logo.png',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Si falla la carga, mostrar el icono original
                    return Container(
                      height: 200,
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFD700), // Amarillo dorado
                            const Color(0xFFFFA500), // Naranja
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.chat_bubble,
                        size: 80,
                        color: Colors.white,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFA500)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget personalizado para seleccionar canal con dropdown
class _ChannelSelector extends StatefulWidget {
  final TextEditingController controller;
  final List<ChannelInfo> channels;
  final bool loadingChannels;
  final dynamic appTheme;

  const _ChannelSelector({
    required this.controller,
    required this.channels,
    required this.loadingChannels,
    required this.appTheme,
  });

  @override
  State<_ChannelSelector> createState() => _ChannelSelectorState();
}

class _ChannelSelectorState extends State<_ChannelSelector> {
  final FocusNode _focusNode = FocusNode();
  List<ChannelInfo> _filteredChannels = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _updateFilteredChannels();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_ChannelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channels != oldWidget.channels) {
      _updateFilteredChannels();
    }
  }

  void _updateFilteredChannels() {
    final query = widget.controller.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredChannels = widget.channels.take(20).toList();
      } else {
        _filteredChannels = widget.channels.where((channel) {
          return channel.name.toLowerCase().contains(query) ||
              channel.topic.toLowerCase().contains(query);
        }).take(20).toList();
      }
      print('🔍 [DEBUG] _updateFilteredChannels: ${_filteredChannels.length} canales filtrados de ${widget.channels.length} totales');
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.channels.isNotEmpty) {
      // Si el campo está vacío, mostrar todos los canales automáticamente
      if (widget.controller.text.isEmpty) {
        setState(() {
          _filteredChannels = widget.channels.take(20).toList();
        });
      }
      _showDropdownOverlay();
    } else {
      _hideDropdownOverlay();
    }
  }

  void _onTextChanged() {
    _updateFilteredChannels();
    
    // Si el campo está vacío y tiene foco, asegurar que el dropdown esté visible con todos los canales
    if (widget.controller.text.trim().isEmpty && _focusNode.hasFocus && widget.channels.isNotEmpty) {
      if (!_showDropdown) {
        _showDropdownOverlay();
      }
    }
  }

  void _showDropdownOverlay() {
    // Asegurar que los canales filtrados estén actualizados antes de mostrar
    if (widget.controller.text.trim().isEmpty) {
      _updateFilteredChannels();
    }
    
    print('🔍 [DEBUG] _showDropdownOverlay: ${_filteredChannels.length} canales, ${widget.channels.length} totales');
    
    // Usar showModalBottomSheet en lugar de overlay personalizado
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: widget.appTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.appTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar Canal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.appTheme.primary,
                  ),
                ),
              ),
              Flexible(
                child: _filteredChannels.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No se encontraron canales',
                          style: TextStyle(color: widget.appTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredChannels.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = _filteredChannels[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: widget.appTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.appTheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${option.users}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.appTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: option.topic.isNotEmpty
                                ? Text(
                                    option.topic.length > 60
                                        ? '${option.topic.substring(0, 60)}...'
                                        : option.topic,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.appTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () {
                              print('🔍 [DEBUG] ✅✅✅✅✅ TAP DETECTADO en canal: ${option.name}');
                              widget.controller.text = option.name;
                              widget.controller.selection = TextSelection(
                                baseOffset: widget.controller.text.length,
                                extentOffset: widget.controller.text.length,
                              );
                              print('🔍 [DEBUG] Controlador actualizado: "${widget.controller.text}"');
                              Navigator.pop(context);
                              _focusNode.unfocus();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      setState(() {
        _showDropdown = false;
      });
    });
    
    setState(() {
      _showDropdown = true;
    });
  }

  void _hideDropdownOverlay() {
    // Con showModalBottomSheet, se cierra automáticamente con Navigator.pop
    setState(() {
      _showDropdown = false;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: TextStyle(color: widget.appTheme.textPrimary),
        decoration: InputDecoration(
          labelText: 'Canal',
          hintText: widget.loadingChannels 
              ? 'Cargando canales...' 
              : 'Escribe o selecciona un canal',
          labelStyle: TextStyle(color: widget.appTheme.primary),
          hintStyle: TextStyle(color: widget.appTheme.textSecondary),
          filled: true,
          fillColor: widget.appTheme.surface.withOpacity(0.9),
          prefixIcon: widget.loadingChannels
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.appTheme.primary),
                    ),
                  ),
                )
              : Icon(Icons.tag, color: widget.appTheme.primary),
          suffixIcon: widget.channels.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    _showDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: widget.appTheme.primary,
                  ),
                  onPressed: () {
                    if (_showDropdown) {
                      _hideDropdownOverlay();
                      _focusNode.unfocus();
                    } else {
                      _focusNode.requestFocus();
                      _showDropdownOverlay();
                    }
                  },
                )
              : null,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.6), width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.4), width: 1),
          ),
        ),
        onTap: () {
          print('🔍 [DEBUG] onTap del TextField: ${widget.channels.length} canales disponibles');
          if (widget.channels.isNotEmpty) {
            // Si el campo está vacío, asegurar que se muestren todos los canales
            if (widget.controller.text.trim().isEmpty) {
              _updateFilteredChannels();
            }
            // Mostrar el dropdown siempre
            _showDropdownOverlay();
          } else {
            print('🔍 [DEBUG] ⚠️  No hay canales disponibles aún');
          }
        },
    );
  }
}
