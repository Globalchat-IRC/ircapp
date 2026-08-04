import 'dart:convert';

class PollOption {
  final String text;
  final int votes;
  final Set<String> votedNicks;

  PollOption({required this.text, this.votes = 0, Set<String>? votedNicks})
      : votedNicks = votedNicks ?? {};

  PollOption copyWith({String? text, int? votes, Set<String>? votedNicks}) {
    return PollOption(
      text: text ?? this.text,
      votes: votes ?? this.votes,
      votedNicks: votedNicks ?? this.votedNicks,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'votes': votes,
        'voted': votedNicks.toList(),
      };

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        text: json['text'] as String,
        votes: json['votes'] as int? ?? 0,
        votedNicks: Set<String>.from(json['voted'] as List? ?? []),
      );
}

class Poll {
  final String id;
  final String creator;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;
  final bool closed;

  Poll({
    required this.id,
    required this.creator,
    required this.question,
    required this.options,
    DateTime? createdAt,
    this.closed = false,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalVotes => options.fold(0, (sum, o) => sum + o.votes);

  bool hasVoted(String nick) => options.any((o) => o.votedNicks.contains(nick));

  PollOption? getOptionForNick(String nick) {
    for (final o in options) {
      if (o.votedNicks.contains(nick)) return o;
    }
    return null;
  }

  Poll copyWith({bool? closed, List<PollOption>? options}) {
    return Poll(
      id: id,
      creator: creator,
      question: question,
      options: options ?? this.options,
      createdAt: createdAt,
      closed: closed ?? this.closed,
    );
  }

  String toIrcMessage() {
    final data = {
      't': 'poll',
      'id': id,
      'q': question,
      'o': options.map((o) => o.text).toList(),
    };
    return '===POLL=== ${jsonEncode(data)} ===/POLL===';
  }

  static Poll? fromIrcMessage(String message) {
    final match = RegExp(r'===POLL===\s*(.+?)\s*===/POLL===').firstMatch(message);
    if (match == null) return null;
    try {
      final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      if (data['t'] != 'poll') return null;
      final optionTexts = (data['o'] as List).cast<String>();
      return Poll(
        id: data['id'] as String,
        creator: data['c'] as String? ?? '',
        question: data['q'] as String,
        options: optionTexts.map((t) => PollOption(text: t)).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static String voteMessage(String pollId, int optionIndex) {
    return '===VOTE=== ${jsonEncode({'id': pollId, 'v': optionIndex})} ===/VOTE===';
  }

  static Map<String, dynamic>? parseVote(String message) {
    final match = RegExp(r'===VOTE===\s*(.+?)\s*===/VOTE===').firstMatch(message);
    if (match == null) return null;
    try {
      return jsonDecode(match.group(1)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
