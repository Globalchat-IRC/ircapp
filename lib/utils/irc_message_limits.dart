import 'dart:convert';

import 'package:flutter/services.dart';

/// RFC 1459/2812: longitud máxima de una línea IRC (sin el `\r\n` final).
const int kIrcMaxLineBytes = 510;

/// Bytes disponibles para el cuerpo de un PRIVMSG/NOTICE (`:payload` + sufijo opcional).
int ircPrivmsgMaxPayloadBytes(String target, {String extraSuffix = ''}) {
  final prefix = 'PRIVMSG ${target.trim()} :';
  final used = utf8.encode(prefix).length + utf8.encode(extraSuffix).length;
  final available = kIrcMaxLineBytes - used;
  return available > 0 ? available : 0;
}

int ircNoticeMaxPayloadBytes(String target, {String extraSuffix = ''}) {
  final prefix = 'NOTICE ${target.trim()} :';
  final used = utf8.encode(prefix).length + utf8.encode(extraSuffix).length;
  final available = kIrcMaxLineBytes - used;
  return available > 0 ? available : 0;
}

/// Parte un texto en trozos que no superen [maxBytes] bytes UTF-8, sin
/// cortar caracteres multibyte por la mitad. Devuelve al menos un trozo.
List<String> chunkUtf8ByBytes(String text, int maxBytes) {
  if (maxBytes <= 0) return [text];
  final encoded = utf8.encode(text);
  if (encoded.length <= maxBytes) return [text];

  final chunks = <String>[];
  var start = 0;
  while (start < encoded.length) {
    var end = (start + maxBytes).clamp(0, encoded.length);
    // Retroceder si cortamos en mitad de un carácter multibyte.
    while (end > start &&
        end < encoded.length &&
        (encoded[end] & 0xC0) == 0x80) {
      end--;
    }
    if (end <= start) {
      end = (start + maxBytes).clamp(0, encoded.length);
    }
    chunks.add(utf8.decode(encoded.sublist(start, end)));
    start = end;
  }
  return chunks;
}

String truncateUtf8ToBytes(String text, int maxBytes) {
  if (maxBytes <= 0) return '';
  final encoded = utf8.encode(text);
  if (encoded.length <= maxBytes) return text;

  var end = maxBytes;
  while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
    end--;
  }
  if (end <= 0) return '';
  return utf8.decode(encoded.sublist(0, end));
}

class IrcMessageLengthFormatter extends TextInputFormatter {
  final int maxBytes;

  const IrcMessageLengthFormatter(this.maxBytes);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (maxBytes <= 0) return oldValue;
    if (utf8.encode(newValue.text).length <= maxBytes) return newValue;

    final truncated = truncateUtf8ToBytes(newValue.text, maxBytes);
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}
