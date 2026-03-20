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
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: saffron,
          brightness: Brightness.light,
        ).copyWith(primary: saffron, surface: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
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
        backgroundColor: Colors.white,
        elevation: 0,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Indian food manual search database
const Map<String, Map<String, int>> indianFoodDB = {
  'dal makhani': {'calories': 130, 'protein': 6, 'carbs': 14, 'fat': 7},
  'rajma': {'calories': 125, 'protein': 8, 'carbs': 20, 'fat': 2},
  'roti': {'calories': 70, 'protein': 3, 'carbs': 15, 'fat': 1},
  'paratha': {'calories': 200, 'protein': 4, 'carbs': 30, 'fat': 8},
  'aloo paratha': {'calories': 250, 'protein': 5, 'carbs': 35, 'fat': 10},
  'rice': {'calories': 130, 'protein': 3, 'carbs': 28, 'fat': 0},
  'dal tadka': {'calories': 110, 'protein': 7, 'carbs': 15, 'fat': 4},
  'paneer butter masala': {'calories': 280, 'protein': 12, 'carbs': 15, 'fat': 20},
  'chole': {'calories': 160, 'protein': 9, 'carbs': 25, 'fat': 4},
  'biryani': {'calories': 290, 'protein': 10, 'carbs': 45, 'fat': 9},
  'samosa': {'calories': 150, 'protein': 3, 'carbs': 20, 'fat': 7},
  'idli': {'calories': 58, 'protein': 2, 'carbs': 12, 'fat': 0},
  'dosa': {'calories': 120, 'protein': 3, 'carbs': 22, 'fat': 3},
  'upma': {'calories': 150, 'protein': 4, 'carbs': 25, 'fat': 5},
  'poha': {'calories': 180, 'protein': 3, 'carbs': 35, 'fat': 4},
  'khichdi': {'calories': 160, 'protein': 6, 'carbs': 28, 'fat': 3},
  'lassi': {'calories': 150, 'protein': 6, 'carbs': 20, 'fat': 5},
  'chai': {'calories': 50, 'protein': 2, 'carbs': 8, 'fat': 1},
  'makki di roti': {'calories': 190, 'protein': 4, 'carbs': 38, 'fat': 3},
  'sarson da saag': {'calories': 80, 'protein': 4, 'carbs': 10, 'fat': 3},
  'butter chicken': {'calories': 250, 'protein': 18, 'carbs': 10, 'fat': 16},
  'palak paneer': {'calories': 220, 'protein': 10, 'carbs': 12, 'fat': 15},
  'aloo gobi': {'calories': 130, 'protein': 4, 'carbs': 20, 'fat': 5},
  'matar paneer': {'calories': 210, 'protein': 9, 'carbs': 18, 'fat': 12},
  'naan': {'calories': 260, 'protein': 8, 'carbs': 45, 'fat': 6},
  'puri': {'calories': 130, 'protein': 3, 'carbs': 18, 'fat': 6},
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int goalCalories = 2000;
  int _todayCalories = 0;

  webpick.WebPickedImage? _webPicked;
  NutritionResult? _result;
  String? _error;
  bool _loading = false;
  bool _logging = false;
  bool _showManualSearch = false;

  // Confirmation edit controllers
  late TextEditingController _dishNameController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  // Manual search
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
    _loadTodayCalories();
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

  void _populateControllers(NutritionResult result) {
    _dishNameController.text = result.dishName;
    _caloriesController.text = result.calories.toString();
    _proteinController.text = result.protein.toString();
    _carbsController.text = result.carbs.toString();
    _fatController.text = result.fat.toString();
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
        'logged_at': FieldValue.serverTimestamp(),
      });
      await _loadTodayCalories();
      if (mounted) {
        setState(() {
          _result = null;
          _webPicked = null;
          _showManualSearch = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meal logged! ✅'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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

  void _searchManualFood() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    // Try exact match first
    if (indianFoodDB.containsKey(query)) {
      final food = indianFoodDB[query]!;
      final result = NutritionResult(
        dishName: _searchController.text.trim(),
        portionSize: '1 serving (100g)',
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
      });
      _populateControllers(result);
      return;
    }

    // Try partial match
    for (final key in indianFoodDB.keys) {
      if (key.contains(query) || query.contains(key)) {
        final food = indianFoodDB[key]!;
        final result = NutritionResult(
          dishName: key,
          portionSize: '1 serving (100g)',
          calories: food['calories']!,
          protein: food['protein']!,
          carbs: food['carbs']!,
          fat: food['fat']!,
          confidence: 80,
        );
        setState(() {
          _result = result;
          _searchError = null;
          _showManualSearch = false;
          _searchController.clear();
        });
        _populateControllers(result);
        return;
      }
    }

    setState(() => _searchError = 'Food not found. Try: dal, roti, paratha, biryani, paneer...');
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
        base64Image: _webPicked!.base64,
        mimeType: _webPicked!.mimeType,
      );
      if (mounted) {
        setState(() => _result = res);
        _populateControllers(res);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = (_todayCalories / goalCalories).clamp(0.0, 1.0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cal भारत',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: const Color(0xFFFF7A00))),
                    Text('Track your Indian meals',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black45, fontWeight: FontWeight.w500)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Today',
                      style: TextStyle(
                          color: const Color(0xFFFF7A00),
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calorie card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFF9500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's Calories",
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_todayCalories',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('/ $goalCalories kcal',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${goalCalories - _todayCalories > 0 ? goalCalories - _todayCalories : 0} kcal remaining',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan + Manual search buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _loading ? null : _scanFood,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Scan Food 📸',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _showManualSearch = !_showManualSearch;
                      _result = null;
                      _error = null;
                    }),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFF7A00), width: 1.5),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, color: Color(0xFFFF7A00), size: 20),
                          Text('Search',
                              style: TextStyle(
                                  color: Color(0xFFFF7A00),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
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
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Search Indian Food',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'e.g. dal makhani, paratha...',
                              filled: true,
                              fillColor: const Color(0xFFF7F7F7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
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
                      ],
                    ),
                    if (_searchError != null) ...[
                      const SizedBox(height: 8),
                      Text(_searchError!,
                          style: TextStyle(color: Colors.red.shade600, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Photo preview
            if (_webPicked != null && _result == null && !_loading) ...[
              _Card(
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_webPicked!.dataUrl,
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Photo selected',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(_webPicked!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black45, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Loading
            if (_loading) ...[
              _Card(
                child: Row(children: [
                  SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('AI is analyzing your food...',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Error
            if (_error != null) ...[
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('❌ Could not recognize food',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text('Try searching manually using the Search button above.',
                        style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // CONFIRMATION CARD — most important V2 feature
            if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(children: [
                            Icon(Icons.check_circle, color: Colors.green.shade600, size: 14),
                            const SizedBox(width: 4),
                            Text('AI Result — Please confirm',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Dish name editable
                    const Text('Dish Name',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black45)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _dishNameController,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        suffixIcon: const Icon(Icons.edit, size: 16, color: Colors.black38),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nutrition fields
                    Row(children: [
                      _EditableNutrition(label: 'Calories', unit: 'kcal', controller: _caloriesController, highlight: true),
                      const SizedBox(width: 8),
                      _EditableNutrition(label: 'Protein', unit: 'g', controller: _proteinController),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _EditableNutrition(label: 'Carbs', unit: 'g', controller: _carbsController),
                      const SizedBox(width: 8),
                      _EditableNutrition(label: 'Fat', unit: 'g', controller: _fatController),
                    ]),
                    const SizedBox(height: 16),

                    // Log button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        onPressed: _logging ? null : _logMeal,
                        child: _logging
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('✅ Confirm & Log Meal'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => setState(() { _result = null; _webPicked = null; }),
                        child: const Text('❌ Cancel', style: TextStyle(color: Colors.black45)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditableNutrition extends StatelessWidget {
  const _EditableNutrition({
    required this.label,
    required this.unit,
    required this.controller,
    this.highlight = false,
  });
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
          color: highlight
              ? const Color(0xFFFF7A00).withValues(alpha: 0.08)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: highlight ? const Color(0xFFFF7A00) : Colors.black45)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: highlight ? const Color(0xFFFF7A00) : Colors.black87),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Text(unit,
                    style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Meal Log',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const Text('Today\'s meals',
              style: TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Not logged in'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('meals')
                        .where('user_id', isEqualTo: uid)
                        .where('logged_at', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
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
                              const Text('🍽️', style: TextStyle(fontSize: 56)),
                              const SizedBox(height: 12),
                              const Text('No meals logged today',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black54)),
                              const SizedBox(height: 8),
                              const Text('Scan your food to get started',
                                  style: TextStyle(color: Colors.black38, fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      // Calculate total
                      int totalCal = 0;
                      for (final doc in docs) {
                        totalCal += ((doc.data() as Map)['calories'] as num).toInt();
                      }

                      return Column(
                        children: [
                          // Total bar
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7A00), Color(0xFFFF9500)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total today',
                                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                Text('$totalCal kcal',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final data = docs[i].data() as Map<String, dynamic>;
                                final ts = data['logged_at'] as Timestamp?;
                                final time = ts != null
                                    ? TimeOfDay.fromDateTime(ts.toDate()).format(context)
                                    : '';
                                return Dismissible(
                                  key: Key(docs[i].id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.delete_outline, color: Colors.white),
                                  ),
                                  onDismissed: (_) async {
                                    await FirebaseFirestore.instance
                                        .collection('meals')
                                        .doc(docs[i].id)
                                        .delete();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.restaurant, color: Color(0xFFFF7A00), size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['dish_name'] ?? '',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                            const SizedBox(height: 2),
                                            Text(time,
                                                style: const TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${data['calories']}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                  color: Color(0xFFFF7A00))),
                                          const Text('kcal',
                                              style: TextStyle(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ]),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
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
    final email = (user?.email ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Profile',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 16),

          // Profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A00), Color(0xFFFF9500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome back! 👋',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(email,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Stats card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Goal',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('2000 kcal per day',
                    style: TextStyle(color: Colors.black45, fontSize: 13)),
              ],
            ),
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black12),
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

