import 'package:cloud_firestore/cloud_firestore.dart';

/// Recursively turns a value coming out of Firestore into something
/// `jsonEncode` can handle.
///
/// Firestore's native types (Timestamp, GeoPoint, DocumentReference)
/// don't have `toJson()`. The standard library's encoder will throw
/// `Converting object to an encodable object failed` on any of them.
///
/// Used by:
///   • Admin GDPR export pipeline — compiles a user's data into a
///     single JSON file before uploading to Storage.
///   • Anywhere else we serialise raw Firestore docs (e.g. debug
///     dumps, support tickets).
///
/// Returns:
///   • null, num, bool, String → unchanged
///   • Timestamp                → ISO 8601 string
///   • GeoPoint                 → {'lat': ..., 'lng': ...}
///   • DocumentReference        → its full slash-path string
///   • DateTime                 → ISO 8601 string
///   • List                     → list of normalised elements
///   • Map                      → map with string keys + normalised values
///   • anything else            → .toString()
Object? normaliseForJson(Object? v) {
  if (v == null || v is num || v is bool || v is String) return v;
  if (v is Timestamp) return v.toDate().toIso8601String();
  if (v is DateTime) return v.toIso8601String();
  if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
  if (v is DocumentReference) return v.path;
  if (v is List) return v.map(normaliseForJson).toList();
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), normaliseForJson(val)));
  }
  return v.toString();
}
