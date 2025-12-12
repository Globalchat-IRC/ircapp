import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../providers/irc_provider.dart';
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
      
      await ircService.connect(
        host: host,
        port: port,
        nickname: nick,
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
      setState(() => _errorMessage = 'Error: $e');
      setState(() => _isLoading = false);
    }
    
    globalLog('========================================');
    globalLog('🔵 [LOGIN] _connect() method finished');
    globalLog('========================================');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente IRC'),
        backgroundColor: const Color(0xFFFF8C00), // Naranja oscuro
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFD700).withOpacity(0.1), // Amarillo dorado claro
              const Color(0xFFFFA500).withOpacity(0.1), // Naranja claro
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
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
                      Colors.white,
                      const Color(0xFFFFE4B5).withOpacity(0.3), // Amarillo claro
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
                  const Text(
                    'Conectar a GlobalChat IRC Network',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00), // Naranja oscuro
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: 'Servidor',
                      hintText: 'ceres.globalchat.org',
                      prefixIcon: const Icon(Icons.language, color: Color(0xFFFFA500)),
                      labelStyle: const TextStyle(color: Color(0xFFFF8C00)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFA500), width: 2),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFD700)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: 'Puerto',
                      hintText: '6667',
                      prefixIcon: const Icon(Icons.vpn_lock, color: Color(0xFFFFA500)),
                      labelStyle: const TextStyle(color: Color(0xFFFF8C00)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFA500), width: 2),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFD700)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nickController,
                    decoration: InputDecoration(
                      labelText: 'Apodo',
                      hintText: 'FlutterUser',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFFFFA500)),
                      labelStyle: const TextStyle(color: Color(0xFFFF8C00)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFA500), width: 2),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFFFD700)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ChannelSelector(
                    controller: _channelController,
                    channels: _channels,
                    loadingChannels: _loadingChannels,
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
                        backgroundColor: const Color(0xFFFFA500), // Naranja
                        disabledBackgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Conectar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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

  const _ChannelSelector({
    required this.controller,
    required this.channels,
    required this.loadingChannels,
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar Canal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF8C00),
                  ),
                ),
              ),
              Flexible(
                child: _filteredChannels.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No se encontraron canales'),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFA500).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${option.users}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFFF8C00),
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
                                      color: Colors.grey[600],
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
        decoration: InputDecoration(
          labelText: 'Canal',
          hintText: widget.loadingChannels 
              ? 'Cargando canales...' 
              : 'Escribe o selecciona un canal',
          prefixIcon: widget.loadingChannels
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFA500)),
                    ),
                  ),
                )
              : const Icon(Icons.tag, color: Color(0xFFFFA500)),
          suffixIcon: widget.channels.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    _showDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: const Color(0xFFFFA500),
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
          labelStyle: const TextStyle(color: Color(0xFFFF8C00)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFA500), width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFD700)),
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
