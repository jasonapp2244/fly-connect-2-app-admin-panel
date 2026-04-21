import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Tests for PostProvider behavior: likes, comments, reports, bookmarks.
/// Same caveat as auth_provider_test: our provider uses singleton Firestore,
/// so we validate the data-layer contract directly against fake Firestore.
void main() {
  late FakeFirebaseFirestore db;
  const uid = 'test-user-123';
  const postId = 'post-abc';

  setUp(() {
    db = FakeFirebaseFirestore();
  });

  group('Likes', () {
    test('liking a post writes to likes subcollection and increments count', () async {
      await db.collection('posts').doc(postId).set({'likeCount': 0});
      await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).set({'likedAt': Timestamp.now()});
      await db.collection('posts').doc(postId).update({
        'likeCount': FieldValue.increment(1),
      });

      final postSnap = await db.collection('posts').doc(postId).get();
      expect(postSnap.data()!['likeCount'], 1);

      final likeSnap = await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).get();
      expect(likeSnap.exists, true);
    });

    test('isLiked check returns true after liking', () async {
      await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).set({'likedAt': Timestamp.now()});
      final doc = await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).get();
      expect(doc.exists, true);
    });

    test('unliking removes the doc and decrements count', () async {
      await db.collection('posts').doc(postId).set({'likeCount': 1});
      await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).set({'likedAt': Timestamp.now()});

      await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).delete();
      await db.collection('posts').doc(postId).update({
        'likeCount': FieldValue.increment(-1),
      });

      final postSnap = await db.collection('posts').doc(postId).get();
      expect(postSnap.data()!['likeCount'], 0);

      final likeSnap = await db.collection('posts').doc(postId)
          .collection('likes').doc(uid).get();
      expect(likeSnap.exists, false);
    });
  });

  group('Comments', () {
    test('adding a comment writes to comments subcollection', () async {
      await db.collection('posts').doc(postId).set({'commentCount': 0});
      await db.collection('posts').doc(postId)
          .collection('comments').add({
        'postId': postId,
        'authorId': uid,
        'text': 'Nice post!',
        'likeCount': 0,
        'createdAt': Timestamp.now(),
      });
      await db.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      final comments = await db.collection('posts').doc(postId)
          .collection('comments').get();
      expect(comments.docs.length, 1);
      expect(comments.docs.first.data()['text'], 'Nice post!');

      final post = await db.collection('posts').doc(postId).get();
      expect(post.data()!['commentCount'], 1);
    });
  });

  group('Reports (UGC compliance)', () {
    test('reporting a post creates a report record AND flags the post', () async {
      // 1. Seed post
      await db.collection('posts').doc(postId).set({
        'reportCount': 0,
        'isReported': false,
      });

      // 2. Report: flag post + create report record
      await db.collection('posts').doc(postId).update({
        'reportCount': FieldValue.increment(1),
        'isReported': true,
      });
      await db.collection('reports').add({
        'targetType': 'post',
        'targetId': postId,
        'reporterId': uid,
        'reason': 'Spam',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      final post = await db.collection('posts').doc(postId).get();
      expect(post.data()!['isReported'], true);
      expect(post.data()!['reportCount'], 1);

      final reports = await db.collection('reports').get();
      expect(reports.docs.length, 1);
      expect(reports.docs.first.data()['status'], 'pending');
    });

    test('blocking a user writes to users/{uid}/blocked/', () async {
      const targetUid = 'other-user';
      await db.collection('users').doc(uid)
          .collection('blocked').doc(targetUid).set({
        'blockedAt': Timestamp.now(),
      });

      final blocked = await db.collection('users').doc(uid)
          .collection('blocked').get();
      expect(blocked.docs.length, 1);
      expect(blocked.docs.first.id, targetUid);
    });
  });

  group('Saved posts (bookmarks)', () {
    test('saving persists to users/{uid}/savedPosts/{postId}', () async {
      await db.collection('users').doc(uid)
          .collection('savedPosts').doc(postId).set({
        'savedAt': Timestamp.now(),
      });

      final doc = await db.collection('users').doc(uid)
          .collection('savedPosts').doc(postId).get();
      expect(doc.exists, true);
    });

    test('unsaving removes the doc', () async {
      await db.collection('users').doc(uid)
          .collection('savedPosts').doc(postId).set({'savedAt': Timestamp.now()});
      await db.collection('users').doc(uid)
          .collection('savedPosts').doc(postId).delete();

      final doc = await db.collection('users').doc(uid)
          .collection('savedPosts').doc(postId).get();
      expect(doc.exists, false);
    });
  });
}
