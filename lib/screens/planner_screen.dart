import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/friend.dart';
import '../models/group.dart';
import '../models/tour.dart';
import '../services/api_client.dart';
import '../services/friends_service.dart';
import '../services/groups_service.dart';
import '../services/tours_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/map_placeholder.dart';

// ---------------------------------------------------------------------------
// 2. KÉPERNYŐ: TÚRATERVEZŐ ÉS AI AJÁNLÓ NÉZET
//    0. lépés: csak térkép + úti cél keresősáv, majd az indulási hely választása
//    1. lépés: a kiválasztott útvonal a térképen + AI elemzés indítása
//    2. lépés: AI ajánlások, résztvevők meghívása, túra mentése és indítása
// ---------------------------------------------------------------------------
class TourPlannerScreen extends StatefulWidget {
  /// A túra indítása: az indulási helyet és az úti célt adja tovább a fő nézetnek.
  final void Function(String origin, String destination) onStartTour;

  const TourPlannerScreen({super.key, required this.onStartTour});

  @override
  State<TourPlannerScreen> createState() => _TourPlannerScreenState();
}

class _TourPlannerScreenState extends State<TourPlannerScreen> {
  // 0 = térkép + úti cél keresése, 1 = útvonal a térképen, 2 = AI elemzés
  int _step = 0;

  // A keresősáv javaslatai (a prototípusban statikus helylista).
  static const List<String> _popularPlaces = <String>[
    'Balatonfüred',
    'Eger',
    'Mátra',
    'Kékes',
    'Tihany',
    'Dunakanyar',
    'Tokaj',
    'Pécs',
  ];

  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final FocusNode _destinationFocus = FocusNode();

  String? _destination;
  bool _useCurrentLocation = true;

  // A túrához meghívható barátok és csoportok a backendről.
  List<Friend> _friends = const <Friend>[];
  List<BikeGroup> _groups = const <BikeGroup>[];
  final Set<String> _selectedFriendIds = <String>{};
  final Set<String> _selectedGroupIds = <String>{};

  bool _inviteLoading = true;
  String? _inviteError;
  bool _savingTour = false;

  FriendsService get _friendsService => context.read<FriendsService>();
  GroupsService get _groupsService => context.read<GroupsService>();
  ToursService get _toursService => context.read<ToursService>();

  @override
  void initState() {
    super.initState();
    _destinationFocus.addListener(_handleDestinationFocusChange);
    _loadInvitees();
  }

