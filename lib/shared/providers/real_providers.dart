import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import '../models/models.dart';

// ─── Mock credentials (used when isMock = true) ───────────────
const _mockCredentials = {
  'user@flyconnect.com':    ('user123',    'user'),
  'sarah@flyconnect.com':   ('sarah123',   'user'),
  'business@flyconnect.com':('business123','business'),
  'emirates@flyconnect.com':('emirates123','business'),
};

UserModel _mockUserModelFor(String email, String role) {
  switch (email) {
    case 'sarah@flyconnect.com':
      return UserModel(
        uid: 'mock_sarah', name: 'Sarah Mitchell', email: email,
        airline: 'British Airways', position: 'Flight Attendant',
        airport: 'LHR', city: 'London', state: 'England',
        bio: 'Cabin crew with a passion for discovering hidden gems 🌍',
        hobbies: ['Travel','Photography','Yoga','Reading'],
        matchType: 'buddy', followerCount: 843, followingCount: 210, postCount: 31,
        passportStamps: ['GB','US','FR','IT','JP','AU','AE','TH'],
        travelHistory: ['New York','Paris','Tokyo','Sydney'],
        isVerified: true, role: 'user',
        createdAt: DateTime.now().subtract(const Duration(days: 220)),
        photoUrl: 'https://i.pravatar.cc/200?img=25',
      );
    case 'business@flyconnect.com':
      return UserModel(
        uid: 'mock_biz1', name: 'Sky Lounge NYC', email: email,
        role: 'business', position: 'Airport Lounge', airport: 'JFK',
        city: 'New York', state: 'NY',
        bio: 'Premium airport lounge at JFK Terminal 4.',
        photoUrl: 'https://picsum.photos/seed/lounge/200',
        followerCount: 2840, followingCount: 0, postCount: 12,
        passportStamps: [], travelHistory: [], hobbies: [],
        isVerified: true, createdAt: DateTime.now().subtract(const Duration(days: 180)),
      );
    case 'emirates@flyconnect.com':
      return UserModel(
        uid: 'mock_biz2', name: 'Emirates Business Lounge', email: email,
        role: 'business', position: 'Airlines', airport: 'DXB',
        city: 'Dubai', state: 'Dubai',
        bio: 'Official Emirates lounge at Dubai International.',
        photoUrl: 'https://picsum.photos/seed/emirates/200',
        followerCount: 5120, followingCount: 0, postCount: 28,
        passportStamps: [], travelHistory: [], hobbies: [],
        isVerified: true, createdAt: DateTime.now().subtract(const Duration(days: 300)),
      );
    default: // user@flyconnect.com and any other email
      return UserModel(
        uid: 'mock_alex', name: 'Alex Johnson', email: email,
        airline: 'Delta Air Lines', position: 'Pilot',
        airport: 'JFK', city: 'New York', state: 'NY',
        bio: 'Senior pilot with 12 years of experience ✈️',
        hobbies: ['Photography','Hiking','Coffee','Travel','Fitness'],
        matchType: 'buddy', followerCount: 1284, followingCount: 342, postCount: 47,
        passportStamps: ['US','GB','JP','FR','DE','AU','TH','AE','SG','IT'],
        travelHistory: ['London','Tokyo','Paris','Berlin','Sydney'],
        isVerified: true, role: 'user',
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
        photoUrl: 'https://i.pravatar.cc/200?img=11',
      );
  }
}

