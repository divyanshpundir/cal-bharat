import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

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
  static const Color primary = Color(0xFFFF7A00);
  static const Color bg = Color(0xFFF8F9FA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cal भारत',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(primary: primary, surface: Colors.white),
      ),
      home: const FirebaseBootstrap(),
    );
  }
}

// ─── AUTH GATE ────────────────────────────────────────────────────────────────

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _seenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    setState(() => _seenOnboarding = seen);
  }

  @override
  Widget build(BuildContext context) {
    if (_seenOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_seenOnboarding! && !kIsWeb) {
      return const OnboardingScreen();
    }
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

// ─── ONBOARDING ───────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  final List<Map<String, String>> _pages = [
    {
      'emoji': '🍛',
      'title': 'Cal भारत',
      'subtitle': 'India\'s smartest\nfood tracker',
      'desc': 'Track calories for real Indian food — dal, roti, biryani and more.',
    },
    {
      'emoji': '📸',
      'title': 'Just take a photo',
      'subtitle': 'AI identifies your\nIndian dishes instantly',
      'desc': 'Snap a photo of your meal and get instant calorie breakdown.',
    },
    {
      'emoji': '📊',
      'title': 'Reach your goals',
      'subtitle': 'Track daily progress\nand stay consistent',
      'desc': 'Set your calorie goal and see your weekly progress.',
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _page < 2
                    ? TextButton(
                        onPressed: _finishOnboarding,
                        child: const Text('Skip',
                            style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600)),
                      )
                    : const SizedBox(height: 40),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p['emoji']!, style: const TextStyle(fontSize: 80)),
                        const SizedBox(height: 32),
                        Text(p['title']!,
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(p['subtitle']!,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFFF7A00)),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(p['desc']!,
                            style: const TextStyle(fontSize: 15, color: Colors.black45, height: 1.5),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? const Color(0xFFFF7A00) : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    if (_page < 2) {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut);
                    } else {
                      _finishOnboarding();
                    }
                  },
                  child: Text(_page < 2 ? 'Next →' : 'Get Started 🚀'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── APP SHELL ────────────────────────────────────────────────────────────────

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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: const Color(0xFFFF7A00).withValues(alpha: 0.1),
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home, color: Color(0xFFFF7A00)),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt, color: Color(0xFFFF7A00)),
                label: 'Log'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: Color(0xFFFF7A00)),
                label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─── INDIAN FOOD DATABASE ─────────────────────────────────────────────────────