  /// Barátok és csoportok betöltése a "RÉSZTVEVŐK MEGHÍVÁSA" kártyához.
  Future<void> _loadInvitees() async {
    if (mounted) {
      setState(() {
        _inviteLoading = true;
        _inviteError = null;
      });
    }

    try {
      final friends = await _friendsService.fetchFriends();

      // A csoportok csak kényelmi meghíváshoz kellenek; ha nem jönnek be,
      // a barátlistával akkor is működik a kártya.
      List<BikeGroup> groups = const <BikeGroup>[];
      try {
        groups = await _groupsService.fetchGroups();
      } on ApiException {
        groups = const <BikeGroup>[];
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _friends = friends;
        _groups = groups;
        _inviteLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _inviteError = error.message;
        _inviteLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _destinationFocus.removeListener(_handleDestinationFocusChange);
    _destinationFocus.dispose();
    _destinationController.dispose();
    _originController.dispose();
    super.dispose();
  }

  void _handleDestinationFocusChange() {
    setState(() {});
  }

  // A kiválasztott indulási hely megjelenített neve.
  String get _originLabel {
    final String typed = _originController.text.trim();
    if (!_useCurrentLocation && typed.isNotEmpty) {
      return typed;
    }
    return 'Jelenlegi hely';
  }

  String get _destinationLabel => _destination ?? 'Eger';

  // Az útvonal a választott indulással és úti céllal jelenik meg a térképen.
  List<MapPin> get _routePins => <MapPin>[
    MapPin(left: 0.12, top: 0.82, label: _originLabel, type: MapPinType.start),
    const MapPin(
      left: 0.44,
      top: 0.66,
      label: 'Mátra',
      type: MapPinType.waypoint,
    ),
    MapPin(
      left: 0.70,
      top: 0.20,
      label: _destinationLabel,
      type: MapPinType.end,
    ),
  ];

  List<String> get _filteredPlaces {
    final String query = _destinationController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _popularPlaces;
    }
    return _popularPlaces
        .where((String place) => place.toLowerCase().contains(query))
        .toList();
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
    });
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _toggleFriend(String friendId) {
    setState(() {
      if (!_selectedFriendIds.remove(friendId)) {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  void _toggleGroup(String groupId) {
    setState(() {
      if (!_selectedGroupIds.remove(groupId)) {
        _selectedGroupIds.add(groupId);
      }
    });
  }

  /// A túra mentése a backendre (`draft`) vagy indítása (`active`).
  /// Hiba esetén hibaüzenetet mutat, és null-lal tér vissza.
  Future<BikeTour?> _persistTour(String status) async {
    if (_savingTour) {
      return null;
    }

    setState(() => _savingTour = true);

    try {
      final tour = await _toursService.createTour(
        title: '$_originLabel ➔ $_destinationLabel',
        originName: _originLabel,
        destinationName: _destinationLabel,
        status: status,
        inviteUserIds: _selectedFriendIds.toList(),
        inviteGroupIds: _selectedGroupIds.toList(),
      );

      if (!mounted) {
        return tour;
      }

      // Indításkor a túra képernyő veszi át a vezetést, ott nem kell üzenet.
      if (status != 'active') {
        final memberText = tour.memberCount > 1
            ? ' • ${tour.memberCount} résztvevő'
            : '';
        _showMessage(context, 'Túra elmentve: ${tour.title}$memberText');
      }

      return tour;
    } on ApiException catch (error) {
      if (!mounted) {
        return null;
      }

      _showMessage(context, error.message);
      return null;
    } finally {
      if (mounted) {
        setState(() => _savingTour = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 0. lépés: Google Maps-szerű indítás – csak térkép és keresősáv.
    if (_step == 0) {
      return _buildDestinationMapStep();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Túratervező & AI Asszisztens')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StepIndicator(currentStep: _step),
          const SizedBox(height: 16),
          if (_step >= 1) ...[
            _SelectedRouteCard(
              origin: _originLabel,
              destination: _destinationLabel,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _step == 1 ? 240 : 160,
              child: MapPlaceholder(
                showRoute: true,
                pins: _routePins,
                caption: 'Előnézet: a kiválasztott útvonal',
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
          if (_step == 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: _primaryButtonStyle(),
                onPressed: () => _goTo(2),
                icon: const Icon(Icons.auto_awesome),
                label: const Text(
                  'ÚTVONAL AI ELEMZÉSE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _goTo(0),
              child: const Text('Útvonal módosítása'),
            ),
          ],
          if (_step == 2) ...[
            const SizedBox(height: 20),
            const SectionTitle('AI által javasolt megállók:'),
            const _RecommendationCard(
              icon: Icons.landscape_outlined,
              category: 'Látnivaló / Fotópont',
              name: 'Kékesi kilátó',
              detail: '+3 km kitérő • 4.8',
            ),
            const SizedBox(height: 10),
            const _RecommendationCard(
              icon: Icons.restaurant_outlined,
              category: 'Étterem',
              name: 'Motoros Pihenő & Büfé',
              detail: 'Útvonalon • 4.6',
            ),
            const SizedBox(height: 10),
            const _RecommendationCard(
              icon: Icons.hotel_outlined,
              category: 'Szállás',
              name: 'Mátra Vendégház',
              detail: '+1 km kitérő • 4.7',
            ),
            const SizedBox(height: 10),
            const _RecommendationCard(
              icon: Icons.local_gas_station_outlined,
              category: 'Benzinkút / Pihenő',
              name: 'MOL Gyöngyös',
              detail: 'Útvonalon • 4.4',
            ),
            const SizedBox(height: 16),
            _buildInviteCard(context),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFBDBDBD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _savingTour ? null : () => _persistTour('draft'),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text(
                  'TÚRA MENTÉSE',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: _primaryButtonStyle(),
                onPressed: _savingTour
                    ? null
                    : () async {
                        final tour = await _persistTour('active');

                        if (tour != null && mounted) {
                          widget.onStartTour(_originLabel, _destinationLabel);
                        }
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'TÚRA INDÍTÁSA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            TextButton(
              onPressed: _restartPlanning,
              child: const Text('Új túra tervezése'),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.amber,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
    );
  }

  // 0. lépés: csak a térkép látszik, felül az úti cél keresősávval.
  // Az úti cél kiválasztása után jelenik meg az indulási hely választó.
  Widget _buildDestinationMapStep() {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPlaceholder(
              pins: _destination == null
                  ? const <MapPin>[]
                  : <MapPin>[
                      MapPin(
                        left: 0.70,
                        top: 0.20,
                        label: _destination!,
                        type: MapPinType.end,
                      ),
                    ],
              caption: 'Keresd meg a térképen, hová szeretnél menni',
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: _destination == null
                    ? const SizedBox(width: double.infinity)
                    : _buildOriginSheet(),
              ),
            ),
          ),
          // A keresősáv és a javaslatok a lap fölött vannak, hogy az úti cél
          // utólagos módosításakor a találati lista ne lógjon a lap alá.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDestinationSearchBar(),
                    if (_destinationFocus.hasFocus) ...[
                      const SizedBox(height: 8),
                      _buildSuggestions(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Felül lebegő keresősáv: itt kereshetünk rá az úti célra.
  Widget _buildDestinationSearchBar() {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        key: const Key('destinationSearchField'),
        controller: _destinationController,
        focusNode: _destinationFocus,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() {
          // A keresett szöveg módosításakor a korábbi választás érvényét veszti.
          _destination = null;
        }),
        onSubmitted: _selectDestination,
        decoration: InputDecoration(
          hintText: 'Hová szeretnél menni?',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _destinationController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Keresés törlése',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearDestination,
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // A keresősáv alatti javaslatlista (népszerű helyek / találatok).
  Widget _buildSuggestions() {
    final List<String> suggestions = _filteredPlaces;
    final String query = _destinationController.text.trim();

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Text(
                query.isEmpty ? 'NÉPSZERŰ ÚTI CÉLOK' : 'TALÁLATOK',
                style: sectionLabelStyle,
              ),
            ),
            for (final String place in suggestions)
              ListTile(
                dense: true,
                leading: const Icon(Icons.location_on_outlined, size: 20),
                title: Text(place),
                onTap: () => _selectDestination(place),
              ),
            if (suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Nincs a listában – írd be az úti célt, és nyomj Entert.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Úti cél kiválasztása: ekkor jelenik meg a honnan választó.
  void _selectDestination(String value) {
    final String place = value.trim();
    if (place.isEmpty) {
      return;
    }

    setState(() {
      _destination = place;
      _destinationController.text = place;
    });
    _destinationFocus.unfocus();
  }

  void _clearDestination() {
    setState(() {
      _destination = null;
      _destinationController.clear();
    });
    _destinationFocus.requestFocus();
  }

  void _restartPlanning() {
    setState(() {
      _step = 0;
      _destination = null;
      _useCurrentLocation = true;
      _destinationController.clear();
      _originController.clear();
    });
    _destinationFocus.unfocus();
  }

  // Alsó lap: honnan indulunk? Jelenlegi hely vagy megadott indulási hely.
  Widget _buildOriginSheet() {
    final bool canContinue =
        _useCurrentLocation || _originController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 18, color: Colors.black87),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('HONNAN INDULUNK?', style: sectionLabelStyle),
                ),
                Flexible(child: InfoChip('Úti cél: ${_destination ?? ''}')),
              ],
            ),
            const SizedBox(height: 12),
            _OriginOption(
              icon: Icons.my_location_rounded,
              title: 'Jelenlegi tartózkodási hely',
              subtitle: 'Indulás GPS alapján, innen',
              selected: _useCurrentLocation,
              onTap: () {
                setState(() {
                  _useCurrentLocation = true;
                  _originController.clear();
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('originSearchField'),
              controller: _originController,
              onTap: () {
                if (_useCurrentLocation) {
                  setState(() {
                    _useCurrentLocation = false;
                  });
                }
              },
              onChanged: (_) {
                setState(() {
                  _useCurrentLocation = false;
                });
              },
              decoration: InputDecoration(
                labelText: 'Vagy indulás más helyről',
                hintText: 'pl. Budapest',
                prefixIcon: const Icon(Icons.trip_origin),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: _primaryButtonStyle(),
              onPressed: canContinue
                  ? () {
                      FocusScope.of(context).unfocus();
                      _goTo(1);
                    }
                  : null,
              icon: const Icon(Icons.alt_route_rounded),
              label: const Text(
                'TOVÁBB A TERVEZÉSHEZ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Túra mentése előtt: barátok vagy egész csoport hozzáadása a túrához.
  Widget _buildInviteCard(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RÉSZTVEVŐK MEGHÍVÁSA', style: sectionLabelStyle),
            const SizedBox(height: 12),
            if (_inviteLoading)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Barátok és csoportok betöltése…'),
                ],
              )
            else if (_inviteError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _inviteError!,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadInvitees,
                    child: const Text('Újra'),
                  ),
                ],
              )
            else ...[
              const Text(
                'Barátok hozzáadása',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_friends.isEmpty)
                Text(
                  'Még nincs barátod – a Közösség fülön jelölhetsz be valakit.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final friend in _friends)
                      _InviteChip(
                        key: Key('inviteFriend_${friend.id}'),
                        initials: friend.initials,
                        label: friend.displayName,
                        selected: _selectedFriendIds.contains(friend.id),
                        onTap: () => _toggleFriend(friend.id),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              const Text(
                'Csoport hozzáadása',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_groups.isEmpty)
                Text(
                  'Még nincs csoportod – a Közösség fülön hozhatsz létre egyet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final group in _groups)
                      _InviteChip(
                        key: Key('inviteGroup_${group.id}'),
                        initials: group.initials,
                        label: group.name,
                        isGroup: true,
                        selected: _selectedGroupIds.contains(group.id),
                        onTap: () => _toggleGroup(group.id),
                      ),
                  ],
                ),
              if (_selectedFriendIds.isNotEmpty ||
                  _selectedGroupIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Kiválasztva: ${_selectedFriendIds.length} barát, '
                  '${_selectedGroupIds.length} csoport',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// Lépésjelző: Útvonal -> Térkép -> AI elemzés
class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  static const List<String> _labels = ['Úti cél', 'Térkép', 'AI elemzés'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentStep
                    ? Colors.amber
                    : const Color(0xFFE0E0E0),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i <= currentStep ? Colors.amber : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= currentStep
                        ? Colors.amber
                        : const Color(0xFFE0E0E0),
                    width: 2,
                  ),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: i <= currentStep ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: i == currentStep
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: i <= currentStep ? Colors.black87 : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OriginOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OriginOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.amber.withValues(alpha: 0.18)
          : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.amber : const Color(0xFFE0E0E0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Colors.black : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedRouteCard extends StatelessWidget {
  final String origin;
  final String destination;

  const _SelectedRouteCard({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('KIVÁLASZTOTT ÚTVONAL', style: sectionLabelStyle),
            const SizedBox(height: 6),
            Text(
              '$origin ➔ Mátra ➔ $destination',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Táv: 165 km  •  Becsült idő: 2 óra 45 perc',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final IconData icon;
  final String category;
  final String name;
  final String detail;

  const _RecommendationCard({
    required this.icon,
    required this.category,
    required this.name,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.amber,
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.toUpperCase(), style: sectionLabelStyle),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, color: Color(0xFF616161)),
          ],
        ),
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  final String initials;
  final String label;
  final VoidCallback onTap;
  final bool isGroup;
  final bool selected;

  const _InviteChip({
    super.key,
    required this.initials,
    required this.label,
    required this.onTap,
    this.isGroup = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.amber : const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.amber : const Color(0xFFE0E0E0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: isGroup
                    ? const Color(0xFF212121)
                    : Colors.amber,
                child: isGroup
                    ? const Icon(Icons.groups, size: 14, color: Colors.white)
                    : Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                size: 16,
                color: selected ? Colors.black : const Color(0xFF616161),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
