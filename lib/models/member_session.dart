class MemberSession {
  const MemberSession({
    required this.suuid,
    required this.accessToken,
    this.name,
  });

  final String suuid;
  final String accessToken;
  final String? name;

  Map<String, String> get memberAuth => {
        'suuid': suuid,
        'accessToken': accessToken,
      };

  MemberSession copyWith({String? name}) {
    return MemberSession(
      suuid: suuid,
      accessToken: accessToken,
      name: name ?? this.name,
    );
  }
}