// ─── Real Auth Provider ──────────────────────────────────────
class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserModel? _currentUser;
  bool _loading = false;
  String? _error;

  // When true, login uses mock credentials instead of Firebase Auth
  final bool isMock;

  UserModel? get currentUser => _currentUser;
  dynamic get firebaseUser => isMock ? _currentUser : _auth.currentUser;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => isMock ? _currentUser != null : _auth.currentUser != null;
  String get userRole => _currentUser?.role ?? 'user';

  AuthProvider({this.isMock = false}) {
    if (!isMock) {
      _auth.authStateChanges().listen((user) async {
        if (user != null) {
          await _fetchUser(user.uid);
        } else {
          _currentUser = null;
        }
        notifyListeners();
      });
    }
  }

  Future<void> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      _currentUser = UserModel.fromFirestore(doc);
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true; _error = null; notifyListeners();

    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      final entry = _mockCredentials[email.trim().toLowerCase()];
      if (entry != null && entry.$1 == password) {
        _currentUser = _mockUserModelFor(email.trim().toLowerCase(), entry.$2);
        _loading = false; notifyListeners();
        return true;
      }
      // Any unrecognised email/password still logs in as the default user
      _currentUser = _mockUserModelFor(email.trim().toLowerCase(), 'user');
      _loading = false; notifyListeners();
      return true;
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _fetchUser(cred.user!.uid);
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Login failed';
      _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login failed. Please check your connection and try again.';
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String name, required String email, required String password,
    String? phone, String? airline, String? airport, String? position,
    String? city, String? state, String role = 'user', String? bio,
  }) async {
    _loading = true; _error = null; notifyListeners();

    if (isMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      _currentUser = UserModel(
        uid: 'mock_new_${DateTime.now().millisecondsSinceEpoch}',
        name: name, email: email, phone: phone,
        airline: airline, airport: airport, position: position,
        city: city, state: state, role: role, bio: bio,
        createdAt: DateTime.now(),
        hobbies: [], passportStamps: [], travelHistory: [],
      );
      _loading = false; notifyListeners();
      return true;
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user!.updateDisplayName(name);
      final user = UserModel(
        uid: cred.user!.uid, name: name, email: email, phone: phone,
        airline: airline, airport: airport, position: position,
        city: city, state: state, role: role, bio: bio,
        createdAt: DateTime.now(),
        hobbies: [], passportStamps: [], travelHistory: [],
      );
      await _db.collection('users').doc(user.uid).set(user.toFirestore());
      _currentUser = user;
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Signup failed';
      _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'Signup failed. Please check your connection and try again.';
      _loading = false; notifyListeners();
      return false;
    }
  }

  void switchUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Deletes the user's Firestore data and the FirebaseAuth user itself.
  /// Required by Google Play Store (since May 2024) and Apple App Store.
  ///
  /// Steps:
  /// 1. Delete the top-level user doc `users/{uid}`
  /// 2. Delete first-party subcollections under that user (savedPosts, blocked, following, followers, trips)
  /// 3. Mark the user's posts as deleted (soft-delete) \u2014 we don't cascade-delete
  ///    other users' replies/likes automatically; those are handled by a Cloud
  ///    Function on the `users/{uid}` delete trigger in production.
  /// 4. Sign the user out of Google / Apple
  /// 5. Call `FirebaseAuth.currentUser!.delete()` \u2014 requires a recent login
  ///
  /// Returns `true` on success. On `requires-recent-login`, sets `_error`
  /// and returns `false` so the caller can prompt the user to re-authenticate.
  Future<bool> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      _error = 'You must be signed in to delete your account.';
      notifyListeners();
      return false;
    }
    final uid = user.uid;
    _loading = true; _error = null; notifyListeners();

    try {
      // 1. Wipe the user doc
      await _db.collection('users').doc(uid).delete();

      // 2. Wipe known subcollections (Firestore requires individual doc deletes)
      await _deleteSubcollection(_db.collection('users').doc(uid).collection('savedPosts'));
      await _deleteSubcollection(_db.collection('users').doc(uid).collection('blocked'));
      await _deleteSubcollection(_db.collection('users').doc(uid).collection('following'));
      await _deleteSubcollection(_db.collection('users').doc(uid).collection('followers'));
      await _deleteSubcollection(_db.collection('users').doc(uid).collection('trips'));

      // 3. Soft-delete user's posts (anonymize author)
      final postSnap = await _db.collection('posts')
          .where('authorId', isEqualTo: uid).get();
      final batch = _db.batch();
      for (final doc in postSnap.docs) {
        batch.update(doc.reference, {
          'authorName': '[deleted user]',
          'authorPhotoUrl': null,
          'isDeleted': true,
        });
      }
      await batch.commit();

      // 4. Sign out of Google (native only)
      if (!kIsWeb) {
        try { await GoogleSignIn().signOut(); } catch (_) {}
      }

      // 5. Delete the Firebase Auth user
      await user.delete();

      _currentUser = null;
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _error = 'Please sign out and sign in again, then try deleting your account.';
      } else {
        _error = e.message ?? 'Could not delete account.';
      }
      _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'Could not delete account: $e';
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<void> _deleteSubcollection(CollectionReference ref) async {
    try {
      final snap = await ref.limit(500).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      // Recurse if there were exactly 500 docs (Firestore batch max)
      if (snap.docs.length == 500) {
        await _deleteSubcollection(ref);
      }
    } catch (_) {
      // Non-fatal \u2014 continue deletion of other subcollections
    }
  }

  Future<bool> resetPassword(String email) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Failed to send reset email';
      _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to send reset email: $e';
      _loading = false; notifyListeners();
      return false;
    }
  }

  Future<bool> logout() async {
    _error = null;
    if (isMock) {
      _currentUser = null;
      notifyListeners();
      return true;
    }
    try {
      if (!kIsWeb) {
        // Sign out of Google too on native, otherwise re-login skips picker.
        try { await GoogleSignIn().signOut(); } catch (_) {}
      }
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Logout failed. Please check your connection and try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────
  // Web: uses signInWithPopup (no extra package config needed).
  // Mobile: uses google_sign_in package — requires:
  //   • iOS: REVERSED_CLIENT_ID added to Info.plist URL Schemes
  //   • Android: SHA-1 fingerprint added to Firebase Console
  //   • Firebase Console: Google sign-in provider enabled
  Future<bool> signInWithGoogle({String role = 'user'}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      UserCredential cred;
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        cred = await _auth.signInWithPopup(provider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          _loading = false; notifyListeners();
          return false; // user cancelled
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        cred = await _auth.signInWithCredential(credential);
      }

      await _ensureUserDoc(cred.user!, provider: 'google', role: role);
      _loading = false; notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Google sign-in failed';
      _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google sign-in failed: $e';
      _loading = false; notifyListeners();
      return false;
    }
  }

  // ── Apple Sign-In ──────────────────────────────────────────
  // iOS native: requires "Sign in with Apple" capability in Xcode.
  // Web/Android: requires Apple Service ID + Firebase provider config.
  Future<bool> signInWithApple({String role = 'user'}) async {
    _loading = true; _error = null; notifyListeners();
    try {
      UserCredential cred;
      if (kIsWeb) {
        final provider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        cred = await _auth.signInWithPopup(provider);
      } else {
        // Generate cryptographic nonce for replay protection
        final rawNonce = _generateNonce();
        final nonce = _sha256(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );

        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );
        cred = await _auth.signInWithCredential(oauthCredential);

        // Apple only provides name on first sign-in
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName
        ].where((p) => p != null && p.isNotEmpty).join(' ');
        if (displayName.isNotEmpty && cred.user!.displayName == null) {
          await cred.user!.updateDisplayName(displayName);
        }
      }

      await _ensureUserDoc(cred.user!, provider: 'apple', role: role);
      _loading = false; notifyListeners();
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        _loading = false; notifyListeners();
        return false;
      }
      _error = 'Apple sign-in failed: ${e.message}';
      _loading = false; notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Apple sign-in failed';
      _loading = false; notifyListeners();
      return false;
    } catch (e) {
      _error = 'Apple sign-in failed: $e';
      _loading = false; notifyListeners();
      return false;
    }
  }

  // Create the Firestore user doc on first OAuth sign-in.
  // `role` is honored only when the doc doesn't yet exist (first-time login).
  // Existing users keep whatever role they already have.
  Future<void> _ensureUserDoc(User user,
      {required String provider, String role = 'user'}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      _currentUser = UserModel.fromFirestore(snap);
      // Update lastSeen on every login
      await ref.update({'lastSeen': Timestamp.now()});
      return;
    }
    final newUser = UserModel(
      uid: user.uid,
      name: user.displayName ?? user.email?.split('@').first ?? 'New User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      role: role,
      createdAt: DateTime.now(),
      hobbies: [],
      passportStamps: [],
      travelHistory: [],
    );
    await ref.set(newUser.toFirestore());
    _currentUser = newUser;
  }

  // ── Helpers for Apple nonce ────────────────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}

