import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

import 'mock_document_reference.dart';
import 'mock_document_snapshot.dart';
import 'mock_query.dart';
import 'mock_snapshot.dart';
import 'util.dart';

const snapshotsStreamKey = '_snapshots';

class MockCollectionReference extends MockQuery implements CollectionReference {
  final Map<String, dynamic> root;
  final Map<String, dynamic> snapshotStreamControllerRoot;
  String currentChildId = '';

  // ignore: unused_field
  final CollectionReferencePlatform _delegate = null;

  StreamController<QuerySnapshot> get snapshotStreamController {
    if (!snapshotStreamControllerRoot.containsKey(snapshotsStreamKey)) {
      snapshotStreamControllerRoot[snapshotsStreamKey] =
          StreamController<QuerySnapshot>.broadcast();
    }
    return snapshotStreamControllerRoot[snapshotsStreamKey];
  }

  MockCollectionReference(this.root, this.snapshotStreamControllerRoot)
      : super(root.entries
            .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
            .toList());

  static final Random _random = Random();
  static final String _autoIdCharacters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static String _generateAutoId() {
    final maxIndex = _autoIdCharacters.length - 1;
    final autoId = List<int>.generate(20, (_) => _random.nextInt(maxIndex))
        .map((i) => _autoIdCharacters[i])
        .join();
    return autoId;
  }

  @override
  DocumentReference document([String path]) {
    if (path == null) {
      path = _generateAutoId();
    }

    return MockDocumentReference(path, root, snapshotStreamControllerRoot);
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) {
    while (currentChildId.isEmpty || root.containsKey(currentChildId)) {
      currentChildId += 'z';
    }
    final keysWithDateTime = data.keys.where((key) => data[key] is DateTime);
    for (final key in keysWithDateTime) {
      data[key] = Timestamp.fromDate(data[key]);
    }
    root[currentChildId] = data;
    fireSnapshotUpdate();
    final doc = document(currentChildId);
    return Future.value(doc);
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    Future(() {
      fireSnapshotUpdate();
    });
    return snapshotStreamController.stream;
  }

  fireSnapshotUpdate() {
    final documents = root.entries
        .map((entry) => MockDocumentSnapshot(entry.key, entry.value))
        .toList();
    snapshotStreamController.add(MockSnapshot(documents));
  }
}
