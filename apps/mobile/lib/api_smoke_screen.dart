import 'package:flutter/material.dart';

import 'api_health_client.dart';

typedef ApiHealthCheck = Future<ApiHealthResult> Function();

class ApiSmokeScreen extends StatefulWidget {
  const ApiSmokeScreen({
    required this.healthUri,
    required this.checkHealth,
    super.key,
  });

  final Uri? healthUri;
  final ApiHealthCheck checkHealth;

  @override
  State<ApiSmokeScreen> createState() => _ApiSmokeScreenState();
}

class _ApiSmokeScreenState extends State<ApiSmokeScreen> {
  ApiHealthResult? _result;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _isChecking = true;
    });

    final result = await widget.checkHealth();
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
    final status = _statusDisplay();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LiftMate'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(status.icon, size: 56, color: status.color),
                  const SizedBox(height: 16),
                  Text(
                    status.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_isChecking)
                    const Center(child: CircularProgressIndicator())
                  else
                    Text(
                      _result?.message ?? 'No health check result.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Endpoint',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    widget.healthUri?.toString() ?? 'API_BASE_URL not configured',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isChecking ? null : _check,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _StatusDisplay _statusDisplay() {
    if (_isChecking) {
      return const _StatusDisplay(
        title: 'Checking API',
        icon: Icons.sync,
        color: Colors.blue,
      );
    }

    return switch (_result?.status) {
      ApiHealthStatus.online => const _StatusDisplay(
          title: 'API online',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
      ApiHealthStatus.offline => const _StatusDisplay(
          title: 'API offline',
          icon: Icons.error,
          color: Colors.orange,
        ),
      ApiHealthStatus.error || null => const _StatusDisplay(
          title: 'API error',
          icon: Icons.warning,
          color: Colors.red,
        ),
    };
  }
}

class _StatusDisplay {
  const _StatusDisplay({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}
