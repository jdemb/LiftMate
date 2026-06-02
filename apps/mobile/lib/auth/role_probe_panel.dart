import 'package:flutter/material.dart';

import 'auth_api_client.dart';
import 'auth_controller.dart';
import 'auth_models.dart';

class RoleProbePanel extends StatefulWidget {
  const RoleProbePanel({
    required this.authApiClient,
    required this.authController,
    required this.user,
    super.key,
  });

  final AuthApiClient authApiClient;
  final AuthController authController;
  final AuthUser user;

  @override
  State<RoleProbePanel> createState() => _RoleProbePanelState();
}

class _RoleProbePanelState extends State<RoleProbePanel> {
  AuthApiResult<RoleProbeResult>? _result;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkProbe();
  }

  @override
  void didUpdateWidget(RoleProbePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.user.role != widget.user.role) {
      _checkProbe();
    }
  }

  Future<void> _checkProbe() async {
    final accessToken = widget.authController.tokens?.accessToken;
    if (accessToken == null) {
      setState(() {
        _isChecking = false;
        _result = const AuthApiResult<RoleProbeResult>(
          status: AuthApiStatus.unauthorized,
          message: 'Missing access token.',
        );
      });
      return;
    }

    setState(() {
      _isChecking = true;
    });

    final result = switch (widget.user.role) {
      UserRole.trainer => await widget.authApiClient.trainerProbe(accessToken: accessToken),
      UserRole.trainee => await widget.authApiClient.traineeProbe(accessToken: accessToken),
    };

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = _roleLabel(widget.user.role);

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
            Text('Role probe', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_isChecking)
              const LinearProgressIndicator()
            else if (_result?.isSuccess == true)
              Text('$roleLabel probe passed')
            else
              Text(_result?.message ?? 'Role probe failed.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isChecking ? null : _checkProbe,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry probe'),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.trainer => 'Trainer',
      UserRole.trainee => 'Trainee',
    };
  }
}
