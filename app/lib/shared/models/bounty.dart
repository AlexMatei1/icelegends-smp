class Bounty {
  final int id;
  final String placerName;
  final String targetName;
  final int amount;
  final int placedAt;
  final String status;
  final String? claimedBy;

  const Bounty({
    required this.id,
    required this.placerName,
    required this.targetName,
    required this.amount,
    required this.placedAt,
    required this.status,
    this.claimedBy,
  });

  factory Bounty.fromJson(Map<String, dynamic> j) => Bounty(
        id:          (j['id'] as num).toInt(),
        placerName:  j['placer_name'] as String,
        targetName:  j['target_name'] as String,
        amount:      (j['amount'] as num).toInt(),
        placedAt:    (j['placed_at'] as num).toInt(),
        status:      j['status'] as String,
        claimedBy:   j['claimed_by'] as String?,
      );
}
