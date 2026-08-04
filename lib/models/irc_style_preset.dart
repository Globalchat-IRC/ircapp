import 'package:flutter/material.dart';

class IrcStylePreset {
  final String id;
  final String name;
  final String emoji;
  final Color nickColor;
  final Color messageColor;
  final Color timestampColor;
  final Color? backgroundColor;
  final Color? highlightColor;
  final String? fontFamily;
  final double? fontSize;

  const IrcStylePreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.nickColor,
    required this.messageColor,
    this.timestampColor = const Color(0xFF888888),
    this.backgroundColor,
    this.highlightColor,
    this.fontFamily,
    this.fontSize,
  });

  static const List<IrcStylePreset> presets = [
    IrcStylePreset(
      id: 'default',
      name: 'Clásico',
      emoji: '💬',
      nickColor: Color(0xFF00CC66),
      messageColor: Color(0xFFCCCCCC),
      timestampColor: Color(0xFF666666),
    ),
    IrcStylePreset(
      id: 'matrix',
      name: 'Matrix',
      emoji: '🟢',
      nickColor: Color(0xFF00FF41),
      messageColor: Color(0xFF00CC33),
      timestampColor: Color(0xFF006619),
      highlightColor: Color(0xFF00FF41),
      fontFamily: 'monospace',
    ),
    IrcStylePreset(
      id: 'neon',
      name: 'Neon Green',
      emoji: '💚',
      nickColor: Color(0xFF39FF14),
      messageColor: Color(0xFFB9FF66),
      timestampColor: Color(0xFF1A8A00),
      highlightColor: Color(0xFF39FF14),
    ),
    IrcStylePreset(
      id: 'fuego',
      name: 'Fuego',
      emoji: '🔥',
      nickColor: Color(0xFFFF6600),
      messageColor: Color(0xFFFFCC00),
      timestampColor: Color(0xFFCC3300),
      highlightColor: Color(0xFFFF4500),
    ),
    IrcStylePreset(
      id: 'cyberpunk',
      name: 'Cyberpunk',
      emoji: '🤖',
      nickColor: Color(0xFF00FFFF),
      messageColor: Color(0xFFFF00FF),
      timestampColor: Color(0xFF660066),
      highlightColor: Color(0xFF00FFFF),
    ),
    IrcStylePreset(
      id: 'sunset',
      name: 'Sunset',
      emoji: '🌅',
      nickColor: Color(0xFFFF6B6B),
      messageColor: Color(0xFFFFE66D),
      timestampColor: Color(0xFFFF8E53),
      highlightColor: Color(0xFFFF6B6B),
    ),
    IrcStylePreset(
      id: 'ocean',
      name: 'Ocean',
      emoji: '🌊',
      nickColor: Color(0xFF0077B6),
      messageColor: Color(0xFF90E0EF),
      timestampColor: Color(0xFF023E8A),
      highlightColor: Color(0xFF00B4D8),
    ),
    IrcStylePreset(
      id: 'purple',
      name: 'Purple Haze',
      emoji: '🟣',
      nickColor: Color(0xFFBB86FC),
      messageColor: Color(0xFFE0B0FF),
      timestampColor: Color(0xFF6200EA),
      highlightColor: Color(0xFFBB86FC),
    ),
    IrcStylePreset(
      id: 'hacker',
      name: 'Hacker',
      emoji: '💻',
      nickColor: Color(0xFF00FF00),
      messageColor: Color(0xFF00CC00),
      timestampColor: Color(0xFF003300),
      fontFamily: 'monospace',
      highlightColor: Color(0xFF00FF00),
    ),
    IrcStylePreset(
      id: 'candy',
      name: 'Candy',
      emoji: '🍬',
      nickColor: Color(0xFFFF69B4),
      messageColor: Color(0xFFFFB6C1),
      timestampColor: Color(0xFFDB7093),
      highlightColor: Color(0xFFFF1493),
    ),
    IrcStylePreset(
      id: 'ice',
      name: 'Ice',
      emoji: '🧊',
      nickColor: Color(0xFFB3E5FC),
      messageColor: Color(0xFFE1F5FE),
      timestampColor: Color(0xFF4FC3F7),
      highlightColor: Color(0xFF03A9F4),
    ),
    IrcStylePreset(
      id: 'retro',
      name: 'Retro',
      emoji: '👾',
      nickColor: Color(0xFFFF0080),
      messageColor: Color(0xFFFFFF00),
      timestampColor: Color(0xFF00FFFF),
      fontFamily: 'monospace',
      highlightColor: Color(0xFFFF0080),
    ),
    IrcStylePreset(
      id: 'forest',
      name: 'Forest',
      emoji: '🌲',
      nickColor: Color(0xFF2E7D32),
      messageColor: Color(0xFFA5D6A7),
      timestampColor: Color(0xFF1B5E20),
      highlightColor: Color(0xFF4CAF50),
    ),
    IrcStylePreset(
      id: 'blood',
      name: 'Blood',
      emoji: '🩸',
      nickColor: Color(0xFFFF1744),
      messageColor: Color(0xFFFFCDD2),
      timestampColor: Color(0xFFB71C1C),
      highlightColor: Color(0xFFD50000),
    ),
    IrcStylePreset(
      id: 'galaxy',
      name: 'Galaxy',
      emoji: '🌌',
      nickColor: Color(0xFF7C4DFF),
      messageColor: Color(0xFFB388FF),
      timestampColor: Color(0xFF311B92),
      highlightColor: Color(0xFF651FFF),
    ),
    IrcStylePreset(
      id: 'gold',
      name: 'Gold',
      emoji: '✨',
      nickColor: Color(0xFFFFD700),
      messageColor: Color(0xFFFFF8E1),
      timestampColor: Color(0xFFFF8F00),
      highlightColor: Color(0xFFFFD700),
    ),
  ];

  static IrcStylePreset getById(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }
}
