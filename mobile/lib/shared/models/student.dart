class StudentModel {
  final int id;
  final int orgId;
  final String firstName;
  final String lastName;
  final String? phone;
  final String status;
  final String? note;
  final bool isForeign;
  final DateTime createdAt;
  /// Present when loaded by a TEACHER — the StudentTeacher link id.
  final int? studentTeacherId;

  const StudentModel({
    required this.id,
    required this.orgId,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.status,
    this.note,
    this.isForeign = false,
    required this.createdAt,
    this.studentTeacherId,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(
        id: json['id'] as int,
        orgId: json['org_id'] as int,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        phone: json['phone'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        note: json['note'] as String?,
        isForeign: (json['is_foreign'] as bool?) ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String) ?? DateTime(2024)
            : DateTime(2024),
        studentTeacherId: json['student_teacher_id'] as int?,
      );

  String get fullName => '$firstName $lastName';

  // Initials for avatar
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }
}
