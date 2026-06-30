class UserModel {
  final int id;
  final int orgId;
  final String login;
  final String role;
  final String? teacherName;

  const UserModel({
    required this.id,
    required this.orgId,
    required this.login,
    required this.role,
    this.teacherName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        orgId: json['org_id'] as int,
        login: json['login'] as String,
        role: json['role'] as String,
        teacherName: json['teacher_name'] as String?,
      );

  String get displayName => teacherName ?? login;
  bool get isAdmin => role == 'ADMIN';
  bool get isTeacher => role == 'TEACHER';
}
