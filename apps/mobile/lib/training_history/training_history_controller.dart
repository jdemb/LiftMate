import 'package:flutter/foundation.dart';

import 'training_history_api_client.dart';
import 'training_history_models.dart';

enum TrainingHistoryStatus { idle, loading, loaded, error }

class TrainingHistoryState {
  const TrainingHistoryState({
    this.status = TrainingHistoryStatus.idle,
    this.items = const [],
    this.nextCursor,
    this.message,
    this.paginationError,
    this.isLoadingMore = false,
    this.isLoadingNested = false,
    this.detail,
    this.progress,
  });

  final TrainingHistoryStatus status;
  final List<TrainingHistorySessionSummary> items;
  final String? nextCursor;
  final String? message;
  final String? paginationError;
  final bool isLoadingMore;
  final bool isLoadingNested;
  final TrainingHistorySession? detail;
  final ExerciseProgress? progress;

  TrainingHistoryState copyWith({
    TrainingHistoryStatus? status,
    List<TrainingHistorySessionSummary>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    String? message,
    bool clearMessage = false,
    String? paginationError,
    bool clearPaginationError = false,
    bool? isLoadingMore,
    bool? isLoadingNested,
    TrainingHistorySession? detail,
    bool clearDetail = false,
    ExerciseProgress? progress,
    bool clearProgress = false,
  }) {
    return TrainingHistoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      message: clearMessage ? null : message ?? this.message,
      paginationError: clearPaginationError
          ? null
          : paginationError ?? this.paginationError,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isLoadingNested: isLoadingNested ?? this.isLoadingNested,
      detail: clearDetail ? null : detail ?? this.detail,
      progress: clearProgress ? null : progress ?? this.progress,
    );
  }
}

class TrainingHistoryController extends ChangeNotifier {
  TrainingHistoryController({
    required this.apiClient,
    required this.accessTokenProvider,
    this.traineeUserId,
  });

  final TrainingHistoryApiClient apiClient;
  final String? Function() accessTokenProvider;
  final String? traineeUserId;

  TrainingHistoryState _state = const TrainingHistoryState();
  TrainingHistoryState get state => _state;

  Future<void> loadInitial() async {
    _setState(
      const TrainingHistoryState(status: TrainingHistoryStatus.loading),
    );
    final token = accessTokenProvider();
    if (token == null) {
      _setState(
        const TrainingHistoryState(
          status: TrainingHistoryStatus.error,
          message: 'User is not authenticated.',
        ),
      );
      return;
    }
    final result = await apiClient.list(
      accessToken: token,
      traineeUserId: traineeUserId,
    );
    if (!result.isSuccess || result.data == null) {
      _setState(
        TrainingHistoryState(
          status: TrainingHistoryStatus.error,
          message: result.message,
        ),
      );
      return;
    }
    _setState(
      TrainingHistoryState(
        status: TrainingHistoryStatus.loaded,
        items: result.data!.items,
        nextCursor: result.data!.nextCursor,
      ),
    );
  }

  Future<void> loadMore() async {
    final cursor = _state.nextCursor;
    if (_state.isLoadingMore || cursor == null) return;
    _setState(_state.copyWith(isLoadingMore: true, clearPaginationError: true));
    final token = accessTokenProvider();
    if (token == null) {
      _setState(
        _state.copyWith(
          isLoadingMore: false,
          paginationError: 'User is not authenticated.',
        ),
      );
      return;
    }
    final result = await apiClient.list(
      accessToken: token,
      traineeUserId: traineeUserId,
      cursor: cursor,
    );
    if (!result.isSuccess || result.data == null) {
      _setState(
        _state.copyWith(isLoadingMore: false, paginationError: result.message),
      );
      return;
    }
    final ids = _state.items.map((item) => item.id).toSet();
    final appended = result.data!.items.where((item) => ids.add(item.id));
    _setState(
      _state.copyWith(
        items: [..._state.items, ...appended],
        nextCursor: result.data!.nextCursor,
        clearNextCursor: result.data!.nextCursor == null,
        isLoadingMore: false,
        clearPaginationError: true,
      ),
    );
  }

  Future<void> retry() {
    return _state.items.isEmpty ? loadInitial() : loadMore();
  }

  Future<void> openSession(String sessionId) async {
    final token = accessTokenProvider();
    if (token == null) return;
    _setState(_state.copyWith(isLoadingNested: true, clearMessage: true));
    final result = await apiClient.detail(
      accessToken: token,
      sessionId: sessionId,
    );
    if (!result.isSuccess || result.data == null) {
      _setState(
        _state.copyWith(isLoadingNested: false, message: result.message),
      );
      return;
    }
    _setState(
      _state.copyWith(
        isLoadingNested: false,
        detail: result.data,
        clearProgress: true,
      ),
    );
  }

  Future<void> openProgress(String exerciseId) async {
    final token = accessTokenProvider();
    if (token == null) return;
    _setState(_state.copyWith(isLoadingNested: true, clearMessage: true));
    final result = await apiClient.progress(
      accessToken: token,
      exerciseId: exerciseId,
      traineeUserId: traineeUserId,
    );
    if (!result.isSuccess || result.data == null) {
      _setState(
        _state.copyWith(isLoadingNested: false, message: result.message),
      );
      return;
    }
    _setState(_state.copyWith(isLoadingNested: false, progress: result.data));
  }

  void backFromProgress() {
    _setState(_state.copyWith(clearProgress: true, clearMessage: true));
  }

  void backFromDetail() {
    _setState(
      _state.copyWith(
        clearDetail: true,
        clearProgress: true,
        clearMessage: true,
      ),
    );
  }

  void _setState(TrainingHistoryState value) {
    _state = value;
    notifyListeners();
  }
}