const Map<String, Map<String, int>> indianFoodDB = {
  'dal makhani': {'calories': 130, 'protein': 6, 'carbs': 14, 'fat': 7},
  'dal tadka': {'calories': 110, 'protein': 7, 'carbs': 15, 'fat': 4},
  'dal fry': {'calories': 105, 'protein': 6, 'carbs': 14, 'fat': 4},
  'rajma': {'calories': 125, 'protein': 8, 'carbs': 20, 'fat': 2},
  'rajma chawal': {'calories': 255, 'protein': 11, 'carbs': 48, 'fat': 2},
  'chole': {'calories': 160, 'protein': 9, 'carbs': 25, 'fat': 4},
  'chole bhature': {'calories': 450, 'protein': 12, 'carbs': 65, 'fat': 18},
  'moong dal': {'calories': 90, 'protein': 7, 'carbs': 14, 'fat': 1},
  'masoor dal': {'calories': 100, 'protein': 8, 'carbs': 16, 'fat': 1},
  'chana masala': {'calories': 165, 'protein': 9, 'carbs': 26, 'fat': 4},
  'sambar': {'calories': 80, 'protein': 4, 'carbs': 12, 'fat': 2},
  'kadhi': {'calories': 95, 'protein': 4, 'carbs': 10, 'fat': 5},
  'kadhi chawal': {'calories': 225, 'protein': 7, 'carbs': 38, 'fat': 5},
  'roti': {'calories': 70, 'protein': 3, 'carbs': 15, 'fat': 1},
  'chapati': {'calories': 70, 'protein': 3, 'carbs': 15, 'fat': 1},
  'paratha': {'calories': 200, 'protein': 4, 'carbs': 30, 'fat': 8},
  'aloo paratha': {'calories': 250, 'protein': 5, 'carbs': 35, 'fat': 10},
  'gobi paratha': {'calories': 230, 'protein': 5, 'carbs': 32, 'fat': 9},
  'paneer paratha': {'calories': 280, 'protein': 9, 'carbs': 32, 'fat': 13},
  'makki di roti': {'calories': 190, 'protein': 4, 'carbs': 38, 'fat': 3},
  'naan': {'calories': 260, 'protein': 8, 'carbs': 45, 'fat': 6},
  'butter naan': {'calories': 310, 'protein': 8, 'carbs': 45, 'fat': 11},
  'garlic naan': {'calories': 290, 'protein': 8, 'carbs': 46, 'fat': 9},
  'puri': {'calories': 130, 'protein': 3, 'carbs': 18, 'fat': 6},
  'bhatura': {'calories': 200, 'protein': 4, 'carbs': 28, 'fat': 9},
  'missi roti': {'calories': 90, 'protein': 4, 'carbs': 16, 'fat': 2},
  'tandoori roti': {'calories': 80, 'protein': 3, 'carbs': 17, 'fat': 1},
  'rice': {'calories': 130, 'protein': 3, 'carbs': 28, 'fat': 0},
  'jeera rice': {'calories': 150, 'protein': 3, 'carbs': 30, 'fat': 3},
  'biryani': {'calories': 290, 'protein': 10, 'carbs': 45, 'fat': 9},
  'chicken biryani': {'calories': 320, 'protein': 18, 'carbs': 42, 'fat': 10},
  'mutton biryani': {'calories': 350, 'protein': 20, 'carbs': 40, 'fat': 14},
  'veg biryani': {'calories': 270, 'protein': 7, 'carbs': 48, 'fat': 7},
  'pulao': {'calories': 180, 'protein': 4, 'carbs': 35, 'fat': 4},
  'khichdi': {'calories': 160, 'protein': 6, 'carbs': 28, 'fat': 3},
  'fried rice': {'calories': 210, 'protein': 5, 'carbs': 38, 'fat': 5},
  'paneer butter masala': {'calories': 280, 'protein': 12, 'carbs': 15, 'fat': 20},
  'palak paneer': {'calories': 220, 'protein': 10, 'carbs': 12, 'fat': 15},
  'matar paneer': {'calories': 210, 'protein': 9, 'carbs': 18, 'fat': 12},
  'paneer tikka': {'calories': 250, 'protein': 15, 'carbs': 8, 'fat': 17},
  'paneer bhurji': {'calories': 230, 'protein': 13, 'carbs': 8, 'fat': 16},
  'shahi paneer': {'calories': 310, 'protein': 12, 'carbs': 15, 'fat': 24},
  'kadai paneer': {'calories': 265, 'protein': 11, 'carbs': 14, 'fat': 19},
  'paneer': {'calories': 265, 'protein': 18, 'carbs': 4, 'fat': 20},
  'butter chicken': {'calories': 250, 'protein': 18, 'carbs': 10, 'fat': 16},
  'chicken curry': {'calories': 220, 'protein': 20, 'carbs': 8, 'fat': 13},
  'chicken tikka masala': {'calories': 260, 'protein': 22, 'carbs': 10, 'fat': 16},
  'tandoori chicken': {'calories': 190, 'protein': 25, 'carbs': 4, 'fat': 8},
  'chicken tikka': {'calories': 200, 'protein': 24, 'carbs': 5, 'fat': 9},
  'chicken 65': {'calories': 280, 'protein': 22, 'carbs': 12, 'fat': 16},
  'chicken korma': {'calories': 290, 'protein': 20, 'carbs': 12, 'fat': 19},
  'aloo gobi': {'calories': 130, 'protein': 4, 'carbs': 20, 'fat': 5},
  'aloo sabzi': {'calories': 110, 'protein': 3, 'carbs': 20, 'fat': 4},
  'aloo matar': {'calories': 135, 'protein': 4, 'carbs': 22, 'fat': 5},
  'baingan bharta': {'calories': 100, 'protein': 3, 'carbs': 12, 'fat': 5},
  'bhindi masala': {'calories': 90, 'protein': 3, 'carbs': 10, 'fat': 5},
  'sarson da saag': {'calories': 80, 'protein': 4, 'carbs': 10, 'fat': 3},
  'mixed veg': {'calories': 120, 'protein': 4, 'carbs': 16, 'fat': 5},
  'pav bhaji': {'calories': 280, 'protein': 7, 'carbs': 42, 'fat': 10},
  'idli': {'calories': 58, 'protein': 2, 'carbs': 12, 'fat': 0},
  'dosa': {'calories': 120, 'protein': 3, 'carbs': 22, 'fat': 3},
  'masala dosa': {'calories': 215, 'protein': 5, 'carbs': 35, 'fat': 7},
  'uttapam': {'calories': 175, 'protein': 5, 'carbs': 28, 'fat': 5},
  'upma': {'calories': 150, 'protein': 4, 'carbs': 25, 'fat': 5},
  'vada': {'calories': 180, 'protein': 6, 'carbs': 20, 'fat': 9},
  'poha': {'calories': 180, 'protein': 3, 'carbs': 35, 'fat': 4},
  'aloo poha': {'calories': 210, 'protein': 4, 'carbs': 38, 'fat': 5},
  'sabudana khichdi': {'calories': 220, 'protein': 3, 'carbs': 45, 'fat': 5},
  'besan chilla': {'calories': 150, 'protein': 8, 'carbs': 18, 'fat': 5},
  'samosa': {'calories': 150, 'protein': 3, 'carbs': 20, 'fat': 7},
  'pakora': {'calories': 160, 'protein': 4, 'carbs': 18, 'fat': 8},
  'aloo tikki': {'calories': 140, 'protein': 3, 'carbs': 22, 'fat': 5},
  'pani puri': {'calories': 200, 'protein': 3, 'carbs': 32, 'fat': 6},
  'bhel puri': {'calories': 180, 'protein': 4, 'carbs': 30, 'fat': 5},
  'kachori': {'calories': 190, 'protein': 4, 'carbs': 24, 'fat': 9},
  'lassi': {'calories': 150, 'protein': 6, 'carbs': 20, 'fat': 5},
  'sweet lassi': {'calories': 190, 'protein': 6, 'carbs': 28, 'fat': 5},
  'mango lassi': {'calories': 200, 'protein': 5, 'carbs': 32, 'fat': 5},
  'chai': {'calories': 50, 'protein': 2, 'carbs': 8, 'fat': 1},
  'masala chai': {'calories': 60, 'protein': 2, 'carbs': 9, 'fat': 2},
  'nimbu pani': {'calories': 30, 'protein': 0, 'carbs': 8, 'fat': 0},
  'curd': {'calories': 60, 'protein': 4, 'carbs': 5, 'fat': 3},
  'raita': {'calories': 70, 'protein': 4, 'carbs': 8, 'fat': 2},
  'ghee': {'calories': 112, 'protein': 0, 'carbs': 0, 'fat': 13},
  'gulab jamun': {'calories': 150, 'protein': 2, 'carbs': 28, 'fat': 4},
  'jalebi': {'calories': 150, 'protein': 1, 'carbs': 30, 'fat': 4},
  'halwa': {'calories': 200, 'protein': 3, 'carbs': 30, 'fat': 8},
  'kheer': {'calories': 180, 'protein': 5, 'carbs': 28, 'fat': 6},
  'gajar ka halwa': {'calories': 220, 'protein': 4, 'carbs': 32, 'fat': 9},
  'ladoo': {'calories': 170, 'protein': 3, 'carbs': 24, 'fat': 7},
  'rasgulla': {'calories': 110, 'protein': 3, 'carbs': 22, 'fat': 1},
  'egg': {'calories': 70, 'protein': 6, 'carbs': 0, 'fat': 5},
  'omelette': {'calories': 150, 'protein': 10, 'carbs': 2, 'fat': 11},
  'bread': {'calories': 80, 'protein': 3, 'carbs': 15, 'fat': 1},
  'banana': {'calories': 90, 'protein': 1, 'carbs': 23, 'fat': 0},
  'apple': {'calories': 52, 'protein': 0, 'carbs': 14, 'fat': 0},
  'mango': {'calories': 60, 'protein': 1, 'carbs': 15, 'fat': 0},
};

