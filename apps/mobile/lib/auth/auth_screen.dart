import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_models.dart';

enum _AuthStep {
  welcome,
  role,
  login,
  signup,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.authController,
    super.key,
  });

  final AuthController authController;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  final _trainerCodeController = TextEditingController();

  _AuthStep _step = _AuthStep.welcome;
  UserRole _selectedRole = UserRole.trainer;
  UserRole? _pendingPairRole;
  String? _trainerInviteCode;
  String? _pairingError;
  bool _isPairing = false;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_onAuthChanged);
    widget.authController.initialize();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAuthChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _invitationCodeController.dispose();
    _trainerCodeController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    _pendingPairRole = null;
    await widget.authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _signup() async {
    if (!_signupFormKey.currentState!.validate()) {
      return;
    }

    final role = _selectedRole;
    final result = await widget.authController.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: role,
      displayName: _displayNameController.text.trim(),
      invitationCode: _invitationCodeController.text.trim(),
    );

    if (result.isSuccess) {
      setState(() {
        _pendingPairRole = role;
        _pairingError = null;
        _trainerInviteCode = null;
        _trainerCodeController.clear();
      });
    }
  }

  Future<void> _generateTrainerCode() async {
    setState(() {
      _isPairing = true;
      _pairingError = null;
    });

    final result = await widget.authController.generateTrainerInviteCode();
    if (!mounted) {
      return;
    }

    setState(() {
      _isPairing = false;
      if (result.isSuccess && result.data != null) {
        _trainerInviteCode = result.data!.code;
      } else {
        _pairingError = result.message;
      }
    });
  }

  Future<void> _claimTrainerCode() async {
    final code = _trainerCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _pairingError = 'Wpisz kod trenera.';
      });
      return;
    }

    setState(() {
      _isPairing = true;
      _pairingError = null;
    });

    final result = await widget.authController.claimTrainerInviteCode(code: code);
    if (!mounted) {
      return;
    }

    setState(() {
      _isPairing = false;
      if (result.isSuccess) {
        _pendingPairRole = null;
      } else {
        _pairingError = result.message;
      }
    });
  }

  Future<void> _finishTrainerPairing() async {
    setState(() {
      _pendingPairRole = null;
    });
  }

  Future<void> _logout() async {
    _resetOnboarding();
    await widget.authController.logout();
  }

  void _resetOnboarding() {
    setState(() {
      _step = _AuthStep.welcome;
      _pendingPairRole = null;
      _trainerInviteCode = null;
      _pairingError = null;
      _isPairing = false;
      _trainerCodeController.clear();
    });
  }

  void _selectRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _pairingError = null;
    });
  }

  void _continueToSignup() {
    setState(() {
      _step = _AuthStep.signup;
      _pairingError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.authController.state;
    final user = state.user;
    final isLoading = state.status == AuthControllerStatus.loading;
    final errorMessage =
        state.status == AuthControllerStatus.error ? state.message : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(),
                  const SizedBox(height: 28),
                  if (user != null && _pendingPairRole != null)
                    _PairingPanel(
                      role: _pendingPairRole!,
                      trainerInviteCode: _trainerInviteCode,
                      trainerCodeController: _trainerCodeController,
                      isLoading: _isPairing,
                      errorMessage: _pairingError,
                      onGenerateTrainerCode: _generateTrainerCode,
                      onClaimTrainerCode: _claimTrainerCode,
                      onContinue: _finishTrainerPairing,
                    )
                  else if (state.status == AuthControllerStatus.authenticated &&
                      user != null)
                    _AuthenticatedPanel(
                      user: user,
                      onLogout: _logout,
                    )
                  else
                    _OnboardingPanel(
                      step: _step,
                      selectedRole: _selectedRole,
                      isLoading: isLoading,
                      errorMessage: errorMessage,
                      loginFormKey: _loginFormKey,
                      signupFormKey: _signupFormKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      displayNameController: _displayNameController,
                      invitationCodeController: _invitationCodeController,
                      onShowLogin: () => setState(() => _step = _AuthStep.login),
                      onShowRoleSelection: () =>
                          setState(() => _step = _AuthStep.role),
                      onBack: () => setState(() => _step = _AuthStep.welcome),
                      onRoleSelected: _selectRole,
                      onContinueRole: _continueToSignup,
                      onLogin: _login,
                      onSignup: _signup,
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.fitness_center, color: Colors.white),
        ),
        const SizedBox(height: 18),
        Text('LiftMate', style: theme.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Trening prowadzony blisko celu, bez zgadywania.',
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    required this.step,
    required this.selectedRole,
    required this.isLoading,
    required this.loginFormKey,
    required this.signupFormKey,
    required this.emailController,
    required this.passwordController,
    required this.displayNameController,
    required this.invitationCodeController,
    required this.onShowLogin,
    required this.onShowRoleSelection,
    required this.onBack,
    required this.onRoleSelected,
    required this.onContinueRole,
    required this.onLogin,
    required this.onSignup,
    this.errorMessage,
  });

  final _AuthStep step;
  final UserRole selectedRole;
  final bool isLoading;
  final GlobalKey<FormState> loginFormKey;
  final GlobalKey<FormState> signupFormKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController displayNameController;
  final TextEditingController invitationCodeController;
  final VoidCallback onShowLogin;
  final VoidCallback onShowRoleSelection;
  final VoidCallback onBack;
  final ValueChanged<UserRole> onRoleSelected;
  final VoidCallback onContinueRole;
  final Future<void> Function() onLogin;
  final Future<void> Function() onSignup;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      _AuthStep.welcome => _WelcomeStep(
          isLoading: isLoading,
          onCreateAccount: onShowRoleSelection,
          onLogin: onShowLogin,
        ),
      _AuthStep.role => _RoleStep(
          selectedRole: selectedRole,
          onBack: onBack,
          onRoleSelected: onRoleSelected,
          onContinue: onContinueRole,
        ),
      _AuthStep.login => _LoginForm(
          formKey: loginFormKey,
          isLoading: isLoading,
          emailController: emailController,
          passwordController: passwordController,
          errorMessage: errorMessage,
          onBack: onBack,
          onLogin: onLogin,
        ),
      _AuthStep.signup => _SignupForm(
          formKey: signupFormKey,
          role: selectedRole,
          isLoading: isLoading,
          emailController: emailController,
          passwordController: passwordController,
          displayNameController: displayNameController,
          invitationCodeController: invitationCodeController,
          errorMessage: errorMessage,
          onBack: onBack,
          onSignup: onSignup,
        ),
    };
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({
    required this.isLoading,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final bool isLoading;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isLoading ? null : onCreateAccount,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Załóż konto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isLoading ? null : onLogin,
          icon: const Icon(Icons.login),
          label: const Text('Mam już konto'),
        ),
      ],
    );
  }
}