// ─── Real User Provider ──────────────────────────────────────
class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  bool get loading => false;

  void updateAuth(AuthProvider auth) {
    _currentUser = auth.currentUser;
    notifyListeners();
  }

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
    if (_currentUser != null && uid == _currentUser!.uid) {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) _currentUser = UserModel.fromFirestore(doc);
    }
    notifyListeners();
  }

  Future<void> followUser(String targetUid) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(uid).collection('following').doc(targetUid),
      {'followedAt': Timestamp.now()});
    batch.set(_db.collection('users').doc(targetUid).collection('followers').doc(uid),
      {'followedAt': Timestamp.now()});
    batch.update(_db.collection('users').doc(uid), {'followingCount': FieldValue.increment(1)});
    batch.update(_db.collection('users').doc(targetUid), {'followerCount': FieldValue.increment(1)});
    await batch.commit();
    notifyListeners();
  }

  Future<void> unfollowUser(String targetUid) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(uid).collection('following').doc(targetUid));
    batch.delete(_db.collection('users').doc(targetUid).collection('followers').doc(uid));
    batch.update(_db.collection('users').doc(uid), {'followingCount': FieldValue.increment(-1)});
    batch.update(_db.collection('users').doc(targetUid), {'followerCount': FieldValue.increment(-1)});
    await batch.commit();
    notifyListeners();
  }

  Future<bool> isFollowing(String targetUid) async {
    final uid = _currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db.collection('users').doc(uid).collection('following').doc(targetUid).get();
    return doc.exists;
  }
}

