import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/models.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser!.uid;

  // ── Get user by id ────────────────────────────────────────
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
      (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
    );
  }

  // ── Create user (used at signup) ──────────────────────────
  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toFirestore());
  }

  // ── Update profile ────────────────────────────────────────
  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _db.collection('users').doc(currentUid).update(data);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // ── Upload profile photo (web-compatible using bytes) ─────
  Future<String> uploadProfilePhoto(Uint8List bytes) async {
    final ref = _storage.ref('profile_photos/$currentUid.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(currentUid).update({'photoUrl': url});
    return url;
  }

  // ── Follow / unfollow ─────────────────────────────────────
  Future<void> followUser(String targetUid) async {
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(currentUid).collection('following').doc(targetUid),
      {'followedAt': Timestamp.now()},
    );
    batch.set(
      _db.collection('users').doc(targetUid).collection('followers').doc(currentUid),
      {'followedAt': Timestamp.now()},
    );
    batch.update(_db.collection('users').doc(currentUid),
      {'followingCount': FieldValue.increment(1)});
    batch.update(_db.collection('users').doc(targetUid),
      {'followerCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(currentUid).collection('following').doc(targetUid));
    batch.delete(_db.collection('users').doc(targetUid).collection('followers').doc(currentUid));
    batch.update(_db.collection('users').doc(currentUid),
      {'followingCount': FieldValue.increment(-1)});
    batch.update(_db.collection('users').doc(targetUid),
      {'followerCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<bool> isFollowing(String targetUid) async {
    final doc = await _db.collection('users').doc(currentUid)
        .collection('following').doc(targetUid).get();
    return doc.exists;
  }

  // ── Block user ────────────────────────────────────────────
  Future<void> blockUser(String targetUid) async {
    await _db.collection('users').doc(currentUid)
        .collection('blocked').doc(targetUid)
        .set({'blockedAt': Timestamp.now()});
  }

  Future<void> unblockUser(String targetUid) async {
    await _db.collection('users').doc(currentUid)
        .collection('blocked').doc(targetUid).delete();
  }

  Stream<List<String>> watchBlockedUsers() {
    return _db.collection('users').doc(currentUid)
        .collection('blocked').snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  // ── Search users ──────────────────────────────────────────
  Future<List<UserModel>> searchUsers(String query) async {
    final snap = await _db.collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThan: '${query}z')
        .limit(20)
        .get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  // ── Nearby users ──────────────────────────────────────────
  Future<List<UserModel>> getNearbyUsers() async {
    final snap = await _db.collection('users')
        .where('uid', isNotEqualTo: currentUid)
        .limit(30)
        .get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  // ── Trips ─────────────────────────────────────────────────
  Stream<List<TripModel>> watchTrips(String uid) {
    return _db.collection('users').doc(uid).collection('trips')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TripModel.fromFirestore(d)).toList());
  }

  Future<void> addTrip(TripModel trip) async {
    final ref = _db.collection('users').doc(currentUid).collection('trips').doc();
    await ref.set({...trip.toFirestore(), 'id': ref.id});
    await _db.collection('users').doc(currentUid).update({
      'passportStamps': FieldValue.arrayUnion([trip.countryCode]),
      'travelHistory': FieldValue.arrayUnion([trip.destination]),
    });
  }

  // ── Update last seen ──────────────────────────────────────
  Future<void> updateLastSeen(String uid) async {
    await _db.collection('users').doc(uid).update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