class _RoleStep extends StatelessWidget {
  const _RoleStep({
    required this.selectedRole,
    required this.onBack,
    required this.onRoleSelected,
    required this.onContinue,
  });

  final UserRole selectedRole;
  final VoidCallback onBack;
  final ValueChanged<UserRole> onRoleSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Wybierz rolę', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(
              value: UserRole.trainer,
              icon: Icon(Icons.sports),
              label: Text('Trener'),
            ),
            ButtonSegment(
              value: UserRole.trainee,
              icon: Icon(Icons.accessibility_new),
              label: Text('Podopieczny'),
            ),
          ],
          selected: {selectedRole},
          onSelectionChanged: (selection) => onRoleSelected(selection.single),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Dalej'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Wróć'),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.onBack,
    required this.onLogin,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onBack;
  final Future<void> Function() onLogin;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Logowanie', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          _EmailField(controller: emailController),
          const SizedBox(height: 12),
          _PasswordField(controller: passwordController),
          _ErrorText(message: errorMessage),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isLoading ? null : onLogin,
            icon: const Icon(Icons.login),
            label: const Text('Zaloguj'),
          ),
          TextButton.icon(
            onPressed: isLoading ? null : onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Wróć'),
          ),
        ],
      ),
    );
  }
}

class _SignupForm extends StatelessWidget {
  const _SignupForm({
    required this.formKey,
    required this.role,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.displayNameController,
    required this.invitationCodeController,
    required this.onBack,
    required this.onSignup,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final UserRole role;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController displayNameController;
  final TextEditingController invitationCodeController;
  final VoidCallback onBack;
  final Future<void> Function() onSignup;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = role == UserRole.trainer ? 'Trener' : 'Podopieczny';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nowe konto', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Rola: $roleLabel', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextFormField(
            controller: displayNameController,
            decoration: const InputDecoration(
              labelText: 'Imię i nazwisko',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          _EmailField(controller: emailController),
          const SizedBox(height: 12),
          _PasswordField(controller: passwordController),
          const SizedBox(height: 12),
          TextFormField(
            controller: invitationCodeController,
            decoration: const InputDecoration(
              labelText: 'Kod rejestracji',
              prefixIcon: Icon(Icons.key),
            ),
            textInputAction: TextInputAction.done,
            validator: _requiredValidator,
          ),
          _ErrorText(message: errorMessage),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: isLoading ? null : onSignup,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Kontynuuj'),
          ),
          TextButton.icon(
            onPressed: isLoading ? null : onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Wróć'),
          ),
        ],
      ),
    );
  }
}

