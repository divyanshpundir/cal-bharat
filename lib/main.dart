import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/nutrition_result.dart';
import 'services/gemini_vision_service.dart';
import 'utils/image_picker_compat.dart';
import 'utils/picked_image.dart';
import 'web/web_file_picker_stub.dart'
    if (dart.library.html) 'web/web_file_picker.dart' as webpick;
import 'firebase/firebase_bootstrap.dart';
import 'auth/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalBharatApp());
}

class CalBharatApp extends StatelessWidget {
  const CalBharatApp({super.key});
  static const Color saffron = Color(0xFFFF7A00);
  static const Color surface = Colors.white;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cal भारत',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: saffron,
          brightness: Brightness.light,
        ).copyWith(primary: saffron, surface: surface),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const FirebaseBootstrap(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) return const LoginScreen();
        return const AppShell();
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const HomeScreen(), const LogScreen(), const ProfileScreen()];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int goalCalories = 2000;
  int _todayCalories = 0;

  PickedImage? _pickedImage;
  webpick.WebPickedImage? _webPicked;
  NutritionResult? _result;
  String? _error;
  bool _loading = false;
  bool _logging = false;

  @override
  void initState() {
    super.initState();
    _loadTodayCalories();
  }

  Future<void> _loadTodayCalories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await FirebaseFirestore.instance
        .collection('meals')
        .where('user_id', isEqualTo: uid)
        .where('logged_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    int total = 0;
    for (final doc in snap.docs) {
      total += (doc['calories'] as num).toInt();
    }
    if (mounted) setState(() => _todayCalories = total);
  }

  Future<void> _logMeal() async {
    if (_result == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _logging = true);
    try {
      await FirebaseFirestore.instance.collection('meals').add({
        'user_id': uid,
        'dish_name': _result!.dishName,
        'calories': _result!.calories,
        'protein': _result!.protein,
        'carbs': _result!.carbs,
        'fat': _result!.fat,
        'logged_at': FieldValue.serverTimestamp(),
      });
      await _loadTodayCalories();
      if (mounted) {
        setState(() {
          _result = null;
          _pickedImage = null;
          _webPicked = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal logged! ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _scanFood() async {
    setState(() { _error = null; _result = null; });

    if (kIsWeb) {
      final webImage = await webpick.pickImageWithHtmlInput();
      if (webImage == null) return;
      setState(() { _webPicked = webImage; _pickedImage = null; _loading = true; });
    } else {
      final image = await pickImageFromGallery();
      if (image == null) return;
      setState(() { _pickedImage = image; _webPicked = null; _loading = true; });
    }

    try {
      const apiKey = String.fromEnvironment('GROQ_API_KEY');
      final service = GeminiVisionService(apiKey: apiKey);
      final res = kIsWeb
          ? await service.analyzeFoodImageBase64(
              base64Image: _webPicked!.base64, mimeType: _webPicked!.mimeType)
          : await service.analyzeFoodImageBytes(
              imageBytes: _pickedImage!.bytes, mimeType: _pickedImage!.mimeType);
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = goalCalories <= 0
        ? 0.0
        : (_todayCalories / goalCalories).clamp(0.0, 1.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cal भारत',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 14),
            _PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's calories",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_todayCalories',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1)),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('of $goalCalories kcal',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color:
                                        Colors.black.withValues(alpha: 0.55),
                                    fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_webPicked != null) ...[
              _PremiumCard(
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_webPicked!.dataUrl,
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected photo',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(_webPicked!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color:
                                        Colors.black.withValues(alpha: 0.60),
                                    fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            if (_loading) ...[
              _PremiumCard(
                child: Row(children: [
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Analyzing photo…',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              _PremiumCard(
                child: Text(_error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
            ],
            if (_result != null) ...[
              _ResultCard(result: _result!, pickedImage: _pickedImage),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _logging ? null : _logMeal,
                  icon: _logging
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_logging ? 'Logging…' : 'Log This Meal ✅'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints.tightFor(height: 58),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2),
                  ),
                  onPressed: _loading ? null : _scanFood,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Scan Food 📸'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10))
        ],
      ),
      child: child,
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.pickedImage});
  final NutritionResult result;
  final PickedImage? pickedImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black.withValues(alpha: 0.55), fontWeight: FontWeight.w700);
    final valueStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w800);

    Widget metric(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 4),
            Text(value, style: valueStyle),
          ]),
        );

    return _PremiumCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pickedImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(pickedImage!.bytes,
                  width: 64, height: 64, fit: BoxFit.cover),
            ),
          if (pickedImage != null) const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(result.dishName.isEmpty ? 'Dish' : result.dishName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text(
                  result.portionSize.isEmpty
                      ? 'Portion: (unknown)'
                      : 'Portion: ${result.portionSize}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Confidence: ${result.confidence}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          metric('Calories', '${result.calories} kcal'),
          const SizedBox(width: 10),
          metric('Protein', '${result.protein} g'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          metric('Carbs', '${result.carbs} g'),
          const SizedBox(width: 10),
          metric('Fat', '${result.fat} g'),
        ]),
      ]),
    );
  }
}

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Meal Log',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 14),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Not logged in'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('meals')
                        .where('user_id', isEqualTo: uid)
                        .where('logged_at',
                            isGreaterThanOrEqualTo:
                                Timestamp.fromDate(startOfDay))
                        .orderBy('logged_at', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🍽️',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text('No meals logged today',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black54)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final data =
                              docs[i].data() as Map<String, dynamic>;
                          final ts = data['logged_at'] as Timestamp?;
                          final time = ts != null
                              ? TimeOfDay.fromDateTime(ts.toDate())
                                  .format(context)
                              : '';
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.06)),
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['dish_name'] ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(time,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Colors.black54,
                                                fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              Text('${data['calories']} kcal',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFF7A00))),
                            ]),
                          );
                        },
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Profile',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900, letterSpacing: -0.4)),
          const SizedBox(height: 14),
          _PremiumCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Hello 👋' : name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(email.isEmpty ? 'No email' : email,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () async => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ]),
      ),
    );
  }
}