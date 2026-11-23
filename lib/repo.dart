// Zugriff auf Cloud Firestore. Alle Handys lesen und schreiben dieselben Dokumente.
//
// Aufbau:
//   users/{uid}                       {familyId}
//   invites/{code}                    {familyId}
//   families/{fid}                    {name, createdBy, inviteCode}
//   families/{fid}/members/{uid}      {name, color, inviteCode?}
//   families/{fid}/shiftTypes/{id}    ShiftType
//   families/{fid}/entries/{entryId}  Entry  (entryId = uid_JJJJMMTT_platz)
import 'package:cloud_firestore/cloud_firestore.dart';

import 'logic.dart';
import 'models.dart';

class Repo {
  Repo(this.db, this.uid);

  final FirebaseFirestore db;
  final String uid;

  DocumentReference<Map<String, dynamic>> get _userDoc => db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _family(String fid) => db.collection('families').doc(fid);

  /// Familie des Nutzers. Nur vom Server bestätigte Stände zählen: Sonst meldet der lokale
  /// Zwischenspeicher die Familie schon, bevor der Server die Mitgliedschaft kennt, und die
  /// folgenden Abfragen scheitern an den Zugriffsregeln (permission-denied).
  Stream<String?> familyId() => _userDoc
      .snapshots(includeMetadataChanges: true)
      .where((s) => !s.metadata.hasPendingWrites)
      .map((s) => s.data()?['familyId'] as String?)
      .distinct();

  Stream<Family?> family(String fid) =>
      _family(fid).snapshots().map((s) => s.exists ? Family.fromMap(s.id, s.data()!) : null);

  Stream<List<Member>> members(String fid) => _family(fid).collection('members').snapshots().map((q) {
        final list = q.docs.map((d) => Member.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Stream<List<ShiftType>> shiftTypes(String fid) => _family(fid).collection('shiftTypes').snapshots().map((q) {
        final list = q.docs.map((d) => ShiftType.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
        return list;
      });

  /// Einträge aller Personen von `from` bis `to` (jeweils `JJJJ-MM-TT`, einschließlich).
  Stream<List<Entry>> entries(String fid, String from, String to) => _family(fid)
      .collection('entries')
      .where('date', isGreaterThanOrEqualTo: from)
      .where('date', isLessThanOrEqualTo: to)
      .snapshots()
      .map((q) => q.docs.map((d) => Entry.fromMap(d.id, d.data())).toList());

  Future<void> createFamily({required String familyName, required String memberName}) async {
    final famRef = db.collection('families').doc();
    var code = newInviteCode();
    for (var i = 0; i < 5; i++) {
      final existing = await db.collection('invites').doc(code).get();
      if (!existing.exists) break;
      code = newInviteCode();
    }
    final batch = db.batch();
    batch.set(famRef, {
      'name': familyName,
      'createdBy': uid,
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(famRef.collection('members').doc(uid), {
      'name': memberName,
      'color': memberPalette.first.toARGB32(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('invites').doc(code), {'familyId': famRef.id});
    batch.set(_userDoc, {'familyId': famRef.id});
    await batch.commit();
  }

  /// Tritt per Einladungscode bei. Wirft [StateError], wenn der Code unbekannt ist.
  Future<void> joinFamily({required String code, required String memberName}) async {
    final normalized = normalizeInviteCode(code);
    final invite = await db.collection('invites').doc(normalized).get();
    final fid = invite.data()?['familyId'] as String?;
    if (!invite.exists || fid == null) {
      throw StateError('Diesen Einladungscode gibt es nicht.');
    }
    final color = memberPalette[uid.hashCode.abs() % memberPalette.length].toARGB32();
    final batch = db.batch();
    batch.set(_family(fid).collection('members').doc(uid), {
      'name': memberName,
      'color': color,
      'inviteCode': normalized,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_userDoc, {'familyId': fid});
    await batch.commit();
  }

  Future<void> updateMe(String fid, {required String name, required int color}) =>
      _family(fid).collection('members').doc(uid).set({'name': name, 'color': color}, SetOptions(merge: true));

  Future<void> saveShiftType(String fid, ShiftType type) {
    final col = _family(fid).collection('shiftTypes');
    final ref = type.id.isEmpty ? col.doc() : col.doc(type.id);
    return ref.set(type.copyWith(id: ref.id).toMap());
  }

  Future<void> setEntry(String fid, DateTime day, int slot, String shiftTypeId) {
    final id = entryId(uid, day, slot);
    final entry = Entry(id: id, owner: uid, date: dateKey(day), slot: slot, shiftTypeId: shiftTypeId);
    return _family(fid).collection('entries').doc(id).set(entry.toMap());
  }

  Future<void> deleteEntry(String fid, String id) => _family(fid).collection('entries').doc(id).delete();
}
