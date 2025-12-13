class RadioStation {
  final String id;
  final String name;
  final String description;
  final String source;
  final String? currentArtistSong;
  final String? namesite;
  final String? salon;
  final String? genre;
  final String? bitrate;
  final String? favicon;

  RadioStation({
    required this.id,
    required this.name,
    required this.description,
    required this.source,
    this.currentArtistSong,
    this.namesite,
    this.salon,
    this.genre,
    this.bitrate,
    this.favicon,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    // El JSON real tiene campos diferentes, adaptar ambos formatos
    return RadioStation(
      id: json['id']?.toString() ?? 
          (json['name']?.toString().hashCode.toString() ?? ''),
      name: json['name'] ?? '',
      description: json['description'] ?? json['genre'] ?? '',
      source: json['source'] ?? '',
      currentArtistSong: json['current_artist_song'] ?? json['current_song'],
      namesite: json['namesite'] ?? json['description'],
      salon: json['salon'],
      genre: json['genre'],
      bitrate: json['bitrate'],
      favicon: json['favicon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'source': source,
      'current_artist_song': currentArtistSong,
      'namesite': namesite,
      'salon': salon,
      'genre': genre,
      'bitrate': bitrate,
      'favicon': favicon,
    };
  }
}

