class CustomAction {
  final String emoji;
  final String label;

  const CustomAction({
    required this.emoji,
    required this.label,
  });

  factory CustomAction.fromJson(Map<String, dynamic> json) {
    return CustomAction(
      emoji: json['emoji'] as String,
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'label': label,
      };
}
