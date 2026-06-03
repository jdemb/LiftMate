import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import 'shared_session_api_client.dart';
import 'shared_session_models.dart';
import 'shared_session_realtime_client.dart';

class SharedSessionDiagnosticPanel extends StatefulWidget {
  const SharedSessionDiagnosticPanel({
    required this.authController,
    required this.user,
    required this.sharedSessionApiClient,
    required this.realtimeClientFactory,
    super.key,
  });

  final AuthController authController;
  final AuthUser user;
  final SharedSessionApiClient sharedSessionApiClient;
  final SharedSessionRealtimeClientFactory realtimeClientFactory;

  @override
  State<SharedSessionDiagnosticPanel> createState() => _SharedSessionDiagnosticPanelState();
}

class _SharedSessionDiagnosticPanelState extends State<SharedSessionDiagnosticPanel> {
  final _sessionIdController = TextEditingController();
  final _traineeUserIdController = TextEditingController();
  final _repsController = TextEditingController(text: '8');
  final _weightController = TextEditingController(text: '42.5');
  late final SharedSessionRealtimeClient _realtimeClient;
  StreamSubscription<SharedSession>? _updatesSubscription;
  StreamSubscription<SharedSessionConnectionStatus>? _statusSubscription;

  SharedSession? _session;
  SharedSessionConnectionStatus _connectionStatus =
      SharedSessionConnectionStatus.disconnected;
  String? _message;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _realtimeClient = widget.realtimeClientFactory();
    _updatesSubscription = _realtimeClient.updates.listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
          _sessionIdController.text = session.id;
          _message = 'Session update received.';
        });
      }
    });
    _statusSubscription = _realtimeClient.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    });
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    _statusSubscription?.cancel();
    _realtimeClient.disconnect();
    _sessionIdController.dispose();
    _traineeUserIdController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _createDemoSession() async {
    final accessToken = _accessToken;
    final traineeUserId = _traineeUserIdController.text.trim();
    if (accessToken == null || traineeUserId.isEmpty) {
      _setMessage('Access token and trainee user ID are required.');
      return;
    }

    await _run(() async {
      final result = await widget.sharedSessionApiClient.create(
        accessToken: accessToken,
        traineeUserId: traineeUserId,
        values: const [
          CreateSharedSessionValue(
            exerciseName: 'Bench press',
            exerciseType: ExerciseValueType.repsWeight,
            setIndex: 1,
            reps: 6,
            weight: 40,
          ),
        ],
      );
      await _applyResult(result, connect: true);
    });
  }

  Future<void> _joinSession() async {
    final accessToken = _accessToken;
    final sessionId = _sessionIdController.text.trim();
    if (accessToken == null || sessionId.isEmpty) {
      _setMessage('Access token and session ID are required.');
      return;
    }

    await _run(() async {
      final result = await widget.sharedSessionApiClient.get(
        accessToken: accessToken,
        sessionId: sessionId,
      );
      await _applyResult(result, connect: true);
    });
  }

  Future<void> _updateFirstValue() async {
    final accessToken = _accessToken;
    final session = _session;
    final value = session?.values.isEmpty ?? true ? null : session!.values.first;
    if (accessToken == null || session == null || value == null) {
      _setMessage('Join or create a session before updating values.');
      return;
    }

    final reps = int.tryParse(_repsController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (reps == null || weight == null) {
      _setMessage('Reps and weight must be valid numbers.');
      return;
    }

    await _run(() async {
      final result = await widget.sharedSessionApiClient.updateValue(
        accessToken: accessToken,
        sessionId: session.id,
        valueId: value.id,
        value: UpdateSharedSessionValue(reps: reps, weight: weight),
      );
      await _applyResult(result);
    });
  }

  Future<void> _completeSession() async {
    await _closeSession((accessToken, sessionId) {
      return widget.sharedSessionApiClient.complete(
        accessToken: accessToken,
        sessionId: sessionId,
      );
    });
  }

  Future<void> _cancelSession() async {
    await _closeSession((accessToken, sessionId) {
      return widget.sharedSessionApiClient.cancel(
        accessToken: accessToken,
        sessionId: sessionId,
      );
    });
  }

  Future<void> _closeSession(
    Future<SharedSessionApiResult<SharedSession>> Function(
      String accessToken,
      String sessionId,
    ) action,
  ) async {
    final accessToken = _accessToken;
    final session = _session;
    if (accessToken == null || session == null) {
      _setMessage('Join or create a session first.');
      return;
    }

    await _run(() async {
      final result = await action(accessToken, session.id);
      await _applyResult(result);
    });
  }

  Future<void> _applyResult(
    SharedSessionApiResult<SharedSession> result, {
    bool connect = false,
  }) async {
    final session = result.data;
    if (!result.isSuccess || session == null) {
      _setMessage(result.message);
      return;
    }

    setState(() {
      _session = session;
      _sessionIdController.text = session.id;
      _message = result.message;
    });

    if (connect) {
      final accessToken = _accessToken;
      if (accessToken != null) {
        await _realtimeClient.connect(
          accessToken: accessToken,
          sessionId: session.id,
        );
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _message = null;
    });

    try {
      await action();
    } on Object catch (error) {
      _setMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _setMessage(String message) {
    if (mounted) {
      setState(() {
        _message = message;
      });
    }
  }

  String? get _accessToken => widget.authController.tokens?.accessToken;

  bool get _canEdit => !_isBusy && _session?.status == SharedSessionStatus.active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Shared session diagnostics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText('Current user: ${widget.user.id} (${widget.user.role.wireName})'),
            Text('Realtime: ${_connectionStatus.name}'),
            const SizedBox(height: 12),
            TextField(
              controller: _sessionIdController,
              decoration: const InputDecoration(labelText: 'Session ID'),
              enabled: !_isBusy,
            ),
            if (widget.user.role == UserRole.trainer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _traineeUserIdController,
                decoration: const InputDecoration(labelText: 'Trainee user ID'),
                enabled: !_isBusy,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isBusy ? null : _createDemoSession,
                child: const Text('Create demo session'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isBusy ? null : _joinSession,
              child: const Text('Join session'),
            ),
            if (session != null) ...[
              const SizedBox(height: 16),
              Text('Status: ${session.status.wireName}'),
              Text('Version: ${session.version}'),
              const SizedBox(height: 8),
              for (final value in session.values) _SessionValueRow(value: value),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _repsController,
                      decoration: const InputDecoration(labelText: 'Reps'),
                      keyboardType: TextInputType.number,
                      enabled: _canEdit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      decoration: const InputDecoration(labelText: 'Weight'),
                      keyboardType: TextInputType.number,
                      enabled: _canEdit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _canEdit ? _updateFirstValue : null,
                child: const Text('Update first value'),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canEdit ? _completeSession : null,
                      child: const Text('Complete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canEdit ? _cancelSession : null,
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionValueRow extends StatelessWidget {
  const _SessionValueRow({required this.value});

  final SharedSessionValue value;

  @override
  Widget build(BuildContext context) {
    final parts = [
      value.exerciseName,
      value.exerciseType.wireName,
      'set ${value.setIndex}',
      if (value.reps != null) '${value.reps} reps',
      if (value.weight != null) '${value.weight} kg',
      if (value.seconds != null) '${value.seconds} sec',
    ];

    return Text(parts.join(' | '));
  }
}
