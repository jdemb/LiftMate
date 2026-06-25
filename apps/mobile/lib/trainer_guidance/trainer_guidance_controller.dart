import 'package:flutter/foundation.dart';

import 'trainer_guidance_api_client.dart';
import 'trainer_guidance_models.dart';

enum TrainerGuidanceStatus { idle, loading, loaded, error }

class TrainerGuidanceState {
  const TrainerGuidanceState({
    this.status = TrainerGuidanceStatus.idle,
    this.items = const [],
    this.message,
    this.markingReadId,
  });

  final TrainerGuidanceStatus status;
  final List<TrainerGuidance> items;
  final String? message;
  final String? markingReadId;

  TrainerGuidanceState copyWith({
    TrainerGuidanceStatus? status,
    List<TrainerGuidance>? items,
    String? message,
    bool clearMessage = false,
    String? markingReadId,
    bool clearMarkingReadId = false,
  }) {
    return TrainerGuidanceState(
      status: status ?? this.status,
      items: items ?? this.items,
      message: clearMessage ? null : message ?? this.message,
      markingReadId: clearMarkingReadId
          ? null
          : markingReadId ?? this.markingReadId,
    );
  }
}

class TrainerGuidanceController extends ChangeNotifier {
  TrainerGuidanceController({
    required this.apiClient,
    required this.accessTokenProvider,
    required this.traineeUserId,
  }) : _seeded = false;

  TrainerGuidanceController.seeded({
    required this.traineeUserId,
    TrainerGuidanceStatus status = TrainerGuidanceStatus.loaded,
    List<TrainerGuidance> items = const [],
    String? message,
  }) : apiClient = TrainerGuidanceApiClient(),
       accessTokenProvider = (() => null),
       _seeded = true,
       _state = TrainerGuidanceState(
         status: status,
         items: items,
         message: message,
       );

  final TrainerGuidanceApiClient apiClient;
  final String? Function() accessTokenProvider;
  final String traineeUserId;
  final bool _seeded;

  TrainerGuidanceState _state = const TrainerGuidanceState();
  TrainerGuidanceState get state => _state;

  Future<void> load() async {
    if (_seeded) {
      return;
    }

    _setState(
      const TrainerGuidanceState(status: TrainerGuidanceStatus.loading),
    );
    final token = accessTokenProvider();
    if (token == null) {
      _setState(
        const TrainerGuidanceState(
          status: TrainerGuidanceStatus.error,
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
        TrainerGuidanceState(
          status: TrainerGuidanceStatus.error,
          message: result.message,
        ),
      );
      return;
    }

    _setState(
      TrainerGuidanceState(
        status: TrainerGuidanceStatus.loaded,
        items: result.data!.items,
      ),
    );
  }

  Future<void> markAsRead(String guidanceId) async {
    if (_state.markingReadId != null) {
      return;
    }

    if (_seeded) {
      _removeLocal(guidanceId);
      return;
    }

    final token = accessTokenProvider();
    if (token == null) {
      _setState(_state.copyWith(message: 'User is not authenticated.'));
      return;
    }

    _setState(_state.copyWith(markingReadId: guidanceId, clearMessage: true));
    final result = await apiClient.markAsRead(
      accessToken: token,
      guidanceId: guidanceId,
    );
    if (!result.isSuccess) {
      _setState(
        _state.copyWith(message: result.message, clearMarkingReadId: true),
      );
      return;
    }

    _removeLocal(guidanceId);
  }

  void _removeLocal(String guidanceId) {
    _setState(
      _state.copyWith(
        status: TrainerGuidanceStatus.loaded,
        items: _state.items
            .where((item) => item.id != guidanceId)
            .toList(growable: false),
        clearMessage: true,
        clearMarkingReadId: true,
      ),
    );
  }

  void _setState(TrainerGuidanceState value) {
    _state = value;
    notifyListeners();
  }
}