const Map<String, double> servingSizes = {
  '100g': 1.0,
  '150g': 1.5,
  '200g': 2.0,
  '250g': 2.5,
  '1 katori (150g)': 1.5,
  '1 bowl (250g)': 2.5,
  '1 plate (300g)': 3.0,
  '1 glass (200ml)': 2.0,
  '1 cup (100g)': 1.0,
  '1 piece': 1.0,
  '2 pieces': 2.0,
  'Half plate (150g)': 1.5,
};

// ─── HOME SCREEN ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _todayCalories = 0;
  int _goalCalories = 2000;
  List<FlSpot> _weeklyData = [];

  webpick.WebPickedImage? _webPicked;
  NutritionResult? _result;
  String? _error;
  bool _loading = false;
  bool _logging = false;
  bool _showManualSearch = false;
  String _selectedServing = '1 katori (150g)';

  int _baseCalories = 0;
  int _baseProtein = 0;
  int _baseCarbs = 0;
  int _baseFat = 0;

  late TextEditingController _dishNameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  final TextEditingController _searchController = TextEditingController();
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _dishNameController = TextEditingController();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _dishNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (profile.exists && profile.data()?['calorie_goal'] != null) {
      setState(() => _goalCalories = profile.data()!['calorie_goal']);
    }
    await _loadTodayCalories();
    await _loadWeeklyData();
  }

  Future<void> _loadTodayCalories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));
    final snap = await FirebaseFirestore.instance
        .collection('meals')
        .where('user_id', isEqualTo: uid)
        .where('logged_at', isGreaterThanOrEqualTo: startOfDay)
        .where('logged_at', isLessThanOrEqualTo: endOfDay)
        .get();
    int total = 0;
    for (final doc in snap.docs) {
      total += (doc['calories'] as num).toInt();
    }
    if (mounted) setState(() => _todayCalories = total);
  }

  Future<void> _loadWeeklyData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final List<FlSpot> spots = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final start = Timestamp.fromDate(DateTime(day.year, day.month, day.day));
      final end = Timestamp.fromDate(DateTime(day.year, day.month, day.day, 23, 59, 59));
      final snap = await FirebaseFirestore.instance
          .collection('meals')
          .where('user_id', isEqualTo: uid)
          .where('logged_at', isGreaterThanOrEqualTo: start)
          .where('logged_at', isLessThanOrEqualTo: end)
          .get();
      int total = 0;
      for (final doc in snap.docs) {
        total += (doc['calories'] as num).toInt();
      }
      spots.add(FlSpot((6 - i).toDouble(), total.toDouble()));
    }
    if (mounted) setState(() => _weeklyData = spots);
  }

  void _populateControllers(NutritionResult result) {
   _baseCalories = result.calories.toInt();
_baseProtein = result.protein.toInt();
_baseCarbs = result.carbs.toInt();
_baseFat = result.fat.toInt();
    _dishNameController.text = result.dishName;
    _updateServingCalculation();
  }

  void _updateServingCalculation() {
    final multiplier = servingSizes[_selectedServing] ?? 1.0;
    _caloriesController.text = (_baseCalories * multiplier).round().toString();
    _proteinController.text = (_baseProtein * multiplier).round().toString();
    _carbsController.text = (_baseCarbs * multiplier).round().toString();
    _fatController.text = (_baseFat * multiplier).round().toString();
  }

  Future<void> _logMeal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _logging = true);
    try {
      await FirebaseFirestore.instance.collection('meals').add({
        'user_id': uid,
        'dish_name': _dishNameController.text,
        'calories': int.tryParse(_caloriesController.text) ?? 0,
        'protein': int.tryParse(_proteinController.text) ?? 0,
        'carbs': int.tryParse(_carbsController.text) ?? 0,
        'fat': int.tryParse(_fatController.text) ?? 0,
        'serving': _selectedServing,
        'logged_at': FieldValue.serverTimestamp(),
      });
      await _loadTodayCalories();
      await _loadWeeklyData();
      if (mounted) {
        setState(() {
          _result = null;
          _webPicked = null;
          _showManualSearch = false;
          _selectedServing = '1 katori (150g)';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Meal logged!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  void _searchManualFood() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;
    for (final key in indianFoodDB.keys) {
      if (key == query || key.contains(query) || query.contains(key)) {
        final food = indianFoodDB[key]!;
        final result = NutritionResult(
          dishName: key,
          portionSize: '100g',
          calories: food['calories']!,
          protein: food['protein']!,
          carbs: food['carbs']!,
          fat: food['fat']!,
          confidence: 95,
        );
        setState(() {
          _result = result;
          _searchError = null;
          _showManualSearch = false;
          _searchController.clear();
          _selectedServing = '1 katori (150g)';
        });
        _populateControllers(result);
        return;
      }
    }
    setState(() => _searchError = 'Not found. Try: dal, roti, paratha, biryani...');
  }

  Future<void> _scanFood() async {
    setState(() { _error = null; _result = null; _showManualSearch = false; });
    if (kIsWeb) {
      final webImage = await webpick.pickImageWithHtmlInput();
      if (webImage == null) return;
      setState(() { _webPicked = webImage; _loading = true; });
    }
    try {
      const apiKey = String.fromEnvironment('GROQ_API_KEY');
      final service = GeminiVisionService(apiKey: apiKey);
      final res = await service.analyzeFoodImageBase64(
          base64Image: _webPicked!.base64, mimeType: _webPicked!.mimeType);
      if (mounted) {
        setState(() { _result = res; _selectedServing = '1 katori (150g)'; });
        _populateControllers(res);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not recognize food. Try manual search.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _dayLabel(int index) {
    final now = DateTime.now();
    final day = now.subtract(Duration(days: 6 - index));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_todayCalories / _goalCalories).clamp(0.0, 1.0);
    final remaining = _goalCalories - _todayCalories;
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_greeting()}, $name 👋',
                style: const TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Cal भारत',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Color(0xFFFF7A00))),
            const SizedBox(height: 20),

            // Calorie card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Today's calories",
                          style: TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: remaining > 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          remaining > 0 ? '$remaining left' : '${-remaining} over',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: remaining > 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_todayCalories',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2, color: Colors.black87)),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('/ $_goalCalories kcal',
                            style: const TextStyle(fontSize: 15, color: Colors.black38, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF0F0F0),
                      valueColor: AlwaysStoppedAnimation(
                          progress > 1.0 ? Colors.red : const Color(0xFFFF7A00)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _MacroChip(label: 'Protein', color: Colors.blue.shade400),
                    const SizedBox(width: 8),
                    _MacroChip(label: 'Carbs', color: Colors.amber.shade600),
                    const SizedBox(width: 8),
                    _MacroChip(label: 'Fat', color: Colors.red.shade400),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weekly chart
            if (_weeklyData.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weekly Progress',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Last 7 days',
                            style: TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (_goalCalories * 1.5).toDouble(),
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) => Text(
                                  _dayLabel(value.toInt()),
                                  style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: _weeklyData.map((spot) {
                            final isToday = spot.x == 6;
                            final isOver = spot.y > _goalCalories;
                            return BarChartGroupData(
                              x: spot.x.toInt(),
                              barRods: [
                                BarChartRodData(
                                  toY: spot.y == 0 ? 0.5 : spot.y,
                                  color: isOver
                                      ? Colors.red.shade400
                                      : isToday
                                          ? const Color(0xFFFF7A00)
                                          : const Color(0xFFFF7A00).withValues(alpha: 0.3),
                                  width: 20,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            );
                          }).toList(),
                          // Goal line
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: _goalCalories.toDouble(),
                                color: Colors.black12,
                                strokeWidth: 1,
                                dashArray: [4, 4],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _ActionButton(
                    onTap: _loading ? null : _scanFood,
                    icon: Icons.camera_alt_outlined,
                    label: 'Scan Food',
                    emoji: '📸',
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    onTap: () => setState(() {
                      _showManualSearch = !_showManualSearch;
                      _result = null;
                      _error = null;
                    }),
                    icon: Icons.search,
                    label: 'Search',
                    isPrimary: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Manual search
            if (_showManualSearch) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Search Indian Food',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('${indianFoodDB.length}+ dishes available',
                        style: const TextStyle(color: Colors.black38, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'e.g. dal makhani, biryani, samosa...',
                            hintStyle: const TextStyle(color: Colors.black26),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (_) => _searchManualFood(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _searchManualFood,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search, color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                    if (_searchError != null) ...[
                      const SizedBox(height: 8),
                      Text(_searchError!, style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Loading
            if (_loading) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF7A00))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('Analyzing your food...', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('AI is identifying the dish', style: TextStyle(color: Colors.black38, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Confirmation card
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 14),
                        const SizedBox(width: 4),
                        Text('AI Result — Confirm before logging',
                            style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    const Text('Dish Name',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _dishNameController,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon: const Icon(Icons.edit_outlined, size: 16, color: Colors.black26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Serving Size',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedServing,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedServing = val);
                            _updateServingCalculation();
                          }
                        },
                        items: servingSizes.keys.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      _NutritionField(label: 'Calories', unit: 'kcal', controller: _caloriesController, highlight: true),
                      const SizedBox(width: 8),
                      _NutritionField(label: 'Protein', unit: 'g', controller: _proteinController),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _NutritionField(label: 'Carbs', unit: 'g', controller: _carbsController),
                      const SizedBox(width: 8),
                      _NutritionField(label: 'Fat', unit: 'g', controller: _fatController),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        onPressed: _logging ? null : _logMeal,
                        child: _logging
                            ? const SizedBox(height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('✅ Confirm & Log Meal'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => setState(() { _result = null; _webPicked = null; }),
                        child: const Text('Cancel', style: TextStyle(color: Colors.black38, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.onTap, required this.icon, required this.label, this.emoji, required this.isPrimary});
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final String? emoji;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFFF7A00) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isPrimary ? null : Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.4)),
          boxShadow: isPrimary ? [BoxShadow(color: const Color(0xFFFF7A00).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : const Color(0xFFFF7A00), size: 18),
            const SizedBox(width: 6),
            Text(
              emoji != null ? '$label $emoji' : label,
              style: TextStyle(
                color: isPrimary ? Colors.white : const Color(0xFFFF7A00),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionField extends StatelessWidget {
  const _NutritionField({required this.label, required this.unit, required this.controller, this.highlight = false});
  final String label;
  final String unit;
  final TextEditingController controller;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFF7A00).withValues(alpha: 0.06) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: highlight ? Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.2)) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: highlight ? const Color(0xFFFF7A00) : Colors.black38)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                  color: highlight ? const Color(0xFFFF7A00) : Colors.black87),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, border: InputBorder.none),
            )),
            Text(unit, style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

// ─── LOG SCREEN ───────────────────────────────────────────────────────────────

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Meal Log',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const Text("Today's meals",
              style: TextStyle(color: Colors.black38, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Not logged in'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('meals')
                        .where('user_id', isEqualTo: uid)
                        .where('logged_at', isGreaterThanOrEqualTo: startOfDay)
                        .where('logged_at', isLessThanOrEqualTo: endOfDay)
                        .orderBy('logged_at', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('⚠️', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 8),
                              Text('Error: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.black38, fontSize: 12),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('🍽️', style: TextStyle(fontSize: 56)),
                            SizedBox(height: 12),
                            Text('No meals logged today',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black54)),
                            SizedBox(height: 6),
                            Text('Scan your food to get started',
                                style: TextStyle(color: Colors.black38, fontSize: 13)),
                          ],
                        ));
                      }

                      int totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;
                      for (final doc in docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        totalCal += (d['calories'] as num? ?? 0).toInt();
                        totalProtein += (d['protein'] as num? ?? 0).toInt();
                        totalCarbs += (d['carbs'] as num? ?? 0).toInt();
                        totalFat += (d['fat'] as num? ?? 0).toInt();
                      }

                      return Column(children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Column(children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Total today',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black45, fontSize: 13)),
                              Text('$totalCal kcal',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFFFF7A00))),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              _LogMacro(label: 'Protein', value: '$totalProtein g', color: Colors.blue.shade400),
                              _LogMacro(label: 'Carbs', value: '$totalCarbs g', color: Colors.amber.shade600),
                              _LogMacro(label: 'Fat', value: '$totalFat g', color: Colors.red.shade400),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final data = docs[i].data() as Map<String, dynamic>;
                              final ts = data['logged_at'] as Timestamp?;
                              final time = ts != null ? TimeOfDay.fromDateTime(ts.toDate()).format(context) : '';
                              final serving = data['serving'] as String? ?? '';
                              return Dismissible(
                                key: Key(docs[i].id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade400,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.delete_outline, color: Colors.white),
                                ),
                                onDismissed: (_) async {
                                  await FirebaseFirestore.instance.collection('meals').doc(docs[i].id).delete();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF7A00).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.restaurant_outlined, color: Color(0xFFFF7A00), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(data['dish_name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(
                                        serving.isNotEmpty ? '$time • $serving' : time,
                                        style: const TextStyle(color: Colors.black38, fontSize: 12),
                                      ),
                                    ])),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('${data['calories']}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFFFF7A00))),
                                      const Text('kcal', style: TextStyle(color: Colors.black38, fontSize: 11)),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ]);
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

class _LogMacro extends StatelessWidget {
  const _LogMacro({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        Text(label, style: const TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─── PROFILE SCREEN ───────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _calorieGoal = 2000;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data()?['calorie_goal'] != null) {
      setState(() => _calorieGoal = doc.data()!['calorie_goal']);
    }
    setState(() => _loading = false);
  }

  Future<void> _updateGoal(int goal) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'calorie_goal': goal},
      SetOptions(merge: true),
    );
    setState(() => _calorieGoal = goal);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ Goal updated!'),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showGoalPicker() {
    final goals = [1200, 1500, 1800, 2000, 2200, 2500, 3000];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Set Daily Calorie Goal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: goals.map((g) => GestureDetector(
              onTap: () { Navigator.pop(context); _updateGoal(g); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _calorieGoal == g ? const Color(0xFFFF7A00) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$g kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _calorieGoal == g ? Colors.white : Colors.black54,
                    )),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Profile',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFFFF7A00), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Account',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(email,
                    style: const TextStyle(color: Colors.black38, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: _showGoalPicker,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_fire_department_outlined, color: Color(0xFFFF7A00), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Daily Calorie Goal',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text('$_calorieGoal kcal per day',
                      style: const TextStyle(color: Colors.black38, fontSize: 13)),
                ])),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              _ProfileRow(icon: Icons.info_outline, label: 'App Version', value: 'V2.0'),
              const Divider(height: 20, color: Color(0xFFF0F0F0)),
              _ProfileRow(icon: Icons.restaurant_menu_outlined, label: 'Indian dishes in database', value: '${indianFoodDB.length}+'),
              const Divider(height: 20, color: Color(0xFFF0F0F0)),
              _ProfileRow(icon: Icons.star_outline, label: 'Powered by', value: 'Groq AI'),
            ]),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF7A00), width: 1.5),
                foregroundColor: const Color(0xFFFF7A00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.black38),
      const SizedBox(width: 10),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    ]);
  }
}
