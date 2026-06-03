import 'package:flutter/material.dart';

import '../api_health_client.dart';
import '../api_smoke_screen.dart';
import '../shared_sessions/shared_session_api_client.dart';
import '../shared_sessions/shared_session_diagnostic_panel.dart';
import '../shared_sessions/shared_session_realtime_client.dart';
import 'auth_api_client.dart';
import 'auth_controller.dart';
import 'auth_models.dart';
import 'role_probe_panel.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.authController,
    required this.authApiClient,
    required this.sharedSessionApiClient,
    required this.sharedSessionRealtimeClientFactory,
    required this.healthUri,
    required this.checkHealth,
    super.key,
  });

  final AuthController authController;
  final AuthApiClient authApiClient;
  final SharedSessionApiClient sharedSessionApiClient;
  final SharedSessionRealtimeClientFactory sharedSessionRealtimeClientFactory;
  final Uri? healthUri;
  final ApiHealthCheck checkHealth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _invitationCodeController = TextEditingController();

  bool _isRegistering = false;
  UserRole _selectedRole = UserRole.trainer;
  ApiHealthResult? _healthResult;
  bool _isCheckingHealth = true;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    widget.authController.initialize();
    _checkHealth();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isCheckingHealth = true;
    });

    final result = await widget.checkHealth();
    if (!mounted) {
      return;
    }

    setState(() {
      _healthResult = result;
      _isCheckingHealth = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isRegistering) {
      await widget.authController.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        invitationCode: _invitationCodeController.text.trim(),
      );
      return;
    }

    await widget.authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.authController.state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LiftMate'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.status == AuthControllerStatus.authenticated &&
                      state.user != null)
                    _AuthenticatedPanel(
                      authController: widget.authController,
                      authApiClient: widget.authApiClient,
                      sharedSessionApiClient: widget.sharedSessionApiClient,
                      sharedSessionRealtimeClientFactory:
                          widget.sharedSessionRealtimeClientFactory,
                      user: state.user!,
                    )
                  else
                    _AuthForm(
                      formKey: _formKey,
                      isRegistering: _isRegistering,
                      isLoading: state.status == AuthControllerStatus.loading,
                      selectedRole: _selectedRole,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      invitationCodeController: _invitationCodeController,
                      errorMessage:
                          state.status == AuthControllerStatus.error ? state.message : null,
                      onRoleChanged: (role) {
                        setState(() {
                          _selectedRole = role;
                        });
                      },
                      onSubmit: _submit,
                      onModeChanged: () {
                        setState(() {
                          _isRegistering = !_isRegistering;
                        });
                      },
                    ),
                  const SizedBox(height: 20),
                  _HealthDiagnostics(
                    healthUri: widget.healthUri,
                    result: _healthResult,
                    isChecking: _isCheckingHealth,
                    onRetry: _checkHealth,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.isRegistering,
    required this.isLoading,
    required this.selectedRole,
    required this.emailController,
    required this.passwordController,
    required this.invitationCodeController,
    required this.onRoleChanged,
    required this.onSubmit,
    required this.onModeChanged,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final bool isRegistering;
  final bool isLoading;
  final UserRole selectedRole;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController invitationCodeController;
  final ValueChanged<UserRole> onRoleChanged;
  final Future<void> Function() onSubmit;
  final VoidCallback onModeChanged;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isRegistering ? 'Create account' : 'Sign in';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            textInputAction:
                isRegistering ? TextInputAction.next : TextInputAction.done,
            validator: _requiredValidator,
          ),
          if (isRegistering) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: invitationCodeController,
              decoration: const InputDecoration(labelText: 'Invitation code'),
              textInputAction: TextInputAction.done,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 16),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.trainer,
                  label: Text('Trainer'),
                ),
                ButtonSegment(
                  value: UserRole.trainee,
                  label: Text('Trainee'),
                ),
              ],
              selected: {selectedRole},
              onSelectionChanged: isLoading
                  ? null
                  : (selection) => onRoleChanged(selection.single),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: isLoading ? null : onSubmit,
            child: Text(title),
          ),
          TextButton(
            onPressed: isLoading ? null : onModeChanged,
            child: Text(isRegistering ? 'Sign in' : 'Create account'),
          ),
        ],
      ),
    );
  }

  static String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }
}

class _AuthenticatedPanel extends StatelessWidget {
  const _AuthenticatedPanel({
    required this.authController,
    required this.authApiClient,
    required this.sharedSessionApiClient,
    required this.sharedSessionRealtimeClientFactory,
    required this.user,
  });

  final AuthController authController;
  final AuthApiClient authApiClient;
  final SharedSessionApiClient sharedSessionApiClient;
  final SharedSessionRealtimeClientFactory sharedSessionRealtimeClientFactory;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Signed in', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(user.email),
        Text(user.role.wireName),
        const SizedBox(height: 16),
        RoleProbePanel(
          authApiClient: authApiClient,
          authController: authController,
          user: user,
        ),
        const SizedBox(height: 16),
        SharedSessionDiagnosticPanel(
          authController: authController,
          user: user,
          sharedSessionApiClient: sharedSessionApiClient,
          realtimeClientFactory: sharedSessionRealtimeClientFactory,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: authController.logout,
          child: const Text('Logout'),
        ),
      ],
    );
  }
}

class _HealthDiagnostics extends StatelessWidget {
  const _HealthDiagnostics({
    required this.healthUri,
    required this.result,
    required this.isChecking,
    required this.onRetry,
  });

  final Uri? healthUri;
  final ApiHealthResult? result;
  final bool isChecking;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            Text('API diagnostics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              isChecking ? 'Checking API' : result?.message ?? 'No health check result.',
            ),
            const SizedBox(height: 8),
            SelectableText(
              healthUri?.toString() ?? 'API_BASE_URL not configured',
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isChecking ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry health'),
            ),
          ],
        ),
      ),
    );
  }
}
