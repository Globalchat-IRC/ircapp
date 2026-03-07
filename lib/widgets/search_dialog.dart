import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/irc_message.dart';
import '../services/search_service.dart';

class SearchDialog extends StatefulWidget {
  final List<IRCMessage> messages;
  final Function(IRCMessage) onMessageSelected;

  const SearchDialog({
    super.key,
    required this.messages,
    required this.onMessageSelected,
  });

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  String _searchTerm = '';
  String? _userFilter;
  List<IRCMessage> _filteredMessages = [];
  int _selectedIndex = -1;

  static final SingleActivator _nextResultActivator = SingleActivator(
    LogicalKeyboardKey.keyG,
    meta: true,
  );
  static final SingleActivator _previousResultActivator = SingleActivator(
    LogicalKeyboardKey.keyG,
    meta: true,
    shift: true,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _userController.addListener(_onUserFilterChanged);
    _filteredMessages = widget.messages;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _userController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text;
      _performSearch();
    });
  }

  void _onUserFilterChanged() {
    setState(() {
      _userFilter = _userController.text.isEmpty ? null : _userController.text;
      _performSearch();
    });
  }

  void _performSearch() {
    setState(() {
      _filteredMessages = SearchService.searchMessages(
        widget.messages,
        _searchTerm,
        userFilter: _userFilter,
      );
      _selectedIndex = _filteredMessages.isNotEmpty ? 0 : -1;
    });
  }

  void _selectNext() {
    if (_filteredMessages.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + 1) % _filteredMessages.length;
    });
  }

  void _selectPrevious() {
    if (_filteredMessages.isEmpty) return;
    setState(() {
      _selectedIndex = _selectedIndex <= 0
          ? _filteredMessages.length - 1
          : _selectedIndex - 1;
    });
  }

  void _selectCurrent() {
    if (_selectedIndex >= 0 && _selectedIndex < _filteredMessages.length) {
      widget.onMessageSelected(_filteredMessages[_selectedIndex]);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Shortcuts(
      shortcuts: {
        _nextResultActivator: const _SelectNextIntent(),
        _previousResultActivator: const _SelectPreviousIntent(),
      },
      child: Actions(
        actions: {
          _SelectNextIntent: CallbackAction<_SelectNextIntent>(
            onInvoke: (_) {
              _selectNext();
              return null;
            },
          ),
          _SelectPreviousIntent: CallbackAction<_SelectPreviousIntent>(
            onInvoke: (_) {
              _selectPrevious();
              return null;
            },
          ),
        },
        child: Dialog(
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Barra de búsqueda
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Buscar en mensajes...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _selectCurrent(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _userController,
                        decoration: const InputDecoration(
                          hintText: 'Filtrar por usuario...',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Contador de resultados
                Text(
                  '${_filteredMessages.length} resultado${_filteredMessages.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                const Divider(),
                // Lista de resultados
                Expanded(
                  child: _filteredMessages.isEmpty
                      ? Center(
                          child: Text(
                            _searchTerm.isEmpty
                                ? 'Escribe para buscar...'
                                : 'No se encontraron resultados',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredMessages.length,
                          itemBuilder: (context, index) {
                            final message = _filteredMessages[index];
                            final isSelected = index == _selectedIndex;
                            final spans = SearchService.highlightText(
                              message.message,
                              _searchTerm,
                              theme.textTheme.bodyMedium ?? const TextStyle(),
                              TextStyle(
                                backgroundColor: Colors.yellow,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            );

                            return InkWell(
                              onTap: () {
                                widget.onMessageSelected(message);
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                color: isSelected
                                    ? theme.primaryColor.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          message.nick,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          message.channel,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTime(message.timestamp),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    RichText(
                                      text: TextSpan(children: spans),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const Divider(),
                // Ayuda de atajos
                Text(
                  '⌘G: Siguiente | ⇧⌘G: Anterior | Enter: Seleccionar',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _SelectNextIntent extends Intent {
  const _SelectNextIntent();
}

class _SelectPreviousIntent extends Intent {
  const _SelectPreviousIntent();
}






