import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore_mocks/cloud_firestore_mocks.dart';
import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';
import 'package:mockito/mockito.dart';

import 'mock_snapshot.dart';

class MockQuery extends Mock implements Query {
  List<DocumentSnapshot> documents;
  final MockFirestoreInstance _firestore;

  MockQuery(this._firestore, this.documents);

  // ignore: unused_field
  final QueryPlatform _delegate = null;

  @override
  Future<QuerySnapshot> getDocuments({Source source = Source.serverAndCache}) {
    final savedDocuments = documents.where((snapshot) => _firestore._hasSavedDocument(snapshot.reference.path)).toList();
    return Future.value(MockSnapshot(savedDocuments));
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    return Stream.fromIterable([MockSnapshot(documents)]);
  }

  Query orderBy(dynamic field, {bool descending = false}) {
    final sortedList = List.of(documents);
    sortedList.sort((d1, d2) {
      final value1 = d1.data[field] as Comparable;
      final value2 = d2.data[field];
      final compare = value1.compareTo(value2);
      return descending ? -compare : compare;
    });
    return MockQuery(_firestore, sortedList);
  }

  Query limit(int length) {
    return MockQuery(_firestore, documents.sublist(0, min(documents.length, length)));
  }

  @override
  Query where(dynamic field,
      {dynamic isEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic> arrayContainsAny,
      List<dynamic> whereIn,
      bool isNull}) {
    final matchingDocuments = this.documents.where((document) {
      return _valueMatchesQuery(document[field],
          isEqualTo: isEqualTo,
          isLessThan: isLessThan,
          isLessThanOrEqualTo: isLessThanOrEqualTo,
          isGreaterThan: isGreaterThan,
          isGreaterThanOrEqualTo: isGreaterThanOrEqualTo,
          arrayContains: arrayContains,
          arrayContainsAny: arrayContainsAny,
          whereIn: whereIn,
          isNull: isNull);
    }).toList();
    return MockQuery(_firestore, matchingDocuments);
  }

  bool _valueMatchesQuery(dynamic value,
      {dynamic isEqualTo,
      dynamic isLessThan,
      dynamic isLessThanOrEqualTo,
      dynamic isGreaterThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic arrayContains,
      List<dynamic> arrayContainsAny,
      List<dynamic> whereIn,
      bool isNull}) {
    if (isEqualTo != null) {
      return value == isEqualTo;
    } else if (isGreaterThan != null) {
      Comparable fieldValue = value;
      if (isGreaterThan is DateTime) {
        isGreaterThan = Timestamp.fromDate(isGreaterThan);
      }
      return fieldValue.compareTo(isGreaterThan) > 0;
    } else if (isGreaterThanOrEqualTo != null) {
      Comparable fieldValue = value;
      if (isGreaterThanOrEqualTo is DateTime) {
        isGreaterThanOrEqualTo = Timestamp.fromDate(isGreaterThanOrEqualTo);
      }
      return fieldValue.compareTo(isGreaterThanOrEqualTo) >= 0;
    } else if (isLessThan != null) {
      Comparable fieldValue = value;
      if (isLessThan is DateTime) {
        isLessThan = Timestamp.fromDate(isLessThan);
      }
      return fieldValue.compareTo(isLessThan) < 0;
    } else if (isLessThanOrEqualTo != null) {
      Comparable fieldValue = value;
      if (isLessThanOrEqualTo is DateTime) {
        isLessThanOrEqualTo = Timestamp.fromDate(isLessThanOrEqualTo);
      }
      return fieldValue.compareTo(isLessThanOrEqualTo) <= 0;
    }
    throw "Unsupported";
  }
}
