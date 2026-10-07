import 'dart:convert';

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.round();
  }
  return null;
}

double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }
  return null;
}

String? asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null' || text == 'N/A') {
    return null;
  }
  return text;
}

bool asBool(dynamic value) {
  if (value == true || value == 1) return true;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    return lower == '1' ||
        lower == 'true' ||
        lower == 'active' ||
        lower == 'yes';
  }
  return false;
}

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  final asNumber = asInt(value);
  if (asNumber != null) {
    if (asNumber > 9999999999) {
      return DateTime.fromMillisecondsSinceEpoch(asNumber, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(asNumber * 1000, isUtc: true);
  }
  final text = asString(value);
  if (text == null) return null;
  return DateTime.tryParse(text)?.toUtc();
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }
  return const {};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value.map(asMap).where((item) => item.isNotEmpty).toList();
}

String decodeMaybeBase64(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final looksB64 = RegExp(r'^[A-Za-z0-9+/]+=*$').hasMatch(trimmed) &&
      trimmed.length % 4 == 0 &&
      trimmed.length >= 8;
  if (!looksB64) return value;
  try {
    final decoded = utf8.decode(base64.decode(trimmed));
    if (RegExp(r'[A-Za-zÁÉÍÓÚáéíóúñÑ]').hasMatch(decoded)) return decoded;
  } catch (_) {}
  return value;
}