class _PairingPanel extends StatelessWidget {
  const _PairingPanel({
    required this.role,
    required this.trainerCodeController,
    required this.isLoading,
    required this.onGenerateTrainerCode,
    required this.onClaimTrainerCode,
    required this.onContinue,
    this.trainerInviteCode,
    this.errorMessage,
  });

  final UserRole role;
  final TextEditingController trainerCodeController;
  final bool isLoading;
  final Future<void> Function() onGenerateTrainerCode;
  final Future<void> Function() onClaimTrainerCode;
  final Future<void> Function() onContinue;
  final String? trainerInviteCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTrainer = role == UserRole.trainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isTrainer ? 'Kod dla podopiecznego' : 'Połącz z trenerem',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (isTrainer)
          _TrainerPairingContent(
            code: trainerInviteCode,
            isLoading: isLoading,
            onGenerateTrainerCode: onGenerateTrainerCode,
            onContinue: onContinue,
          )
        else
          _TraineePairingContent(
            controller: trainerCodeController,
            isLoading: isLoading,
            onClaimTrainerCode: onClaimTrainerCode,
          ),
        _ErrorText(message: errorMessage),
      ],
    );
  }
}

class _TrainerPairingContent extends StatelessWidget {
  const _TrainerPairingContent({
    required this.isLoading,
    required this.onGenerateTrainerCode,
    required this.onContinue,
    this.code,
  });

  final bool isLoading;
  final Future<void> Function() onGenerateTrainerCode;
  final Future<void> Function() onContinue;
  final String? code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (code != null) ...[
          SelectableText(
            code!,
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isLoading ? null : onContinue,
            icon: const Icon(Icons.check),
            label: const Text('Przejdź dalej'),
          ),
        ] else
          FilledButton.icon(
            onPressed: isLoading ? null : onGenerateTrainerCode,
            icon: const Icon(Icons.ios_share),
            label: const Text('Wygeneruj kod'),
          ),
      ],
    );
  }
}

class _TraineePairingContent extends StatelessWidget {
  const _TraineePairingContent({
    required this.controller,
    required this.isLoading,
    required this.onClaimTrainerCode,
  });

  final TextEditingController controller;
  final bool isLoading;
  final Future<void> Function() onClaimTrainerCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Kod trenera',
            prefixIcon: Icon(Icons.qr_code_2),
          ),
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isLoading ? null : onClaimTrainerCode,
          icon: const Icon(Icons.link),
          label: const Text('Połącz konto'),
        ),
      ],
    );
  }
}

class _AuthenticatedPanel extends StatelessWidget {
  const _AuthenticatedPanel({
    required this.user,
    required this.onLogout,
  });

  final AuthUser user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = user.role == UserRole.trainer ? 'Trener' : 'Podopieczny';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Witaj, ${user.displayName}', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(user.email),
        Text('Rola: $roleLabel'),
        if (user.trainerUserId != null) Text('Trener: ${user.trainerUserId}'),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Wyloguj'),
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'E-mail',
        prefixIcon: Icon(Icons.mail_outline),
      ),
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: _requiredValidator,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Hasło',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      obscureText: true,
      textInputAction: TextInputAction.done,
      validator: _requiredValidator,
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({
    required this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'To pole jest wymagane.';
  }

  return null;
}
