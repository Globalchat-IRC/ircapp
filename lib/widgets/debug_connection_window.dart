import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class DebugConnectionWindow extends StatefulWidget {
  final AppTheme appTheme;
  final List<String> logs;

  const DebugConnectionWindow({
    Key? key,
    required this.appTheme,
    required this.logs,
  }) : super(key: key);

  @override
  State<DebugConnectionWindow> createState() => _DebugConnectionWindowState();
}

class _DebugConnectionWindowState extends State<DebugConnectionWindow> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DebugConnectionWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_autoScroll && widget.logs.length > oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.appTheme.background,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: widget.appTheme.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.appTheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.bug_report, color: widget.appTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ventana de Debug - Mensajes de Conexión',
                      style: TextStyle(
                        color: widget.appTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                          color: widget.appTheme.textSecondary,
                        ),
                        tooltip: _autoScroll ? 'Desactivar auto-scroll' : 'Activar auto-scroll',
                        onPressed: () {
                          setState(() {
                            _autoScroll = !_autoScroll;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, color: widget.appTheme.textSecondary),
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Logs content
            Expanded(
              child: Container(
                color: widget.appTheme.background,
                child: widget.logs.isEmpty
                    ? Center(
                        child: Text(
                          'No hay mensajes de conexión aún...',
                          style: TextStyle(
                            color: widget.appTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.logs.length,
                        itemBuilder: (context, index) {
                          final log = widget.logs[index];
                          Color textColor = widget.appTheme.textPrimary;
                          Color bgColor = Colors.transparent;

                          // Colorear según el tipo de mensaje
                          if (log.contains('353') || log.contains('NAMES') || log.contains('📋')) {
                            bgColor = Colors.blue.withOpacity(0.1);
                            textColor = Colors.blue.shade300;
                          } else if (log.contains('366') || log.contains('✅')) {
                            bgColor = Colors.green.withOpacity(0.1);
                            textColor = Colors.green.shade300;
                          } else if (log.contains('⚠️') || log.contains('ERROR') || log.contains('❌')) {
                            bgColor = Colors.red.withOpacity(0.1);
                            textColor = Colors.red.shade300;
                          } else if (log.contains('JOIN') || log.contains('🔍')) {
                            bgColor = Colors.orange.withOpacity(0.1);
                            textColor = Colors.orange.shade300;
                          } else if (log.contains('📡') || log.contains('CONNECT')) {
                            bgColor = Colors.purple.withOpacity(0.1);
                            textColor = Colors.purple.shade300;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              log,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.appTheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${widget.logs.length} mensajes',
                    style: TextStyle(
                      color: widget.appTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cerrar',
                      style: TextStyle(color: widget.appTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

