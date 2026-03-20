class NutritionResult {
  const NutritionResult({
    required this.dishName,
    required this.portionSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.confidence,
  });

  final String dishName;
  final String portionSize;
  final num calories;
  final num protein;
  final num carbs;
  final num fat;
  final num confidence;

  factory NutritionResult.fromJson(Map<String, dynamic> json) {
    num asNum(dynamic v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim()) ?? 0;
      return 0;
    }

    String asString(dynamic v) => (v is String) ? v : (v?.toString() ?? '');

    return NutritionResult(
      dishName: asString(json['dish_name']),
      portionSize: asString(json['portion_size']),
      calories: asNum(json['calories']),
      protein: asNum(json['protein']),
      carbs: asNum(json['carbs']),
      fat: asNum(json['fat']),
      confidence: asNum(json['confidence']),
    );
  }
}

