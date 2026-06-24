import 'package:flutter/foundation.dart';

import 'post_workout_feedback_api_client.dart';
import 'post_workout_feedback_models.dart';

enum PostWorkoutFeedbackStatus { idle, submitting, submitted, error }

class PostWorkoutFeedbackState {
  const PostWorkoutFeedbackState({
    required this.sessionId,
    this.status = PostWorkoutFeedbackStatus.idle,
    this.wellbeingRating,
    this.comment = '',
    this.message,
    this.response,
  });

  final String sessionId;
  final PostWorkoutFeedbackStatus status;
  final int? wellbeingRating;
  final String comment;
  final String? message;
  final PostWorkoutFeedbackResponse? response;

  PostWorkoutFeedbackState copyWith({
    PostWorkoutFeedbackStatus? status,
    int? wellbeingRating,
    String? comment,
    String? message,
    bool clearMessage = false,
    PostWorkoutFeedbackResponse? response,
  }) {
    return PostWorkoutFeedbackState(
      sessionId: sessionId,
      status: status ?? this.status,
      wellbeingRating: wellbeingRating ?? this.wellbeingRating,
      comment: comment ?? this.comment,
      message: clearMessage ? null : message ?? this.message,
      response: response ?? this.response,
    );
  }
}

class PostWorkoutFeedbackController extends ChangeNotifier {
  PostWorkoutFeedbackController({
    required String sessionId,
    required this.apiClient,
    required this.accessTokenProvider,
    this.onSaved,
  }) : _state = PostWorkoutFeedbackState(sessionId: sessionId);

  final PostWorkoutFeedbackApiClient apiClient;
  final String? Function() accessTokenProvider;
  final Future<void> Function(String sessionId)? onSaved;

  PostWorkoutFeedbackState _state;
  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>>? _inFlight;

  PostWorkoutFeedbackState get state => _state;

  void setRating(int value) {
    _setState(
      _state.copyWith(
        wellbeingRating: value,
        status: PostWorkoutFeedbackStatus.idle,
        clearMessage: true,
      ),
    );
  }

  void setComment(String value) {
    _setState(
      _state.copyWith(
        comment: value,
        status: PostWorkoutFeedbackStatus.idle,
        clearMessage: true,
      ),
    );
  }

  Future<PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>>
  submit() async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final rating = _state.wellbeingRating;
    if (rating == null) {
      const result = PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>(
        status: PostWorkoutFeedbackApiStatus.badRequest,
        message: 'Wybierz ocenę przed wysłaniem feedbacku.',
      );
      _setState(
        _state.copyWith(
          status: PostWorkoutFeedbackStatus.error,
          message: result.message,
        ),
      );
      return result;
    }

    final accessToken = accessTokenProvider();
    if (accessToken == null) {
      const result = PostWorkoutFeedbackApiResult<PostWorkoutFeedbackResponse>(
        status: PostWorkoutFeedbackApiStatus.unauthorized,
        message: 'User is not authenticated.',
      );
      _setState(
        _state.copyWith(
          status: PostWorkoutFeedbackStatus.error,
          message: result.message,
        ),
      );
      return result;
    }

    _setState(
      _state.copyWith(
        status: PostWorkoutFeedbackStatus.submitting,
        clearMessage: true,
      ),
    );

    final future = apiClient.submit(
      accessToken: accessToken,
      sessionId: _state.sessionId,
      request: PostWorkoutFeedbackRequest(
        wellbeingRating: rating,
        comment: _state.comment,
      ),
    );
    _inFlight = future;

    final result = await future;
    _inFlight = null;

    if (!result.isSuccess || result.data == null) {
      _setState(
        _state.copyWith(
          status: PostWorkoutFeedbackStatus.error,
          message: result.message,
        ),
      );
      return result;
    }

    _setState(
      _state.copyWith(
        status: PostWorkoutFeedbackStatus.submitted,
        response: result.data,
        clearMessage: true,
      ),
    );
    await onSaved?.call(_state.sessionId);
    return result;
  }

  void _setState(PostWorkoutFeedbackState value) {
    _state = value;
    notifyListeners();
  }
}
