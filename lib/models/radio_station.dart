class RadioStation {
  final String id;
  final String name;
  final String description;
  final String source;
  final String? namesite;
  final String? salon;
  final String? genre;
  final String? bitrate;
  final String? currentArtistSong;

  RadioStation({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    this.namesite,
    this.salon,
    this.genre,
    this.bitrate,
    this.currentArtistSong,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      id: json['id']?.toString() ?? json['name'] ?? '',
      name: json['name'] as String? ?? 'Radio',
      description: json['description'] as String? ?? '',
      source: json['source'] as String? ?? '',
      namesite: json['namesite'] as String?,
      salon: json['salon'] as String?,
      genre: json['genre'] as String?,
      bitrate: json['bitrate']?.toString(),
      currentArtistSong: json['currentArtistSong'] as String?,
    );
  }
}



