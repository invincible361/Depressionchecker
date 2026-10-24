import 'package:supabase_flutter/supabase_flutter.dart';

typedef DbRecord = Map<String, dynamic>;
SupabaseClient get db => Supabase.instance.client;

class Api {
  static Future<String> role() async => (await db.rpc('mw_role')) as String;
  static Future<DbRecord?> profile() => db
      .from('mw_profiles')
      .select()
      .eq('user_id', db.auth.currentUser!.id)
      .maybeSingle();
  static Future<List<DbRecord>> read(String table, {String? studentId}) async {
    final collected = <DbRecord>[];
    for (var offset = 0; ; offset += 500) {
      var query = db.from(table).select();
      if (studentId != null) query = query.eq('student_id', studentId);
      // Primary-key ordering makes pagination deterministic for a stable dataset.
      final result = await query
          .order(
            table == 'mw_cases'
                ? 'student_id'
                : table == 'mw_profiles'
                ? 'user_id'
                : 'id',
          )
          .range(offset, offset + 499);
      collected.addAll(List<DbRecord>.from(result));
      if (result.length < 500) return collected;
    }
  }

  static Future<List<DbRecord>> assessments(String student) async {
    final rows = await read('mw_assessments', studentId: student);
    rows.sort(
      (a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String),
    );
    return rows;
  }

  static Future<List<DbRecord>> questions() async =>
      List<DbRecord>.from(await db.from('mw_questionnaires').select().order('code'));
  static Future<void> saveProfile(String name, int age, String contact) async {
    await db.rpc(
      'mw_save_profile',
      params: {
        'p_name': name,
        'p_age': age,
        'p_contact': contact,
        'p_consent': true,
      },
    );
  }

  static Future<DbRecord> saveAssessment(DbRecord payload) async =>
      DbRecord.from(await db.rpc('mw_save_assessment', params: payload));
  static Future<List<DbRecord>> queue() async =>
      List<DbRecord>.from(await db.rpc('mw_queue'));
  static Future<List<DbRecord>> directory() async =>
      List<DbRecord>.from(await db.rpc('mw_staff_directory'));
  static Future<DbRecord?> staffApplicationStatus() async {
    final rows = List<DbRecord>.from(await db.rpc('mw_my_staff_application'));
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> submitStaffApplication({
    required String role,
    required String name,
    required String professionalId,
    required String institution,
  }) async {
    await db.rpc(
      'mw_submit_staff_application',
      params: {
        'p_role': role,
        'p_name': name,
        'p_professional_id': professionalId,
        'p_institution': institution,
      },
    );
  }

  static Future<List<DbRecord>> pendingStaffApplications() async =>
      List<DbRecord>.from(await db.rpc('mw_pending_staff_applications'));

  static Future<void> reviewStaffApplication({
    required String id,
    required bool approve,
    String note = '',
  }) async {
    await db.rpc(
      'mw_review_staff_application',
      params: {'p_id': id, 'p_approve': approve, 'p_note': note},
    );
  }

  static Future<void> action(String function, DbRecord payload) async {
    await db.rpc(function, params: payload);
  }
}
