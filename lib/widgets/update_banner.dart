import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/update_provider.dart';

/// Banner de actualización disponible
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    
    // No mostrar banner si no hay actualización
    if (updateState.updateAvailable == null) {
      return const SizedBox.shrink();
    }
    
    final update = updateState.updateAvailable!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.blue.shade700,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.system_update,
              color: Colors.white,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Información
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Nueva versión disponible!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Versión ${update.latestVersion} • ${update.formattedDate}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // Botones
          if (updateState.isDownloading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else ...[
            // Botón Ver detalles
            TextButton(
              onPressed: () => _showUpdateDialog(context, ref, update),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Ver detalles'),
            ),
            
            const SizedBox(width: 8),
            
            // Botón Actualizar
            ElevatedButton(
              onPressed: () {
                ref.read(updateProvider.notifier).downloadAndInstall();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Actualizar'),
            ),
            
            const SizedBox(width: 8),
            
            // Botón cerrar
            IconButton(
              onPressed: () {
                ref.read(updateProvider.notifier).dismissUpdate();
              },
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Cerrar',
            ),
          ],
        ],
      ),
    );
  }
  
  void _showUpdateDialog(BuildContext context, WidgetRef ref, update) {
    showDialog(
      context: context,
      builder: (context) => UpdateDialog(update: update),
    );
  }
}

/// Diálogo con detalles de la actualización
class UpdateDialog extends ConsumerWidget {
  final dynamic update;
  
  const UpdateDialog({super.key, required this.update});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.system_update,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nueva actualización',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Versiones
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Versión actual',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        update.currentVersion,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Nueva versión',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        update.latestVersion,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Fecha de publicación
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Publicado ${update.formattedDate}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Notas de la versión
            const Text(
              'Notas de la versión:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  update.releaseNotes,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Más tarde'),
        ),
        if (updateState.isDownloading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ref.read(updateProvider.notifier).downloadAndInstall();
            },
            icon: const Icon(Icons.download),
            label: const Text('Descargar actualización'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}

/// Widget para mostrar botón de verificar actualizaciones en configuración
class CheckUpdateButton extends ConsumerWidget {
  const CheckUpdateButton({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);
    
    return ListTile(
      leading: const Icon(Icons.system_update),
      title: const Text('Buscar actualizaciones'),
      subtitle: updateState.isChecking
          ? const Text('Verificando...')
          : updateState.updateAvailable != null
              ? Text('Versión ${updateState.updateAvailable!.latestVersion} disponible')
              : const Text('Verificar si hay nuevas versiones'),
      trailing: updateState.isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : updateState.updateAvailable != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Disponible',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )
              : null,
      onTap: updateState.isChecking
          ? null
          : () {
              ref.read(updateProvider.notifier).checkForUpdates(forceCheck: true);
            },
    );
  }
}

