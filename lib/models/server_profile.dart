class ServerProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool useSSL;
  final bool isDefault;

  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.useSSL = false,
    this.isDefault = false,
  });

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? useSSL,
    bool? isDefault,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      useSSL: useSSL ?? this.useSSL,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static List<ServerProfile> defaultGlobalChatProfiles = [
    const ServerProfile(
      id: 'gc-ceres-6667',
      name: 'GlobalChat · Ceres (6667)',
      host: 'ceres.globalchat.org',
      port: 6667,
      useSSL: false,
      isDefault: true,
    ),
    const ServerProfile(
      id: 'gc-ceres-6697',
      name: 'GlobalChat · Ceres (6697 SSL)',
      host: 'ceres.globalchat.org',
      port: 6697,
      useSSL: true,
    ),
    const ServerProfile(
      id: 'gc-apolo-6667',
      name: 'GlobalChat · Apolo (6667)',
      host: 'apolo.globalchat.org',
      port: 6667,
      useSSL: false,
    ),
    const ServerProfile(
      id: 'gc-apolo-6697',
      name: 'GlobalChat · Apolo (6697 SSL)',
      host: 'apolo.globalchat.org',
      port: 6697,
      useSSL: true,
    ),
    const ServerProfile(
      id: 'gc-creta-6667',
      name: 'GlobalChat · Creta (6667)',
      host: 'creta.globalchat.org',
      port: 6667,
      useSSL: false,
    ),
    const ServerProfile(
      id: 'gc-creta-6697',
      name: 'GlobalChat · Creta (6697 SSL)',
      host: 'creta.globalchat.org',
      port: 6697,
      useSSL: true,
    ),
    const ServerProfile(
      id: 'gc-caliope-6667',
      name: 'GlobalChat · Caliope (6667)',
      host: 'caliope.globalchat.org',
      port: 6667,
      useSSL: false,
    ),
    const ServerProfile(
      id: 'gc-caliope-6697',
      name: 'GlobalChat · Caliope (6697 SSL)',
      host: 'caliope.globalchat.org',
      port: 6697,
      useSSL: true,
    ),
  ];
}








