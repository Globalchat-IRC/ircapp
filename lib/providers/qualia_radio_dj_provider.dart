import '../models/irc_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nick del DJ en directo en #QualiaRadio (null si no hay nadie al aire).
final qualiaRadioLiveDjProvider =
    NotifierProvider<QualiaRadioLiveDjNotifier, String?>(
  QualiaRadioLiveDjNotifier.new,
);

class QualiaRadioLiveDjNotifier extends Notifier<String?> {
  // El DJ en vivo puede detectarse por dos vías:
  //  - El stream en directo (API AzuraCast: streamer_name) → fuente principal.
  //  - Los mensajes de Orion en el canal → respaldo / inmediatez.
  // La API tiene prioridad porque persiste al salir y volver a entrar al canal.
  String? _fromApi;
  String? _fromOrion;

  @override
  String? build() => null;

  void _recompute() {
    state = _fromApi ?? _fromOrion;
  }

  /// Actualiza el DJ a partir del estado del stream en vivo (API).
  void applyLiveStreamer(String? streamerName) {
    final value = streamerName?.trim();
    _fromApi = (value != null && value.isNotEmpty) ? value : null;
    _recompute();
  }

  /// Procesa mensajes de Orion en #QualiaRadio para actualizar el DJ en vivo.
  void processOrionMessage(IRCMessage message) {
    final update = parseQualiaRadioDjOrionMessage(message);
    if (update == null) return;
    switch (update) {
      case QualiaDjUpdateLive(:final nick):
        _fromOrion = nick;
      case QualiaDjUpdateClear():
        _fromOrion = null;
      case QualiaDjUpdateClearDj():
        _fromOrion = null;
    }
    _recompute();
  }
}

sealed class QualiaDjUpdate {}

class QualiaDjUpdateLive extends QualiaDjUpdate {
  QualiaDjUpdateLive(this.nick);
  final String nick;
}

class QualiaDjUpdateClear extends QualiaDjUpdate {}

class QualiaDjUpdateClearDj extends QualiaDjUpdate {
  QualiaDjUpdateClearDj(this.nick);
  final String nick;
}

/// Quita códigos de formato IRC del texto de Orion.
String stripQualiaIrcFormatting(String input) {
  var s = input;
  s = s.replaceAll(RegExp('\u0003\\d{0,2}(,\\d{1,2})?'), '');
  s = s.replaceAll(RegExp('\u0004[0-9A-Fa-f]{0,6}'), '');
  s = s.replaceAll(RegExp('[\u0000-\u001F]'), '');
  s = s.replaceAll('\uFFFD', '');
  s = s.replaceAll(RegExp(r'\s{2,}'), ' ');
  return s.trim();
}

/// Extrae el nick del DJ de un mensaje "En vivo dj X dj está al aire".
String? parseQualiaRadioLiveDjName(String raw) {
  final text = stripQualiaIrcFormatting(raw);
  final patterns = [
    RegExp(
      r'en\s+vivo.*?dj\s+(.+?)\s+dj\s+est[aá]\s+al\s+aire',
      caseSensitive: false,
    ),
    RegExp(
      r'en\s+vivo.*?dj\s+(.+?)\s+est[aá]\s+al\s+aire',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final nick = match.group(1)?.trim();
      if (nick != null && nick.isNotEmpty) return nick;
    }
  }
  return null;
}

/// Extrae el nick del DJ de "Nombre dj se desconectó - ahora suena música automatizada."
String? parseQualiaRadioDjOffName(String raw) {
  final text = stripQualiaIrcFormatting(raw);
  final patterns = [
    RegExp(
      r'^(.+?)\s+dj\s+se\s+desconect',
      caseSensitive: false,
    ),
    RegExp(
      r'(.+?)\s+dj\s+se\s+desconect',
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final nick = match.group(1)?.trim();
      if (nick != null && nick.isNotEmpty) return nick;
    }
  }
  return null;
}

bool isQualiaRadioDjOffOrionMessage(IRCMessage message) {
  if (message.isSystem) return false;
  if (message.channel.toLowerCase() != '#qualiaradio') return false;
  if (message.nick.toLowerCase() != 'orion') return false;
  final lower = stripQualiaIrcFormatting(message.message).toLowerCase();
  return lower.contains('se desconect') &&
      (lower.contains('musica automatizada') ||
          lower.contains('música automatizada') ||
          lower.contains('automatizada'));
}

QualiaDjUpdate? parseQualiaRadioDjOrionMessage(IRCMessage message) {
  if (message.isSystem) return null;
  if (message.channel.toLowerCase() != '#qualiaradio') return null;
  if (message.nick.toLowerCase() != 'orion') return null;

  final text = stripQualiaIrcFormatting(message.message);
  final lower = text.toLowerCase();

  final liveNick = parseQualiaRadioLiveDjName(message.message);
  if (liveNick != null) {
    return QualiaDjUpdateLive(liveNick);
  }

  // "Nombre dj se desconectó - ahora suena música automatizada."
  final offNick = parseQualiaRadioDjOffName(message.message);
  if (offNick != null &&
      (lower.contains('se desconect') ||
          lower.contains('musica automatizada') ||
          lower.contains('música automatizada'))) {
    return QualiaDjUpdateClearDj(offNick);
  }

  // DJ se desconecta / deja la cabina.
  if (lower.contains('fuera de antena') ||
      lower.contains('sin dj') ||
      lower.contains('ya no hay dj') ||
      lower.contains('cabina libre') ||
      lower.contains('no hay dj')) {
    return QualiaDjUpdateClear();
  }

  final offMatch = RegExp(
    r'(.+?)\s+dj\s+(?:se\s+ha\s+)?(?:desconect|deslogue|salid|termin|dej[aá])',
    caseSensitive: false,
  ).firstMatch(text);
  if (offMatch != null) {
    return QualiaDjUpdateClearDj(offMatch.group(1)!.trim());
  }

  if (lower.contains('dj') &&
      (lower.contains('desconect') ||
          lower.contains('deslogue') ||
          lower.contains('ha terminado') ||
          lower.contains('deja la cabina'))) {
    return QualiaDjUpdateClear();
  }

  return null;
}

bool isQualiaRadioDjLiveOrionMessage(IRCMessage message) {
  if (message.isSystem) return false;
  if (message.channel.toLowerCase() != '#qualiaradio') return false;
  if (message.nick.toLowerCase() != 'orion') return false;
  final lower = stripQualiaIrcFormatting(message.message).toLowerCase();
  return lower.contains('en vivo') &&
      lower.contains('dj') &&
      lower.contains('al aire');
}
