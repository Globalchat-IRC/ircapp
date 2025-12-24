import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_database_service.dart';
import '../providers/video_provider.dart';

/// Diálogo para verificar email
class EmailVerificationDialog extends ConsumerStatefulWidget {
  final String nick;
  final VoidCallback? onVerified;
  
  const EmailVerificationDialog({
    super.key,
    required this.nick,
    this.onVerified,
  });
  
  @override
  ConsumerState<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends ConsumerState<EmailVerificationDialog> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _sentCode; // Para testing (remover en producción)
  
  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }
  
  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Ingresa un email válido';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final db = ref.read(videoDatabaseProvider);
      final code = await db.sendEmailVerification(widget.nick, email);
      
      setState(() {
        _codeSent = true;
        _isLoading = false;
        _sentCode = code; // Para testing
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📧 Código enviado a $email\n(Código: $code)'), // Temporal para testing
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al enviar código: $e';
      });
    }
  }
  
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    
    if (code.isEmpty || code.length != 6) {
      setState(() {
        _errorMessage = 'Ingresa el código de 6 dígitos';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final db = ref.read(videoDatabaseProvider);
      final success = await db.verifyEmailCode(widget.nick, code);
      
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email verificado exitosamente (+10 reputación)'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onVerified?.call();
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Código inválido o expirado';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al verificar: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.email, color: Colors.blue),
          SizedBox(width: 10),
          Text('Verificar Email'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_codeSent) ...[
              const Text(
                '✉️ Verifica tu email para:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Aumentar tu reputación +10 puntos'),
              const Text('• Quitar restricciones de video'),
              const Text('• Obtener badge de verificado'),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'tu@email.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
            ] else ...[
              Text(
                '📧 Código enviado a:\n${_emailController.text}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ingresa el código de 6 dígitos:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  hintText: '123456',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                maxLength: 6,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 10),
              Text(
                'Expira en 15 minutos',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
      actions: [
        if (_codeSent)
          TextButton(
            onPressed: _isLoading ? null : () {
              setState(() {
                _codeSent = false;
                _errorMessage = null;
                _codeController.clear();
              });
            },
            child: const Text('Cambiar Email'),
          ),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : (_codeSent ? _verifyCode : _sendCode),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(_codeSent ? 'Verificar' : 'Enviar Código'),
        ),
      ],
    );
  }
}

