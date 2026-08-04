import 'package:flutter/material.dart';

enum NickAura {
  none('Sin aura', '', Colors.transparent),
  heart('Corazón', '❤️', Colors.red),
  kiss('Beso', '💋', Colors.pink),
  storm('Tormenta', '⛈️', Colors.deepPurple),
  stars('Estrellas', '⭐', Colors.amber),
  notes('Notas', '🎵', Colors.blue),
  moons('Lunas', '🌙', Colors.indigo),
  flowers('Flores', '🌸', Colors.pinkAccent),
  butterflies('Mariposas', '🦋', Colors.teal),
  fire('Fuego', '🔥', Colors.deepOrange),
  airplane('Avión', '✈️', Colors.cyan),
  sunny('Soleado', '☀️', Colors.orange);

  final String label;
  final String emoji;
  final Color glowColor;

  const NickAura(this.label, this.emoji, this.glowColor);

  static NickAura fromId(String id) {
    for (final aura in values) {
      if (aura.name == id) return aura;
    }
    return NickAura.none;
  }
}
