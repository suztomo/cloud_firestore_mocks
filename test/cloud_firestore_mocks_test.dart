import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:test/test.dart';

const expectedDumpAfterSetData = """{
  "users": {
    "abc": {
      "name": "Bob"
    }
  }
}""";

const expectedDumpAfterAddData = """{
  "messages": {
    "z": {
      "content": "hello!",
      "uid": "abc"
    }
  }
}""";

const expectedDumpAfterSuccessiveAddData = """{
  "messages": {
    "z": {
      "content": "hello!",
      "uid": "abc"
    },
    "zz": {
      "content": "there!",
      "uid": "abc"
    }
  }
}""";

const uid = 'abc';

void main() {
  group('A group of tests', () {
    test('Sets data for a document within a collection', () async {
      final instance = MockFirestoreInstance();
      await instance.collection('users').document(uid).setData({
        'name': 'Bob',
      });
      expect(instance.dump(), equals(expectedDumpAfterSetData));
    });
    test('Add adds data', () async {
      final instance = MockFirestoreInstance();
      await instance.collection('messages').add({
        'content': 'hello!',
        'uid': uid,
      });
      expect(instance.dump(), equals(expectedDumpAfterAddData));
      await instance.collection('messages').add({
        'content': 'there!',
        'uid': uid,
      });
      expect(instance.dump(), equals(expectedDumpAfterSuccessiveAddData));
    });
    test('nested calls to setData work', () async {
      final firestore = MockFirestoreInstance();
      await firestore
          .collection('userProfiles')
          .document('a')
          .collection('relationship')
          .document('1')
          .setData({'label': 'relationship1'});
      await firestore
          .collection('userProfiles')
          .document('a')
          .collection('relationship')
          .document('2')
          .setData({'label': 'relationship2'});
      expect(
          firestore
              .collection('userProfiles')
              .document('a')
              .collection('relationship')
              .snapshots(),
          emits(QuerySnapshotMatcher([
            DocumentSnapshotMatcher('1', {
              'label': 'relationship1',
            }),
            DocumentSnapshotMatcher('2', {
              'label': 'relationship2',
            })
          ])));
    });
    test('FieldValue.delete() deletes key values', () async {
      final firestore = MockFirestoreInstance();
      firestore.setupFieldValueFactory();
      await firestore.document('root').setData({
        'flower': 'rose'
      });
      await firestore.document('root').setData({
        'flower': FieldValue.delete()
      });
      final document = await firestore.document('root').get();
      expect(document.data.isEmpty, equals(true));
    });
    test('Snapshots returns a Stream of Snapshots', () async {
      final instance = MockFirestoreInstance();
      await instance.collection('users').document(uid).setData({
        'name': 'Bob',
      });
      expect(
          instance.collection('users').snapshots(),
          emits(QuerySnapshotMatcher([
            DocumentSnapshotMatcher('abc', {
              'name': 'Bob',
            })
          ])));
    });
    test('Snapshots returns a Stream of Snapshot', () async {
      final instance = MockFirestoreInstance();
      await instance.collection('users').document(uid).setData({
        'name': 'Bob',
      });
      expect(
          instance.collection('users').document(uid).snapshots(),
          emits(DocumentSnapshotMatcher('abc', {
            'name': 'Bob',
          })));
    });
    test('Chained where queries return the correct snapshots', () async {
      final instance = MockFirestoreInstance();
      final bookmarks = await instance
          .collection('users')
          .document(uid)
          .collection('bookmarks');
      await bookmarks.add({
        'hidden': false,
      });
      await bookmarks.add({
        'tag': 'mostrecent',
        'hidden': false,
      });
      await bookmarks.add({
        'hidden': false,
      });
      await bookmarks.add({
        'tag': 'mostrecent',
        'hidden': true,
      });
      instance
          .collection('users')
          .document(uid)
          .collection('bookmarks')
          .where('hidden', isEqualTo: false)
          .where('tag', isEqualTo: 'mostrecent')
          .snapshots()
          .listen(expectAsync1((QuerySnapshot snapshot) {
        expect(snapshot.documents.length, equals(1));
        expect(snapshot.documents.first.data['tag'], equals('mostrecent'));
      }));
    });
    test(
        'Snapshots sets exists property to false if the document does not exist',
        () async {
      final instance = MockFirestoreInstance();
      await instance.collection('users').document(uid).setData({
        'name': 'Bob',
      });
      instance
          .collection('users')
          .document('doesnotexist')
          .snapshots()
          .listen(expectAsync1((document) {
        expect(document.exists, equals(false));
      }));
    });

    test('Snapshots sets exists property to true if the document does  exist',
        () async {
      final instance = MockFirestoreInstance();
      await instance.collection('users').document(uid).setData({
        'name': 'Bob',
      });
      instance
          .collection('users')
          .document(uid)
          .snapshots()
          .listen(expectAsync1((document) {
        expect(document.exists, equals(true));
      }));
    });

    test('Snapshots returns a Stream of Snapshots upon each change', () async {
      final instance = MockFirestoreInstance();
      expect(
          instance.collection('users').snapshots(),
          emits(QuerySnapshotMatcher([
            DocumentSnapshotMatcher('z', {
              'name': 'Bob',
            })
          ])));
      await instance.collection('users').add({
        'name': 'Bob',
      });
    });
    test('Stores DateTime and returns Timestamps', () async {
      // As per Firebase's implementation.
      final instance = MockFirestoreInstance();
      final now = DateTime.now();
      // Store a DateTime.
      await instance.collection('messages').add({
        'content': 'hello!',
        'uid': uid,
        'timestamp': now,
      });
      // Expect a Timestamp.
      expect(
          instance.collection('messages').snapshots(),
          emits(QuerySnapshotMatcher([
            DocumentSnapshotMatcher('z', {
              'content': 'hello!',
              'uid': uid,
              'timestamp': Timestamp.fromDate(now),
            })
          ])));
    });
    test('Where(field, isGreaterThan: ...)', () async {
      final instance = MockFirestoreInstance();
      final now = DateTime.now();
      await instance.collection('messages').add({
        'content': 'hello!',
        'uid': uid,
        'timestamp': now,
      });
      // Test that there is one result.
      expect(
          instance
              .collection('messages')
              .where('timestamp',
                  isGreaterThan: now.subtract(Duration(seconds: 1)))
              .snapshots(),
          emits(QuerySnapshotMatcher([
            DocumentSnapshotMatcher('z', {
              'content': 'hello!',
              'uid': uid,
              'timestamp': Timestamp.fromDate(now),
            })
          ])));
      // Filter out everything and check that there is no result.
      expect(
          instance
              .collection('messages')
              .where('timestamp', isGreaterThan: now.add(Duration(seconds: 1)))
              .snapshots(),
          emits(QuerySnapshotMatcher([])));
    });
  });
  test('isLessThanOrEqualTo', () async {
    final instance = MockFirestoreInstance();
    final now = DateTime.now();
    final before = now.subtract(Duration(seconds: 1));
    final after = now.add(Duration(seconds: 1));
    await instance.collection('messages').add({
      'content': 'before',
      'timestamp': before,
    });
    await instance.collection('messages').add({
      'content': 'during',
      'timestamp': now,
    });
    await instance.collection('messages').add({
      'content': 'after',
      'timestamp': after,
    });
    // Test filtering.
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThanOrEqualTo: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('z', {
            'content': 'before',
            'timestamp': Timestamp.fromDate(before),
          }),
          DocumentSnapshotMatcher('zz', {
            'content': 'during',
            'timestamp': Timestamp.fromDate(now),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isLessThanOrEqualTo: now.subtract(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThan: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('z', {
            'content': 'before',
            'timestamp': Timestamp.fromDate(before),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isLessThan: now.subtract(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
    expect(
        instance
            .collection('messages')
            .where('timestamp', isGreaterThanOrEqualTo: now)
            .snapshots(),
        emits(QuerySnapshotMatcher([
          DocumentSnapshotMatcher('zz', {
            'content': 'during',
            'timestamp': Timestamp.fromDate(now),
          }),
          DocumentSnapshotMatcher('zzz', {
            'content': 'after',
            'timestamp': Timestamp.fromDate(after),
          }),
        ])));
    expect(
        instance
            .collection('messages')
            .where('timestamp',
                isGreaterThanOrEqualTo: now.add(Duration(seconds: 2)))
            .snapshots(),
        emits(QuerySnapshotMatcher([])));
  });

  test('isEqualTo, orderBy, limit and getDocuments', () async {
    final instance = MockFirestoreInstance();
    final now = DateTime.now();
    final bookmarks = await instance
        .collection('users')
        .document(uid)
        .collection('bookmarks');
    await bookmarks.add({
      'hidden': false,
      'timestamp': now,
    });
    await bookmarks.add({
      'tag': 'mostrecent',
      'hidden': false,
      'timestamp': now.add(Duration(days: 1)),
    });
    await bookmarks.add({
      'hidden': false,
      'timestamp': now,
    });
    await bookmarks.add({
      'hidden': true,
      'timestamp': now,
    });
    final snapshot = (await instance
        .collection('users')
        .document(uid)
        .collection('bookmarks')
        .where('hidden', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(2)
        .getDocuments());
    expect(snapshot.documents.length, equals(2));
    expect(snapshot.documents.first['tag'], equals('mostrecent'));
  });
  test('Collection.getDocuments', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').add({
      'username': 'Bob',
    });
    final snapshot = await instance.collection('users').getDocuments();
    expect(snapshot.documents.length, equals(1));
  });
  test('delete', () async {
    final instance = MockFirestoreInstance();
    await instance.collection('users').document(uid).setData({
      'username': 'Bob',
    });
    await instance.collection('users').document(uid).delete();
    final users = await instance.collection('users').getDocuments();
    expect(users.documents.isEmpty, equals(true));
  });
}

class QuerySnapshotMatcher implements Matcher {
  List<DocumentSnapshotMatcher> _documentSnapshotMatchers;

  QuerySnapshotMatcher(this._documentSnapshotMatchers);

  @override
  Description describe(Description description) {
    return StringDescription("Matches a query snapshot's DocumentSnapshots.");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    mismatchDescription.add("Snapshot does not match expected data.");

    // TODO: this will crash if there are fewer matchers than documents.

    final snapshot = item as QuerySnapshot;
    for (var i = 0; i < snapshot.documents.length; i++) {
      final matcher = _documentSnapshotMatchers[i];
      final item = snapshot.documents[i];
      if (!matcher.matches(item, matchState)) {
        matcher.describeMismatch(
            item, mismatchDescription, matchState, verbose);
      }
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as QuerySnapshot;
    if (snapshot.documents.length != _documentSnapshotMatchers.length) {
      return false;
    }
    for (var i = 0; i < snapshot.documents.length; i++) {
      final matcher = _documentSnapshotMatchers[i];
      if (!matcher.matches(snapshot.documents[i], matchState)) {
        return false;
      }
    }
    return true;
  }
}

class DocumentSnapshotMatcher implements Matcher {
  String _documentId;
  Map<String, dynamic> _data;

  DocumentSnapshotMatcher(this._documentId, this._data);

  @override
  Description describe(Description description) {
    return StringDescription("Matches a snapshot's documentId and data");
  }

  @override
  Description describeMismatch(
      item, Description mismatchDescription, Map matchState, bool verbose) {
    final snapshot = item as DocumentSnapshot;
    // TODO: generate more meaningful descriptions.
    if (!equals(snapshot.documentID).matches(_documentId, matchState)) {
      equals(snapshot.documentID).describeMismatch(
          _documentId, mismatchDescription, matchState, verbose);
    }
    if (!equals(snapshot.data).matches(_data, matchState)) {
      equals(snapshot.data)
          .describeMismatch(_data, mismatchDescription, matchState, verbose);
    }
    return mismatchDescription;
  }

  @override
  bool matches(item, Map matchState) {
    final snapshot = item as DocumentSnapshot;
    return equals(snapshot.documentID).matches(_documentId, matchState) &&
        equals(snapshot.data).matches(_data, matchState);
  }
}
