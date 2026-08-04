import 'package:flutter/material.dart';
import '../models/gift_config.dart';
import '../models/app_theme.dart';
import '../services/global_points_service.dart';

class GiftPicker extends StatefulWidget {
  final Function(GiftItem gift, String recipient) onGiftSelected;
  final AppTheme appTheme;
  final GlobalPointsService pointsService;
  final String targetNick;

  const GiftPicker({
    super.key,
    required this.onGiftSelected,
    required this.appTheme,
    required this.pointsService,
    required this.targetNick,
  });

  @override
  State<GiftPicker> createState() => _GiftPickerState();
}

class _GiftPickerState extends State<GiftPicker> {
  late final TextEditingController _recipientController;

  @override
  void initState() {
    super.initState();
    _recipientController = TextEditingController(text: widget.targetNick);
  }

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = widget.appTheme;
    final pointsService = widget.pointsService;

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: appTheme.surface,
        border: Border(
          top: BorderSide(
            color: appTheme.textSecondary.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.card_giftcard, size: 18, color: appTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Enviar regalo',
                      style: TextStyle(
                        color: appTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('\u2666', style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
                          const SizedBox(width: 3),
                          Text(
                            '${pointsService.points} GP',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => widget.onGiftSelected(GiftItem(id: -1, name: '', icon: '', value: 0), ''),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: appTheme.textSecondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close, size: 16, color: appTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _recipientController,
                  style: TextStyle(color: appTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enviar a (nick)',
                    hintStyle: TextStyle(color: appTheme.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.person, size: 16, color: appTheme.textSecondary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: appTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.85,
              ),
              itemCount: GiftConfig.gifts.length,
              itemBuilder: (context, index) {
                final gift = GiftConfig.gifts[index];
                final canAfford = pointsService.canAfford(gift.value);
                final enabled = canAfford;
                return GestureDetector(
                  onTap: enabled
                      ? () => widget.onGiftSelected(gift, _recipientController.text.trim())
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Necesitas ${gift.value} GP para ${gift.name} (tienes ${pointsService.points} GP)',
                                style: const TextStyle(fontSize: 13),
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: appTheme.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: enabled
                          ? appTheme.background
                          : appTheme.background.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: enabled
                            ? appTheme.textSecondary.withValues(alpha: 0.5)
                            : appTheme.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          gift.icon,
                          style: TextStyle(
                            fontSize: 32,
                            color: enabled ? null : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gift.name,
                          style: TextStyle(
                            fontSize: 11,
                            color: enabled
                                ? appTheme.textPrimary
                                : appTheme.textSecondary,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: enabled
                                ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${gift.value}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: enabled ? const Color(0xFFFFD700) : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
