import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// 3. KÉPERNYŐ: KÖZÖSSÉG & CSAPAT
// ---------------------------------------------------------------------------
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Közösség & Csapatok')),
      body: ListView(
        children: const [
          ListTile(
            leading: CircleAvatar(child: Text('BR')),
            title: Text('Betyár Riders Klub'),
            subtitle: Text('12 tag • 3 aktív túra'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
          ),
          Divider(),
          ListTile(
            leading: CircleAvatar(child: Text('KÁ')),
            title: Text('Kovács Ádám'),
            subtitle: Text('Online • BMW R1250GS'),
            trailing: Icon(Icons.motorcycle),
          ),
          ListTile(
            leading: CircleAvatar(child: Text('NT')),
            title: Text('Nagy Tamás'),
            subtitle: Text('Offline • Yamaha MT-07'),
            trailing: Icon(Icons.motorcycle),
          ),
        ],
      ),
    );
  }
}
