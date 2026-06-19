import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../utils/image_compress.dart';
import '../models/models.dart';

class StoryState extends ChangeNotifier {
  static final StoryState instance = StoryState._();
  StoryState._();
  Uint8List? myStoryBytes;
  String? myStoryUrl;
  List<StoryItem> _stories = [];
  bool _loading = false;

  List<StoryItem> get stories => _stories;
  bool get loading => _loading;

  /// Stories from other users (not mine), active only (< 24h old).
  List<StoryItem> get otherStories => _stories
      .where((s) => s.userId != FirebaseAuth.instance.currentUser?.uid && s.isActive)
      .toList();

  /// My active story.
  StoryItem? get myStory {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _stories.where((s) => s.userId == uid && s.isActive).firstOrNull;
  }

  void removeStory() {
    myStoryBytes = null;
    myStoryUrl = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _deleteMyStory(uid);
    }
    notifyListeners();
  }

  Future<void> _deleteMyStory(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('stories')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (_) {}
  }

  /// Upload a story image and write to Firestore with 24h TTL.
  Future<void> postStory(Uint8List bytes, UserModel user) async {
    try {
      final compressed = await compressForUpload(bytes, maxDimension: 1200);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref('user_uploads/${user.uid}/stories/$ts.png');
      await ref.putData(compressed, SettableMetadata(contentType: 'image/png'));
      final url = await ref.getDownloadURL();

      myStoryUrl = url;
      myStoryBytes = bytes;

      await FirebaseFirestore.instance.collection('stories').add({
        'userId': user.uid,
        'userName': user.name,
        'userPhotoUrl': user.photoUrl,
        'imageUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': DateTime.now().add(const Duration(hours: 24)),
      });
      notifyListeners();
    } catch (e) {
      debugPrint('[StoryState] postStory failed: $e');
    }
  }

  /// Fetch recent stories from Firestore (active, last 24h).
  Future<void> loadStories() async {
    _loading = true;
    notifyListeners();
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final snap = await FirebaseFirestore.instance.collection('stories')
          .where('expiresAt', isGreaterThan: cutoff)
          .orderBy('expiresAt', descending: true)
          .limit(50)
          .get();
      _stories = snap.docs.map((d) => StoryItem.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[StoryState] loadStories failed: $e');
    }
    _loading = false;
    notifyListeners();
  }
}

/// A story item from Firestore.
class StoryItem {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime expiresAt;

  const StoryItem({
    required this.id, required this.userId, required this.userName,
    this.userPhotoUrl, required this.imageUrl,
    required this.createdAt, required this.expiresAt,
  });

  bool get isActive => expiresAt.isAfter(DateTime.now());

  factory StoryItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return StoryItem(
      id: doc.id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userPhotoUrl: d['userPhotoUrl'],
      imageUrl: d['imageUrl'] ?? '',
      createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
      expiresAt: d['expiresAt'] is Timestamp ? (d['expiresAt'] as Timestamp).toDate()
          : d['expiresAt'] is DateTime ? d['expiresAt'] as DateTime : DateTime.now(),
    );
  }
}
