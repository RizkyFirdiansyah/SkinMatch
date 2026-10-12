// SkinMatch Domain Models
// Dart representation dari TypeScript schema di PRD Section 4

// ── Skin Profile ──────────────────────────────────────────────────────────────

enum BiologicalSkinType {
  normal('NORMAL', 'Normal', 'Sebum Seimbang, hidrasi optimum 70–85%'),
  dry('DRY', 'Kering', 'Defisit lipid, rentan bersisik & kencang'),
  combination('COMBINATION', 'Kombinasi', 'Berminyak di dahi/hidung/dagu, pipi kering'),
  oily('OILY', 'Berminyak', 'Hiper-sebum, kilap dalam 2 jam, pori besar'),
  sensitive('SENSITIVE', 'Sensitif', 'Epidermis tipis, mudah memerah & perih');

  const BiologicalSkinType(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
}

enum AgeRange {
  range18to24('18-24'),
  range25to34('25-34'),
  range35to44('35-44'),
  range45plus('45+');

  const AgeRange(this.label);
  final String label;
}

enum BiologicalSex {
  female('FEMALE', 'Wanita'),
  male('MALE', 'Pria');

  const BiologicalSex(this.code, this.label);
  final String code;
  final String label;
}

class SkinCondition {
  const SkinCondition({required this.id, required this.name, required this.label});
  final String id;
  final String name;
  final String label;

  static const List<SkinCondition> predefined = [
    SkinCondition(id: 'barrier_damaged', name: 'barrier_damaged', label: 'Barrier Rusak'),
    SkinCondition(id: 'acne_prone', name: 'acne_prone', label: 'Rentan Jerawat'),
    SkinCondition(id: 'eczema', name: 'eczema', label: 'Eksim'),
    SkinCondition(id: 'rosacea', name: 'rosacea', label: 'Rosacea'),
    SkinCondition(id: 'hyperpigmentation', name: 'hyperpigmentation', label: 'Hiperpigmentasi'),
    SkinCondition(id: 'rough_texture', name: 'rough_texture', label: 'Tekstur Kasar'),
  ];
}

class AllergenTrigger {
  const AllergenTrigger({
    required this.id,
    required this.name,
    required this.keywords,
    required this.severity,
  });
  final String id;
  final String name;
  final List<String> keywords;
  final String severity; // 'HIGH' | 'MEDIUM'
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.ageRange,
    required this.biologicalSex,
    required this.skinType,
    this.conditions = const [],
    this.blacklistedIngredients = const [],
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final AgeRange ageRange;
  final BiologicalSex biologicalSex;
  final BiologicalSkinType skinType;
  final List<String> conditions;
  final List<String> blacklistedIngredients;
  final String? avatarUrl;

  UserProfile copyWith({
    String? userId,
    String? fullName,
    AgeRange? ageRange,
    BiologicalSex? biologicalSex,
    BiologicalSkinType? skinType,
    List<String>? conditions,
    List<String>? blacklistedIngredients,
    String? avatarUrl,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      ageRange: ageRange ?? this.ageRange,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      skinType: skinType ?? this.skinType,
      conditions: conditions ?? this.conditions,
      blacklistedIngredients: blacklistedIngredients ?? this.blacklistedIngredients,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

// ── Ingredient ────────────────────────────────────────────────────────────────

enum IngredientSafetyCategory {
  hero('HERO'),
  safeCarrier('SAFE_CARRIER'),
  warning('WARNING'),
  irritant('IRRITANT');

  const IngredientSafetyCategory(this.code);
  final String code;
}

class IngredientItem {
  const IngredientItem({
    required this.id,
    required this.inciName,
    required this.cleanName,
    required this.category,
    required this.comedogenicRating,
    required this.irritancyRating,
    required this.functionDescription,
    this.concentration,
    this.warningNote,
  });

  final String id;
  final String inciName;
  final String cleanName;
  final String? concentration;
  final IngredientSafetyCategory category;
  final int comedogenicRating; // 0–5
  final int irritancyRating;  // 0–3
  final String functionDescription;
  final String? warningNote;
}

// ── Scan Result ───────────────────────────────────────────────────────────────

enum SafetyStatus {
  lowRisk('LOW_RISK', 'Aman Digunakan'),
  moderateRisk('MODERATE_RISK', 'Perlu Uji Patch'),
  highRisk('HIGH_RISK', 'Tidak Disarankan');

  const SafetyStatus(this.code, this.label);
  final String code;
  final String label;
}

enum AllergyPotential { veryLow, low, medium, high }

class ScanAnalysisResult {
  const ScanAnalysisResult({
    required this.scanId,
    required this.userId,
    required this.timestamp,
    required this.brand,
    required this.productName,
    required this.matchScore,
    required this.safetyStatus,
    required this.allergyPotential,
    required this.comedogenicScale,
    required this.formulaPh,
    required this.ingredients,
    required this.routineRecommendation,
    this.volume,
    this.imageUrl,
    this.keyWarning,
  });

  final String scanId;
  final String userId;
  final String timestamp;
  final String brand;
  final String productName;
  final String? volume;
  final String? imageUrl;
  final int matchScore; // 0–100
  final SafetyStatus safetyStatus;
  final AllergyPotential allergyPotential;
  final String comedogenicScale;
  final String formulaPh;
  final String? keyWarning;
  final String routineRecommendation;
  final List<IngredientItem> ingredients;

  /// PRD Business Rule: derive SafetyStatus from matchScore
  static SafetyStatus statusFromScore(int score) {
    if (score >= 80) return SafetyStatus.lowRisk;
    if (score >= 60) return SafetyStatus.moderateRisk;
    return SafetyStatus.highRisk;
  }
}

// ── History & Review ──────────────────────────────────────────────────────────

enum TrialStatus {
  unreviewed('UNREVIEWED'),
  testingPatch('TESTING_PATCH'),
  completedSuccess('COMPLETED_SUCCESS'),
  triggeredBreakout('TRIGGERED_BREAKOUT');

  const TrialStatus(this.code);
  final String code;
}

class PatchTestProgress {
  const PatchTestProgress({
    required this.currentDay,
    required this.targetDays,
    this.notes = const [],
  });
  final int currentDay;
  final int targetDays;
  final List<String> notes;
}

class ProductReview {
  const ProductReview({
    required this.rating,
    required this.userNotes,
    required this.confirmedMatch,
    required this.reviewedAt,
  });
  final double rating; // 1.0–5.0
  final String userNotes;
  final bool confirmedMatch;
  final String reviewedAt;
}

class ProductHistoryItem {
  const ProductHistoryItem({
    required this.historyId,
    required this.scanResult,
    required this.trialStatus,
    required this.aiFeedbackApplied,
    this.patchTest,
    this.review,
  });

  final String historyId;
  final ScanAnalysisResult scanResult;
  final TrialStatus trialStatus;
  final PatchTestProgress? patchTest;
  final ProductReview? review;
  final bool aiFeedbackApplied;

  ProductHistoryItem copyWith({
    TrialStatus? trialStatus,
    PatchTestProgress? patchTest,
    ProductReview? review,
    bool? aiFeedbackApplied,
  }) {
    return ProductHistoryItem(
      historyId: historyId,
      scanResult: scanResult,
      trialStatus: trialStatus ?? this.trialStatus,
      patchTest: patchTest ?? this.patchTest,
      review: review ?? this.review,
      aiFeedbackApplied: aiFeedbackApplied ?? this.aiFeedbackApplied,
    );
  }
}
