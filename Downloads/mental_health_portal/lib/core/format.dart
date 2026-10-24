import 'package:intl/intl.dart';

String dateLabel(dynamic value) => value == null
    ? '—'
    : DateFormat('dd MMM yyyy, hh:mm a')
          .format(DateTime.parse(value as String).toLocal());
String? emailValidator(String? v) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '')
    ? null
    : 'Enter a valid email';
