enum UserRole {
  trainer('trainer'),
  trainee('trainee');

  const UserRole(this.wireName);

  final String wireName;

  static UserRole? tryParse(Object? value) {
    if (value is! String) {
      return null;
    }

    for (final role in UserRole.values) {
      if (role.wireName == value) {
        return role;
      }
    }

    return null;
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.displayName,
    this.trainerUserId,
  });

  final String id;
  final String email;
  final UserRole role;
  final String displayName;
  final String? trainerUserId;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final role = UserRole.tryParse(json['role']);
    final displayName = json['displayName'];
    final trainerUserId = json['trainerUserId'];

    if (id is! String ||
        email is! String ||
        role == null ||
        displayName is! String ||
        (trainerUserId != null && trainerUserId is! String)) {
      throw const FormatException('Invalid auth user response body.');
    }

    return AuthUser(
      id: id,
      email: email,
      role: role,
      displayName: displayName,
      trainerUserId: trainerUserId,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAt = json['expiresAt'];
    final user = json['user'];

    if (accessToken is! String ||
        refreshToken is! String ||
        expiresAt is! String ||
        user is! Map<String, dynamic>) {
      throw const FormatException('Invalid auth session response body.');
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.parse(expiresAt).toUtc(),
      user: AuthUser.fromJson(user),
    );
  }
}

class RoleProbeResult {
  const RoleProbeResult({
    required this.role,
  });

  final UserRole role;

  factory RoleProbeResult.fromJson(Map<String, dynamic> json) {
    final role = UserRole.tryParse(json['role']);
    if (role == null) {
      throw const FormatException('Invalid role probe response body.');
    }

    return RoleProbeResult(role: role);
  }
}

class TrainerInviteCode {
  const TrainerInviteCode({
    required this.code,
  });

  final String code;

  factory TrainerInviteCode.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is! String) {
      throw const FormatException('Invalid trainer invite code response body.');
    }

    return TrainerInviteCode(code: code);
  }
}
