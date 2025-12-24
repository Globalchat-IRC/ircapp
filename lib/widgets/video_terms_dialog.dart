import 'package:flutter/material.dart';

/// Diálogo de términos y condiciones de videoconferencia
class VideoTermsDialog extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onReject;
  
  const VideoTermsDialog({
    Key? key,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);
  
  @override
  State<VideoTermsDialog> createState() => _VideoTermsDialogState();
}

class _VideoTermsDialogState extends State<VideoTermsDialog> {
  bool _hasScrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollPosition);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }
  
  void _checkScrollPosition() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToBottom) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Normas de Videoconferencia',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // Contenido desplazable
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWarningSection(),
                        const SizedBox(height: 20),
                        _buildProhibitedSection(),
                        const SizedBox(height: 20),
                        _buildConsequencesSection(),
                        const SizedBox(height: 20),
                        _buildModerationSection(),
                        const SizedBox(height: 20),
                        _buildDataSection(),
                        const SizedBox(height: 20),
                        _buildAcceptanceSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Indicador de scroll
            if (!_hasScrolledToBottom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Desplázate hasta el final para continuar',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onReject,
          child: const Text('Rechazar'),
        ),
        ElevatedButton(
          onPressed: _hasScrolledToBottom ? widget.onAccept : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: const Text('Acepto las normas'),
        ),
      ],
    );
  }
  
  Widget _buildWarningSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    '⚠️ ADVERTENCIA IMPORTANTE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Las videoconferencias son espacios públicos o semi-públicos. '
                'Tu comportamiento debe ser respetuoso y apropiado en todo momento.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildProhibitedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚫 CONTENIDO PROHIBIDO',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildProhibitedItem(
          '🔞 Contenido sexual o desnudos',
          'Está estrictamente prohibido mostrar contenido sexual, desnudos parciales '
          'o totales, o cualquier material pornográfico.',
        ),
        _buildProhibitedItem(
          '⚠️ Acoso o abuso',
          'No se tolerará el acoso, intimidación, amenazas o comportamiento abusivo '
          'hacia otros usuarios.',
        ),
        _buildProhibitedItem(
          '⚔️ Violencia',
          'Queda prohibido mostrar actos violentos, armas o amenazas de violencia.',
        ),
        _buildProhibitedItem(
          '📢 Spam o publicidad no deseada',
          'No uses las videoconferencias para hacer spam, publicidad comercial no autorizada '
          'o promoción de productos/servicios.',
        ),
        _buildProhibitedItem(
          '🎭 Suplantación de identidad',
          'No te hagas pasar por otra persona o entidad.',
        ),
      ],
    );
  }
  
  Widget _buildProhibitedItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConsequencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚖️ CONSECUENCIAS POR INCUMPLIMIENTO',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConsequenceItem('1️⃣', 'Expulsión inmediata de la videoconferencia'),
              _buildConsequenceItem('2️⃣', 'Suspensión temporal o permanente del servicio'),
              _buildConsequenceItem('3️⃣', 'Ban permanente de tu cuenta'),
              _buildConsequenceItem('4️⃣', 'Reporte a las autoridades competentes (casos graves)'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚠️ Las infracciones graves pueden ser reportadas a autoridades policiales '
                  'conforme a las leyes aplicables.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildConsequenceItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModerationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '👮 MODERACIÓN Y MONITOREO',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '• Las videoconferencias pueden ser monitoreadas por moderadores.\n\n'
          '• Los usuarios pueden reportar comportamiento inapropiado en cualquier momento.\n\n'
          '• Los moderadores tienen autoridad para expulsar usuarios y tomar acciones disciplinarias.\n\n'
          '• Tres (3) reportes automáticamente resultan en expulsión inmediata.\n\n'
          '• Se guardan registros (logs) de todas las conferencias para fines de seguridad.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
  
  Widget _buildDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔒 PRIVACIDAD Y DATOS',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          '• Las videoconferencias utilizan el servicio de Jitsi Meet (meet.jit.si).\n\n'
          '• Las videollamadas están encriptadas end-to-end.\n\n'
          '• No grabamos las conferencias por defecto (solo moderadores autorizados pueden grabar).\n\n'
          '• Los datos de conferencias (participantes, hora, duración) se guardan para auditoría.\n\n'
          '• Al usar este servicio, aceptas la política de privacidad de Jitsi Meet.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
  
  Widget _buildAcceptanceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✅ AL ACEPTAR ESTAS NORMAS, CONFIRMAS QUE:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '• Has leído y comprendido todas las normas anteriores.\n\n'
            '• Te comprometes a mantener un comportamiento apropiado y respetuoso.\n\n'
            '• Entiendes las consecuencias de incumplir estas normas.\n\n'
            '• Autorizas la moderación y monitoreo de tus videoconferencias.\n\n'
            '• Aceptas la política de privacidad y el uso de servicios de terceros (Jitsi Meet).',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

