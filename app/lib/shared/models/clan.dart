class ClanMember {
  final String uuid;
  final String username;
  final String role;
  final int joinedAt;

  const ClanMember({
    required this.uuid,
    required this.username,
    required this.role,
    required this.joinedAt,
  });

  factory ClanMember.fromJson(Map<String, dynamic> j) => ClanMember(
        uuid:     j['uuid'] as String,
        username: j['username'] as String,
        role:     j['role'] as String? ?? 'member',
        joinedAt: (j['joined_at'] as num).toInt(),
      );
}

class Clan {
  final int id;
  final String name;
  final String tag;
  final String ownerName;
  final String description;
  final int members;
  final int wins;
  final List<ClanMember> memberList;

  const Clan({
    required this.id,
    required this.name,
    required this.tag,
    required this.ownerName,
    required this.description,
    required this.members,
    required this.wins,
    this.memberList = const [],
  });

  factory Clan.fromJson(Map<String, dynamic> j) => Clan(
        id:          (j['id'] as num).toInt(),
        name:        j['name'] as String,
        tag:         j['tag'] as String,
        ownerName:   j['owner_name'] as String,
        description: j['description'] as String? ?? '',
        members:     (j['members'] as num?)?.toInt() ?? 0,
        wins:        (j['wins'] as num?)?.toInt() ?? 0,
        memberList:  (j['members'] is List)
            ? (j['members'] as List).map((e) => ClanMember.fromJson(e as Map<String, dynamic>)).toList()
            : [],
      );
}
