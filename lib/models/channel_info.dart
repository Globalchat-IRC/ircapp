class ChannelInfo {
  final String name;
  final int users;
  final String topic;

  ChannelInfo({
    required this.name,
    required this.users,
    required this.topic,
  });

  // Limpiar HTML básico del topic
  static String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remover etiquetas HTML
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  factory ChannelInfo.fromJson(Map<String, dynamic> json) {
    final rawTopic = json['topic'] as String? ?? '';
    return ChannelInfo(
      name: json['name'] as String? ?? '',
      users: json['users'] as int? ?? 0,
      topic: _cleanHtml(rawTopic),
    );
  }
}

