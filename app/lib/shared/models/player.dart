class SkillStats {
  final int xp;
  final int level;
  const SkillStats({required this.xp, required this.level});

  factory SkillStats.fromJson(Map<String, dynamic> j) =>
      SkillStats(xp: (j['xp'] as num?)?.toInt() ?? 0, level: (j['level'] as num?)?.toInt() ?? 0);
}

class PlayerStats {
  final String uuid;
  final String name;
  final double balance;
  final int playtime;
  final Map<String, SkillStats> skills;
  final String group;

  const PlayerStats({
    required this.uuid,
    required this.name,
    required this.balance,
    required this.playtime,
    required this.skills,
    required this.group,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> j) {
    final rawSkills = (j['skills'] as Map<String, dynamic>?) ?? {};
    final skills = rawSkills.map((k, v) =>
        MapEntry(k, SkillStats.fromJson(v as Map<String, dynamic>)));
    return PlayerStats(
      uuid:     j['uuid'] as String? ?? '',
      name:     j['name'] as String? ?? j['username'] as String? ?? '',
      balance:  (j['balance'] as num?)?.toDouble() ?? 0,
      playtime: (j['playtime'] as num?)?.toInt() ?? 0,
      skills:   skills,
      group:    j['group'] as String? ?? 'jucator',
    );
  }
}

class Achievement {
  final String id;
  final String icon;
  final String name;
  final String desc;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.icon,
    required this.name,
    required this.desc,
    required this.unlocked,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        id:       j['id'] as String,
        icon:     j['icon'] as String,
        name:     j['name'] as String,
        desc:     j['desc'] as String,
        unlocked: j['unlocked'] as bool? ?? false,
      );
}