// ─── Real Post Provider ──────────────────────────────────────
class PostProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<PostModel> _feed = [];
  final Set<String> _liked = {};
  final bool _loading = false;

  bool get loading => _loading;
  List<PostModel> get feed => _feed;

  String? get _uid => _auth.currentUser?.uid;
  StreamSubscription? _feedSub;

  void updateAuth(AuthProvider auth) {}

  void listenFeed() {
    _feedSub?.cancel();
    _feedSub = _db.collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _feed = snap.docs.map((d) => PostModel.fromFirestore(d)).toList();
      notifyListeners();
    });
  }

  Future<void> likePost(String postId) async {
    if (_uid == null) return;
    _liked.add(postId);
    await _db.collection('posts').doc(postId).collection('likes').doc(_uid).set({'likedAt': Timestamp.now()});
    await _db.collection('posts').doc(postId).update({'likeCount': FieldValue.increment(1)});
    notifyListeners();
  }

  Future<void> unlikePost(String postId) async {
    if (_uid == null) return;
    _liked.remove(postId);
    await _db.collection('posts').doc(postId).collection('likes').doc(_uid).delete();
    await _db.collection('posts').doc(postId).update({'likeCount': FieldValue.increment(-1)});
    notifyListeners();
  }

  Future<bool> isLiked(String postId) async {
    if (_uid == null) return false;
    if (_liked.contains(postId)) return true;
    final doc = await _db.collection('posts').doc(postId).collection('likes').doc(_uid).get();
    if (doc.exists) _liked.add(postId);
    return doc.exists;
  }

  // ── Saved / Bookmarked posts ────────────────────────────────
  // Stored under users/{uid}/savedPosts/{postId}
  final Set<String> _saved = {};

  Future<void> savePost(String postId) async {
    if (_uid == null) return;
    _saved.add(postId);
    await _db
        .collection('users')
        .doc(_uid)
        .collection('savedPosts')
        .doc(postId)
        .set({'savedAt': Timestamp.now()});
    notifyListeners();
  }

  Future<void> unsavePost(String postId) async {
    if (_uid == null) return;
    _saved.remove(postId);
    await _db
        .collection('users')
        .doc(_uid)
        .collection('savedPosts')
        .doc(postId)
        .delete();
    notifyListeners();
  }

  Future<bool> isSaved(String postId) async {
    if (_uid == null) return false;
    if (_saved.contains(postId)) return true;
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('savedPosts')
        .doc(postId)
        .get();
    if (doc.exists) _saved.add(postId);
    return doc.exists;
  }

  Stream<List<CommentModel>> watchComments(String postId) {
    return _db.collection('posts').doc(postId).collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => CommentModel.fromFirestore(d)).toList());
  }

  Future<void> addComment(String postId, String text) async {
    if (_uid == null) return;
    final user = _auth.currentUser!;
    final ref = _db.collection('posts').doc(postId).collection('comments').doc();
    await ref.set({
      'postId': postId, 'authorId': _uid, 'authorName': user.displayName ?? 'User',
      'text': text, 'likeCount': 0, 'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('posts').doc(postId).update({'commentCount': FieldValue.increment(1)});
  }

  Future<void> reportPost(String postId, {String? reason}) async {
    // 1. Flag the post itself so it surfaces in the moderation queue
    await _db.collection('posts').doc(postId).update({
      'reportCount': FieldValue.increment(1), 'isReported': true,
    });
    // 2. Persist a detailed report record for Apple 1.2 / Play UGC compliance
    await _db.collection('reports').add({
      'targetType': 'post',
      'targetId': postId,
      'reporterId': _uid,
      'reason': reason ?? 'Inappropriate content',
      'status': 'pending',      // pending | reviewed | actioned | dismissed
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Generic content reporting (groups, chats, users) ────────
  Future<void> reportContent({
    required String targetType,   // 'group' | 'chat' | 'user' | 'comment'
    required String targetId,
    String? reason,
  }) async {
    await _db.collection('reports').add({
      'targetType': targetType,
      'targetId': targetId,
      'reporterId': _uid,
      'reason': reason ?? 'Inappropriate content',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Block a user (UGC compliance \u2014 Apple requires this) ────────
  Future<void> blockUser(String targetUid) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('blocked')
        .doc(targetUid)
        .set({'blockedAt': Timestamp.now()});
    notifyListeners();
  }

  Future<void> unblockUser(String targetUid) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('blocked')
        .doc(targetUid)
        .delete();
    notifyListeners();
  }

  // Upload image bytes to Firebase Storage and return the public download URL.
  // Path: user_uploads/{uid}/posts/{timestamp}.jpg
  Future<String?> uploadPostImage(Uint8List bytes) async {
    if (_uid == null) return null;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('user_uploads/$_uid/posts/$ts.jpg');
      await ref.putData(bytes,
          SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> createPost({
    required String caption,
    List<String> mediaUrls = const [],
    String mediaType = 'text',
    String? location,
    String? groupId,
    String audience = 'Everyone',  // Everyone | Connections | Only me
  }) async {
    if (_uid == null) return;
    final user = _auth.currentUser!;
    final ref = _db.collection('posts').doc();
    final post = PostModel(
      id: ref.id, authorId: _uid!, authorName: user.displayName ?? 'User',
      caption: caption, mediaUrls: mediaUrls, mediaType: mediaType,
      location: location, groupId: groupId, createdAt: DateTime.now(),
    );
    final data = post.toFirestore();
    data['audience'] = audience; // annotate the doc so feed queries can filter
    await ref.set(data);
    await _db.collection('users').doc(_uid).update({'postCount': FieldValue.increment(1)});
    notifyListeners();
  }

  @override
  void dispose() { _feedSub?.cancel(); super.dispose(); }
}

// ─── Real Chat Provider ──────────────────────────────────────
class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ChatModel> _chats = [];
  StreamSubscription? _chatsSub;

  List<ChatModel> get chats => _chats;
  String? get _uid => _auth.currentUser?.uid;

  void updateAuth(AuthProvider auth) {
    _chatsSub?.cancel();
    if (_uid != null) {
      _chatsSub = _db.collection('chats')
          .where('participants', arrayContains: _uid)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .listen((snap) {
        _chats = snap.docs.map((d) => ChatModel.fromFirestore(d)).toList();
        notifyListeners();
      });
    }
  }

  Stream<List<MessageModel>> watchMessages(String chatId) =>
    _db.collection('chats').doc(chatId).collection('messages')
        .orderBy('createdAt').snapshots()
        .map((s) => s.docs.map((d) => MessageModel.fromFirestore(d)).toList());

  Future<void> sendMessage(String chatId, String text,
      {String? mediaUrl, String mediaType = 'text'}) async {
    if (_uid == null) return;
    final user = _auth.currentUser!;
    final msgRef = _db.collection('chats').doc(chatId).collection('messages').doc();
    final batch = _db.batch();
    batch.set(msgRef, {
      'senderId': _uid, 'senderName': user.displayName ?? 'User',
      'senderPhotoUrl': user.photoURL, 'text': text,
      'mediaUrl': mediaUrl, 'mediaType': mediaType,
      'readBy': [_uid], 'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('chats').doc(chatId), {
      'lastMessage': text, 'lastMessageSenderId': _uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    notifyListeners();
  }

  Future<void> markAsRead(String chatId) async {
    if (_uid == null) return;
    await _db.collection('chats').doc(chatId).update({'unreadCount.$_uid': 0});
  }

  Future<String> getOrCreateDm(String otherUid) async {
    if (_uid == null) return '';
    final snap = await _db.collection('chats')
        .where('type', isEqualTo: 'dm')
        .where('participants', arrayContains: _uid).get();
    for (final doc in snap.docs) {
      final chat = ChatModel.fromFirestore(doc);
      if (chat.participants.contains(otherUid)) return doc.id;
    }
    final ref = _db.collection('chats').doc();
    await ref.set({
      'type': 'dm', 'participants': [_uid, otherUid],
      'createdBy': _uid, 'unreadCount': {}, 'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> setTyping(String chatId, bool isTyping) async {
    if (_uid == null) return;
    await _db.collection('chats').doc(chatId).collection('typing').doc(_uid)
        .set({'isTyping': isTyping, 'at': FieldValue.serverTimestamp()});
  }

  Stream<Map<String, bool>> watchTyping(String chatId) =>
    _db.collection('chats').doc(chatId).collection('typing').snapshots()
        .map((s) => Map.fromEntries(
            s.docs.map((d) => MapEntry(d.id, d.data()['isTyping'] as bool? ?? false))));

  @override
  void dispose() { _chatsSub?.cancel(); super.dispose(); }
}

// ─── Real Event Provider ─────────────────────────────────────
class EventProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<EventModel> _events = [];
  final Set<String> _rsvpd = {};
  StreamSubscription? _eventsSub;

  List<EventModel> get events => _events;
  String? get _uid => _auth.currentUser?.uid;

  void updateAuth(AuthProvider auth) {
    _eventsSub?.cancel();
    _eventsSub = _db.collection('events')
        .orderBy('date')
        .snapshots()
        .listen((snap) {
      _events = snap.docs.map((d) => EventModel.fromFirestore(d)).toList();
      notifyListeners();
    });
  }

  Future<void> toggleRsvp(String eventId) async {
    if (_uid == null) return;
    final rsvpRef = _db.collection('events').doc(eventId).collection('rsvps').doc(_uid);
    final doc = await rsvpRef.get();
    if (doc.exists) {
      await rsvpRef.delete();
      await _db.collection('events').doc(eventId).update({
        'rsvpList': FieldValue.arrayRemove([_uid]), 'rsvpCount': FieldValue.increment(-1),
      });
      _rsvpd.remove(eventId);
    } else {
      await rsvpRef.set({'rsvpAt': Timestamp.now()});
      await _db.collection('events').doc(eventId).update({
        'rsvpList': FieldValue.arrayUnion([_uid]), 'rsvpCount': FieldValue.increment(1),
      });
      _rsvpd.add(eventId);
    }
    notifyListeners();
  }

  Future<bool> hasRsvped(String eventId) async {
    if (_uid == null) return false;
    if (_rsvpd.contains(eventId)) return true;
    final doc = await _db.collection('events').doc(eventId).collection('rsvps').doc(_uid).get();
    if (doc.exists) _rsvpd.add(eventId);
    return doc.exists;
  }

  bool isRsvpd(String eventId) => _rsvpd.contains(eventId);

  void addEvent(EventModel event) {
    _db.collection('events').doc().set(event.toFirestore());
    notifyListeners();
  }

  @override
  void dispose() { _eventsSub?.cancel(); super.dispose(); }
}

// ─── Real Group Provider ─────────────────────────────────────
class GroupProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<GroupModel> _groups = [];
  final Set<String> _joined = {};
  StreamSubscription? _groupsSub;

  List<GroupModel> get groups => _groups;
  List<GroupModel> get myGroups => _groups.where((g) => _joined.contains(g.id)).toList();
  String? get _uid => _auth.currentUser?.uid;

  void updateAuth(AuthProvider auth) {
    _groupsSub?.cancel();
    _groupsSub = _db.collection('groups')
        .orderBy('memberCount', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) {
      _groups = snap.docs.map((d) => GroupModel.fromFirestore(d)).toList();
      // Update joined set
      if (_uid != null) {
        _joined.clear();
        for (final g in _groups) {
          if (g.members.contains(_uid)) _joined.add(g.id);
        }
      }
      notifyListeners();
    });
  }

  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return GroupModel.fromFirestore(doc);
  }

  Future<void> joinGroup(String groupId) async {
    if (_uid == null) return;
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([_uid]), 'memberCount': FieldValue.increment(1),
    });
    _joined.add(groupId);
    notifyListeners();
  }

  Future<void> leaveGroup(String groupId) async {
    if (_uid == null) return;
    await _db.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([_uid]), 'memberCount': FieldValue.increment(-1),
    });
    _joined.remove(groupId);
    notifyListeners();
  }

  bool isMember(String groupId) => _joined.contains(groupId);

  void createGroup(GroupModel group) {
    _db.collection('groups').doc().set(group.toFirestore());
    if (group.id.isNotEmpty) _joined.add(group.id);
    notifyListeners();
  }

  @override
  void dispose() { _groupsSub?.cancel(); super.dispose(); }
}

// ─── Real Match Provider ─────────────────────────────────────
class MatchProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<UserModel> _candidates = [];
  final List<MatchModel> _matches = [];
  bool _loading = false;

  bool get loading => _loading;
  List<UserModel> get candidates => _candidates;
  List<MatchModel> get matches => _matches;
  String? get _uid => _auth.currentUser?.uid;

  void updateAuth(AuthProvider auth) {}

  Future<void> loadCandidates() async {
    if (_uid == null) return;
    _loading = true; notifyListeners();
    final snap = await _db.collection('users')
        .where('role', isEqualTo: 'user')
        .limit(20).get();
    _candidates = snap.docs
        .map((d) => UserModel.fromFirestore(d))
        .where((u) => u.uid != _uid).toList();
    _loading = false; notifyListeners();
  }

  Future<void> likeUser(String targetUid, String matchType) async {
    if (_uid == null) return;
    _candidates.removeWhere((u) => u.uid == targetUid);
    // Check if target already liked us
    final existing = await _db.collection('matches')
        .where('userA', isEqualTo: targetUid)
        .where('userB', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending').get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({'status': 'matched', 'matchedAt': FieldValue.serverTimestamp()});
      _matches.add(MatchModel(id: existing.docs.first.id, userA: targetUid, userB: _uid!,
        status: 'matched', matchType: matchType, likedAt: DateTime.now(), matchedAt: DateTime.now()));
    } else {
      await _db.collection('matches').add({
        'userA': _uid, 'userB': targetUid, 'status': 'pending',
        'matchType': matchType, 'likedAt': FieldValue.serverTimestamp(),
      });
    }
    notifyListeners();
  }

  Future<void> passUser(String targetUid) async {
    if (_uid == null) return;
    _candidates.removeWhere((u) => u.uid == targetUid);
    await _db.collection('matches').add({
      'userA': _uid, 'userB': targetUid, 'status': 'passed',
      'matchType': 'none', 'likedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }
}

// ─── Real Notification Provider ──────────────────────────────
class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<NotificationModel> _notifications = [];
  StreamSubscription? _notifSub;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void updateAuth(AuthProvider auth) {
    _notifSub?.cancel();
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      _notifSub = _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .listen((snap) {
        _notifications = snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
        notifyListeners();
      });
    }
  }

  Stream<List<NotificationModel>> watchNotifications() => Stream.value(_notifications);

  Future<void> markAsRead(String id) async {
    await _db.collection('notifications').doc(id).update({'isRead': true});
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i != -1) {
      final n = _notifications[i];
      _notifications[i] = NotificationModel(id: n.id, userId: n.userId,
        type: n.type, title: n.title, body: n.body,
        imageUrl: n.imageUrl, deepLink: n.deepLink,
        isRead: true, createdAt: n.createdAt);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final uid = _notifications.isNotEmpty ? _notifications.first.userId : null;
    if (uid == null) return;
    final snap = await _db.collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> delete(String id) async {
    await _db.collection('notifications').doc(id).delete();
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  @override
  void dispose() { _notifSub?.cancel(); super.dispose(); }
}

// ─── Real Trip Provider ──────────────────────────────────────
class TripProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<TripModel> _trips = [];
  StreamSubscription? _tripsSub;

  List<TripModel> get trips => _trips;

  void updateAuth(AuthProvider auth) {
    _tripsSub?.cancel();
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      _tripsSub = _db.collection('trips')
          .where('userId', isEqualTo: uid)
          .orderBy('startDate', descending: true)
          .snapshots()
          .listen((snap) {
        _trips = snap.docs.map((d) => TripModel.fromFirestore(d)).toList();
        notifyListeners();
      });
    }
  }

  Future<void> addTrip(TripModel trip) async {
    await _db.collection('trips').doc(trip.id).set(trip.toFirestore());
    notifyListeners();
  }

  Future<void> deleteTrip(String tripId) async {
    await _db.collection('trips').doc(tripId).delete();
    _trips.removeWhere((t) => t.id == tripId);
    notifyListeners();
  }

  @override
  void dispose() { _tripsSub?.cancel(); super.dispose(); }
}

// ─── Real Promotion Provider ─────────────────────────────────
class PromotionProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<PromotionModel> _promotions = [];
  StreamSubscription? _promoSub;

  List<PromotionModel> get promotions => _promotions;
  List<PromotionModel> get activePromotions => _promotions.where((p) => p.isActive).toList();
  List<PromotionModel> get expiredPromotions => _promotions.where((p) => !p.isActive).toList();

  void updateAuth(AuthProvider auth) {
    _promoSub?.cancel();
    _promoSub = _db.collection('promotions')
        .snapshots()
        .listen((snap) {
      _promotions = snap.docs.map((d) => PromotionModel.fromFirestore(d)).toList();
      notifyListeners();
    });
  }

  void addPromotion(PromotionModel promo) {
    _db.collection('promotions').doc().set(promo.toFirestore());
    notifyListeners();
  }

  @override
  void dispose() { _promoSub?.cancel(); super.dispose(); }
}

// ─── Real Search Provider ────────────────────────────────────
class SearchProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<UserModel> _userResults = [];
  List<EventModel> _eventResults = [];
  List<GroupModel> _groupResults = [];
  bool _loading = false;
  String _query = '';

  List<UserModel> get userResults => _userResults;
  List<EventModel> get eventResults => _eventResults;
  List<GroupModel> get groupResults => _groupResults;
  bool get loading => _loading;
  String get query => _query;

  void updateAuth(AuthProvider auth) {}

  Future<void> search(String q) async {
    if (q.isEmpty) { clear(); return; }
    _query = q; _loading = true; notifyListeners();

    // Search users
    final userSnap = await _db.collection('users')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(10).get();
    _userResults = userSnap.docs.map((d) => UserModel.fromFirestore(d)).toList();

    // Search events
    final eventSnap = await _db.collection('events')
        .where('title', isGreaterThanOrEqualTo: q)
        .where('title', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(10).get();
    _eventResults = eventSnap.docs.map((d) => EventModel.fromFirestore(d)).toList();

    // Search groups
    final groupSnap = await _db.collection('groups')
        .where('name', isGreaterThanOrEqualTo: q)
        .where('name', isLessThanOrEqualTo: '$q\uf8ff')
        .limit(10).get();
    _groupResults = groupSnap.docs.map((d) => GroupModel.fromFirestore(d)).toList();

    _loading = false; notifyListeners();
  }

  void clear() {
    _query = ''; _userResults = []; _eventResults = []; _groupResults = [];
    notifyListeners();
  }
}

// ─── Real SafeCheck Provider ─────────────────────────────────
class SafeCheckProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<SafeCheckModel> _checkIns = [];
  SafeCheckModel? _myLatestCheckIn;
  bool _loading = false;
  StreamSubscription? _checkInSub;

  List<SafeCheckModel> get checkIns => _checkIns;
  SafeCheckModel? get myLatestCheckIn => _myLatestCheckIn;
  bool get loading => _loading;

  List<SafeCheckModel> get activeCheckIns =>
    _checkIns.where((c) => c.isActive).toList();

  void updateAuth(AuthProvider auth) {
    _checkInSub?.cancel();
    _checkInSub = _db.collection('safeChecks')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _checkIns = snap.docs.map((d) => SafeCheckModel.fromFirestore(d)).toList();
      // Update own latest
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        final my = _checkIns.where((c) => c.userId == uid && c.isActive).toList();
        _myLatestCheckIn = my.isNotEmpty ? my.first : null;
      }
      notifyListeners();
    });
  }

  List<SafeCheckModel> nearbyCheckIns(String city) =>
    activeCheckIns.where((c) => c.city.toLowerCase() == city.toLowerCase()).toList();

  SafeCheckModel? latestForUser(String userId) {
    final userCheckIns = activeCheckIns.where((c) => c.userId == userId).toList();
    if (userCheckIns.isEmpty) return null;
    userCheckIns.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return userCheckIns.first;
  }

  Future<void> checkIn({
    required String status, String? message, required String city,
    double? lat, double? lng, required String userId,
    required String userName, String? userPhotoUrl,
  }) async {
    _loading = true; notifyListeners();
    final now = DateTime.now();
    final checkIn = SafeCheckModel(
      id: '', userId: userId, userName: userName, userPhotoUrl: userPhotoUrl,
      status: status, message: message, city: city, lat: lat, lng: lng,
      createdAt: now, expiresAt: now.add(const Duration(hours: 24)),
    );
    await _db.collection('safeChecks').add(checkIn.toFirestore());
    _loading = false; notifyListeners();
  }

  void clearMyCheckIn(String userId) {
    // Mark as expired in Firestore
    final active = _checkIns.where((c) => c.userId == userId && c.isActive);
    for (final c in active) {
      _db.collection('safeChecks').doc(c.id).update({'expiresAt': DateTime.now()});
    }
    _myLatestCheckIn = null;
    notifyListeners();
  }

  @override
  void dispose() { _checkInSub?.cancel(); super.dispose(); }
}
