// Élő backend elleni füstteszt: a Flutter kliens API rétegét hívja meg.
// Lefedi a regisztrációt, a profilkezelést, a barátkéréseket és a csoportokat.
// Futtatás: dart run tool/api_smoke_test.dart
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:moto_konvoj/services/api_client.dart';
import 'package:moto_konvoj/services/friends_service.dart';
import 'package:moto_konvoj/services/groups_service.dart';
import 'package:moto_konvoj/services/http_auth_api.dart';

Future<void> main() async {
  final client = ApiClient(baseUrl: 'http://localhost:3000/api');
  final api = HttpAuthApi(client);
  final friendsService = FriendsService(client);
  final groupsService = GroupsService(client);
  final suffix = Random().nextInt(99999);

  final session = await api.register(
    email: 'smoke$suffix@example.com',
    password: 'titkosJelszo123',
    displayName: 'Smoke Teszt',
    motorcycle: 'Honda CB500X',
  );
  print('register OK -> ${session.user.displayName} (${session.user.email})');

  api.setToken(session.token);

  final me = await api.fetchMe();
  print('me OK -> ${me.displayName} / ${me.motorcycle} / initials=${me.initials}');

  final updated = await api.updateProfile(
    displayName: 'Smoke Teszt Elek',
    motorcycle: 'Suzuki V-Strom 650',
  );
  print('patch OK -> ${updated.displayName} / ${updated.motorcycle}');

  // --- Barátok -------------------------------------------------------------
  final partnerSession = await api.register(
    email: 'smoke${suffix}b@example.com',
    password: 'titkosJelszo123',
    displayName: 'Smoke Partner',
  );
  final partner = partnerSession.user;
  print('partner register OK -> ${partner.displayName}');

  api.setToken(session.token);
  await friendsService.sendRequest(userId: partner.id);
  print('friend request OK -> ${partner.displayName}');

  api.setToken(partnerSession.token);
  final partnerRequests = await friendsService.fetchPendingRequests();
  final incoming = partnerRequests.firstWhere((request) => request.isIncoming);
  await friendsService.acceptRequest(incoming.id);
  print('accept OK -> kérés: ${incoming.id}');

  api.setToken(session.token);
  final friends = await friendsService.fetchFriends();
  print('friends OK -> ${friends.length} barát (${friends.first.displayName})');

  // --- Csoportok -----------------------------------------------------------
  final group = await groupsService.createGroup(
    name: 'Smoke Csapat $suffix',
    description: 'Füstteszt csoport',
  );
  print(
    'group create OK -> ${group.name} (${group.members.length} tag, '
    'tulajdonos=${group.isOwner})',
  );

  final withMember = await groupsService.addMember(group.id, userId: partner.id);
  print('group add member OK -> ${withMember.memberCount} tag');

  final renamed = await groupsService.updateGroup(
    group.id,
    name: '${group.name} Átnevezve',
    description: 'Módosított leírás',
  );
  print('group rename OK -> ${renamed.name} / ${renamed.description}');

  api.setToken(partnerSession.token);
  final partnerGroups = await groupsService.fetchGroups();
  final partnerView = partnerGroups.firstWhere((item) => item.id == group.id);
  print(
    'partner group view OK -> myRole=${partnerView.myRole}, '
    'saját tag=${partnerView.selfMember?.displayName}',
  );

  await groupsService.removeMember(group.id, partner.id);
  print('leave group OK -> ${partner.displayName} kilépett');

  api.setToken(session.token);
  await groupsService.deleteGroup(group.id);
  final afterDelete = await groupsService.fetchGroups();
  print('group delete OK -> maradék csoport: ${afterDelete.length}');

  // --- Hibakezelés ---------------------------------------------------------
  try {
    await api.login(email: 'smoke$suffix@example.com', password: 'rosszJelszo');
    print('HIBA: a hibás jelszó nem dobott kivételt');
  } on ApiException catch (error) {
    print('hibakezelés OK -> HTTP ${error.statusCode}: ${error.message}');
  }

  await friendsService.removeFriend(partner.id);
  print('friend remove OK -> ${partner.displayName}');

  try {
    await friendsService.removeFriend(partner.id);
    print('HIBA: a barát törlése nem dobott kivételt');
  } on ApiException catch (error) {
    print('barát törlés hibakezelés OK -> HTTP ${error.statusCode}');
  }

  client.close();
  print('SMOKE TEST PASSED');
}

