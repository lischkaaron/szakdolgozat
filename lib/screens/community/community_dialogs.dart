import 'package:flutter/material.dart';

import '../../models/friend.dart';
import '../../widgets/app_widgets.dart';

/// Egységes visszajelzés a közösség képernyőn.
void showCommunityMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 3),
      backgroundColor: isError ? const Color(0xFFB3261E) : null,
    ),
  );
}

/// Megerősítő dialógus (törlés, kilépés, eltávolítás).
Future<bool> confirmCommunityAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'TÖRLÉS',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('MÉGSE'),
          ),
          ElevatedButton(
            key: const Key('confirmActionButton'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

/// A csoport-szerkesztő dialógus eredménye.
class GroupDraft {
  const GroupDraft({required this.name, this.description});

  final String name;
  final String? description;
}

/// Csoport létrehozása vagy szerkesztése (név kötelező, leírás opcionális).
Future<GroupDraft?> showGroupEditorDialog(
  BuildContext context, {
  required String title,
  String? initialName,
  String? initialDescription,
}) {
  return showDialog<GroupDraft>(
    context: context,
    builder: (_) => _GroupEditorDialog(
      title: title,
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

class _GroupEditorDialog extends StatefulWidget {
  const _GroupEditorDialog({
    required this.title,
    this.initialName,
    this.initialDescription,
  });

  final String title;
  final String? initialName;
  final String? initialDescription;

  @override
  State<_GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<_GroupEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initialDescription ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final description = _descriptionController.text.trim();
    Navigator.of(context).pop(
      GroupDraft(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('groupNameField'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Csoport neve',
                  hintText: 'pl. Betyár Riders Klub',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.length < 2) {
                    return 'Legalább 2 karakter kell.';
                  }
                  if (name.length > 80) {
                    return 'Legfeljebb 80 karakter lehet.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('groupDescriptionField'),
                controller: _descriptionController,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Leírás (nem kötelező)',
                  hintText: 'pl. Hétvégi túrázó csapat',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('MÉGSE'),
        ),
        ElevatedButton(
          key: const Key('groupSaveButton'),
          onPressed: _save,
          child: const Text('MENTÉS'),
        ),
      ],
    );
  }
}


/// Barát kiválasztása a csoporthoz (csak a még nem tag barátok közül).
Future<Friend?> showAddGroupMemberDialog(
  BuildContext context, {
  required String groupName,
  required List<Friend> candidates,
}) {
  return showDialog<Friend>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tag hozzáadása – $groupName',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final friend in candidates)
                ListTile(
                  key: Key('addMemberCandidate_${friend.id}'),
                  leading: InitialsAvatar(initials: friend.initials),
                  title: Text(friend.displayName),
                  subtitle: Text(
                    friend.motorcycle ?? friend.email ?? '',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF616161),
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(friend),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('MÉGSE'),
          ),
        ],
      );
    },
  );
}


