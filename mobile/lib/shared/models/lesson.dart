import '../../core/theme/nebula_colors.dart';
import 'package:flutter/material.dart';

class LessonModel {
  final int id;
  final int orgId;
  final int studentTeacherId;
  final int? subscriptionId;
  final String lessonType;    // regular / makeup
  final int? makeupForId;     // id оригинала (только для makeup)
  final DateTime scheduledDate;
  final String? scheduledTime;
  final String status;         // scheduled / attended / missed / cancelled
  final String? cancelledBy;
  final String makeupStatus;   // none / scheduled / done / burned / transferred
  final DateTime? makeupDate;
  final bool paymentCounted;
  final String? notes;

  // Joined fields (from API)
  final String? studentName;
  final String? instrumentName;

  const LessonModel({
    required this.id,
    required this.orgId,
    required this.studentTeacherId,
    this.subscriptionId,
    this.lessonType = 'regular',
    this.makeupForId,
    required this.scheduledDate,
    this.scheduledTime,
    required this.status,
    this.cancelledBy,
    required this.makeupStatus,
    this.makeupDate,
    required this.paymentCounted,
    this.notes,
    this.studentName,
    this.instrumentName,
  });

  bool get isMakeup => lessonType == 'makeup';

  factory LessonModel.fromJson(Map<String, dynamic> json) => LessonModel(
        id: json['id'] as int,
        orgId: json['org_id'] as int,
        studentTeacherId: json['student_teacher_id'] as int,
        subscriptionId: json['subscription_id'] as int?,
        lessonType: json['lesson_type'] as String? ?? 'regular',
        makeupForId: json['makeup_for_id'] as int?,
        scheduledDate: DateTime.parse(json['scheduled_date'] as String),
        scheduledTime: _formatTime(json['scheduled_time'] as String?),
        status: json['status'] as String,
        cancelledBy: json['cancelled_by'] as String?,
        makeupStatus: json['makeup_status'] as String? ?? 'none',
        makeupDate: json['makeup_date'] != null
            ? DateTime.parse(json['makeup_date'] as String)
            : null,
        paymentCounted: json['payment_counted'] as bool? ?? false,
        notes: json['notes'] as String?,
        studentName: json['student_name'] as String?,
        instrumentName: json['instrument_name'] as String?,
      );

  Color get statusColor => NebulaColors.lessonStatus(status);

  static String? _formatTime(String? raw) {
    if (raw == null) return null;
    // "17:15:00" → "17:15", "17:15" → "17:15"
    final parts = raw.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return raw;
  }

  bool get isToday {
    final now = DateTime.now();
    return scheduledDate.year == now.year &&
        scheduledDate.month == now.month &&
        scheduledDate.day == now.day;
  }
}
