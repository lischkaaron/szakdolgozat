import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friend.dart';
import '../models/user.dart';
import '../services/friends_service.dart';
import '../state/auth_controller.dart';
import '../widgets/app_widgets.dart';

// ---------------------------------------------------------------------------
// 4. KÉPERNYŐ: PROFIL – a bejelentkezett felhasználó adatai és barátai.
//    Az adatok a backendről jönnek (GET /api/users/me, GET /api/friends).
// ---------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Friend>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _loadFriends();
  }

  Future<List<Friend>> _loadFriends() {
    return context.read<FriendsService>().fetchFriends();
  }

  Future<void> _refreshFriends() async {
    final future = _loadFriends();
    setState(() {
      _friendsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // A hibát a FutureBuilder jeleníti meg.
    }
  }

  Future<void> _editProfile(User user) async {
    final formKey = GlobalKey<FormState>();
    final displayNameController = TextEditingController(text: user.displayName);
    final motorcycleController = TextEditingController(
      text: user.motorcycle ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Profil szerkesztése'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('profileDisplayNameField'),
                  controller: displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Név',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value?.trim() ?? '').length < 2) {
                      return 'Legalább 2 karakter kell.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('profileMotorcycleField'),
                  controller: motorcycleController,
                  decoration: const InputDecoration(
                    labelText: 'Motor',
                    hintText: 'pl. Yamaha MT-07',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('MÉGSE'),
            ),
            ElevatedButton(
              key: const Key('profileSaveButton'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('MENTÉS'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) {
      displayNameController.dispose();
      motorcycleController.dispose();
      return;
    }

    await context.read<AuthController>().updateProfile(
      displayName: displayNameController.text.trim(),
      motorcycle: motorcycleController.text.trim(),
    );

    displayNameController.dispose();
    motorcycleController.dispose();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kijelentkezés'),
          content: const Text('Biztosan ki akarsz jelentkezni?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('MÉGSE'),
            ),
            TextButton(
              key: const Key('logoutConfirmButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('KIJELENTKEZÉS'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    await context.read<AuthController>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshFriends,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.amber,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      user.displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  if ((user.motorcycle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(child: InfoChip(user.motorcycle!)),
                  ],
                  const SizedBox(height: 28),
                  _buildFriendCard(),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const Key('editProfileButton'),
                    onPressed: () => _editProfile(user),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Profil szerkesztése'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('logoutButton'),
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Kijelentkezés'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFriendCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<List<Friend>>(
        future: _friendsFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasError = snapshot.hasError;
          final count = snapshot.data?.length ?? 0;

          return Column(
            children: [
              const Text('BARÁTOK', style: sectionLabelStyle),
              const SizedBox(height: 6),
              Text(
                isLoading ? '…' : (hasError ? '–' : '$count'),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasError) ...[
                const SizedBox(height: 4),
                Text(
                  'A barátlista most nem érhető el.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
