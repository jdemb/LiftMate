enum TrainerGuidanceType {
  weightStagnation,
  lowWellbeing,
  unknown;

  static TrainerGuidanceType parse(String? value) {
    return switch (value) {
      'weight_stagnation' => TrainerGuidanceType.weightStagnation,
      'low_wellbeing' => TrainerGuidanceType.lowWellbeing,
      _ => TrainerGuidanceType.unknown,
    };
  }
}

class TrainerGuidanceList {
  const TrainerGuidanceList(this.items);

  final List<TrainerGuidance> items;

  factory TrainerGuidanceList.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Missing guidance items.');
    }

    return TrainerGuidanceList(
      items
          .whereType<Map<String, dynamic>>()
          .map(TrainerGuidance.fromJson)
          .toList(growable: false),
    );
  }
}

class TrainerGuidance {
  const TrainerGuidance({
    required this.id,
    required this.type,
    required this.traineeUserId,
    required this.message,
    required this.weightEvidence,
    required this.wellbeingEvidence,
    required this.createdAt,
    this.exerciseId,
    this.exerciseName,
    this.averageRating,
  });

  final String id;
  final TrainerGuidanceType type;
  final String traineeUserId;
  final String? exerciseId;
  final String? exerciseName;
  final String message;
  final List<WeightGuidanceEvidence> weightEvidence;
  final List<WellbeingGuidanceEvidence> wellbeingEvidence;
  final double? averageRating;
  final DateTime createdAt;

  factory TrainerGuidance.fromJson(Map<String, dynamic> json) {
    final evidence = json['evidence'] is Map<String, dynamic>
        ? json['evidence'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final sessions = evidence['sessions'] is List
        ? evidence['sessions'] as List
        : const <dynamic>[];
    final type = TrainerGuidanceType.parse(json['type'] as String?);

    return TrainerGuidance(
      id: _requiredString(json, 'id'),
      type: type,
      traineeUserId: _requiredString(json, 'traineeUserId'),
      exerciseId: json['exerciseId'] as String?,
      exerciseName: json['exerciseName'] as String?,
      message: _requiredString(json, 'message'),
      weightEvidence: type == TrainerGuidanceType.weightStagnation
          ? sessions
                .whereType<Map<String, dynamic>>()
                .map(WeightGuidanceEvidence.fromJson)
                .toList(growable: false)
          : const [],
      wellbeingEvidence: type == TrainerGuidanceType.lowWellbeing
          ? sessions
                .whereType<Map<String, dynamic>>()
                .map(WellbeingGuidanceEvidence.fromJson)
                .toList(growable: false)
          : const [],
      averageRating: _optionalDouble(evidence['averageRating']),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')),
    );
  }
}

class WeightGuidanceEvidence {
  const WeightGuidanceEvidence({
    required this.sessionId,
    required this.maxWeight,
    this.closedAt,
  });

  final String sessionId;
  final DateTime? closedAt;
  final double maxWeight;

  factory WeightGuidanceEvidence.fromJson(Map<String, dynamic> json) {
    return WeightGuidanceEvidence(
      sessionId: _requiredString(json, 'sessionId'),
      closedAt: _optionalDate(json['closedAt']),
      maxWeight: _requiredDouble(json, 'maxWeight'),
    );
  }
}

class WellbeingGuidanceEvidence {
  const WellbeingGuidanceEvidence({
    required this.sessionId,
    required this.rating,
    this.closedAt,
  });

  final String sessionId;
  final DateTime? closedAt;
  final int rating;

  factory WellbeingGuidanceEvidence.fromJson(Map<String, dynamic> json) {
    return WellbeingGuidanceEvidence(
      sessionId: _requiredString(json, 'sessionId'),
      closedAt: _optionalDate(json['closedAt']),
      rating: _requiredInt(json, 'rating'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing string field: $key.');
}

double _requiredDouble(Map<String, dynamic> json, String key) {
  final value = _optionalDouble(json[key]);
  if (value != null) return value;
  throw FormatException('Missing number field: $key.');
}

double? _optionalDouble(Object? value) {
  return switch (value) {
    int number => number.toDouble(),
    double number => number,
    _ => null,
  };
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Missing integer field: $key.');
}

DateTime? _optionalDate(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
