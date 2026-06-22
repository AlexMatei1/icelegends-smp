class War {
  final int id;
  final String challengerName;
  final String targetName;
  final int stake;
  final String status;
  final int challengerKills;
  final int targetKills;
  final String? winnerName;
  final int declaredAt;

  const War({
    required this.id,
    required this.challengerName,
    required this.targetName,
    required this.stake,
    required this.status,
    required this.challengerKills,
    required this.targetKills,
    required this.declaredAt,
    this.winnerName,
  });

  factory War.fromJson(Map<String, dynamic> j) => War(
        id:              (j['id'] as num).toInt(),
        challengerName:  j['challenger_name'] as String,
        targetName:      j['target_name'] as String,
        stake:           (j['stake'] as num?)?.toInt() ?? 0,
        status:          j['status'] as String,
        challengerKills: (j['challenger_kills'] as num?)?.toInt() ?? 0,
        targetKills:     (j['target_kills'] as num?)?.toInt() ?? 0,
        winnerName:      j['winner_name'] as String?,
        declaredAt:      (j['declared_at'] as num).toInt(),
      );
}
