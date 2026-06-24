class PostWorkoutFeedbackRequest {
  const PostWorkoutFeedbackRequest({
    required this.wellbeingRating,
    this.comment,
  });

  final int wellbeingRating;
  final String? comment;

  Map<String, Object?> toJson() {
    if (wellbeingRating < 1 || wellbeingRating > 5) {
      throw const FormatException('Wellbeing rating must be between 1 and 5.');
    }

    final normalizedComment = comment?.trim();
    if (normalizedComment != null && normalizedComment.length > 1000) {
      throw const FormatException('Feedback comment is too long.');
    }

    return {
      'wellbeingRating': wellbeingRating,
      'comment': normalizedComment == null || normalizedComment.isEmpty
          ? null
          : normalizedComment,
    };
  }
}

class PostWorkoutFeedbackResponse {
  const PostWorkoutFeedbackResponse({
    required this.sharedSessionId,
    required this.wellbeingRating,
    required this.comment,
    required this.submittedAt,
  });

  final String sharedSessionId;
  final int wellbeingRating;
  final String? comment;
  final DateTime submittedAt;

  factory PostWorkoutFeedbackResponse.fromJson(Map<String, dynamic> json) {
    final sharedSessionId = json['sharedSessionId'];
    final wellbeingRating = json['wellbeingRating'];
    final comment = json['comment'];
    final submittedAt = json['submittedAt'];

    if (sharedSessionId is! String ||
        wellbeingRating is! int ||
        wellbeingRating < 1 ||
        wellbeingRating > 5 ||
        (comment != null && comment is! String) ||
        submittedAt is! String) {
      throw const FormatException('Invalid post-workout feedback response.');
    }

    return PostWorkoutFeedbackResponse(
      sharedSessionId: sharedSessionId,
      wellbeingRating: wellbeingRating,
      comment: comment,
      submittedAt: DateTime.parse(submittedAt).toUtc(),
    );
  }
}
