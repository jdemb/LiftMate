import 'package:flutter/material.dart';

import '../relationships/authenticated_relationship_shell.dart';
import '../relationships/relationship_api_client.dart';
import '../workout_sets/workout_set_api_client.dart';
import 'auth_controller.dart';
import 'auth_models.dart';

const _lmBg = Color(0xFF101216);
const _lmPanel = Color(0xFF191C22);
const _lmBlue = Color(0xFF3A82F6);
const _lmBlueDark = Color(0xFF2F6FD6);
const _lmText = Color(0xFFF3F4F6);
const _lmMuted = Color(0xFF969BA3);
const _lmDim = Color(0xFF686D75);
const _lmSuccess = Color(0xFF21C97A);

enum _AuthStep {
  welcome,
  role,
  login,
  signup,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.authController,
    required this.relationshipApiClient,
    required this.workoutSetApiClient,
    super.key,
  });

  final AuthController authController;
  final RelationshipApiClient relationshipApiClient;
  final WorkoutSetApiClient workoutSetApiClient;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _trainerCodeController = TextEditingController();

  _AuthStep _step = _AuthStep.welcome;
  UserRole _selectedRole = UserRole.trainee;
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

  Future<void> _register() async {
    if (!_signupFormKey.currentState!.validate()) {
      return;
    }

    final role = _selectedRole;
    final result = await widget.authController.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: role,
      displayName: _displayNameController.text.trim(),
    );

    if (result.isSuccess) {
      setState(() {
        _pendingPairRole = role;
        _pairingError = null;
        _trainerInviteCode = null;
        _trainerCodeController.clear();
      });

      if (role == UserRole.trainer) {
        await _generateTrainerCode();
      }
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

  Future<void> _finishPairing() async {
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

  void _backToWelcome() {
    setState(() {
      _step = _AuthStep.welcome;
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
    final isAuthenticated =
        state.status == AuthControllerStatus.authenticated && user != null;

    if (isAuthenticated && _pendingPairRole == null) {
      return Scaffold(
        body: ColoredBox(
          color: _lmBg,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AuthenticatedRelationshipShell(
                  user: user,
                  authController: widget.authController,
                  relationshipApiClient: widget.relationshipApiClient,
                  workoutSetApiClient: widget.workoutSetApiClient,
                  onLogout: _logout,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: _GradientScaffold(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null && _pendingPairRole != null)
                    _PairingPanel(
                      role: _pendingPairRole!,
                      trainerInviteCode: _trainerInviteCode,
                      trainerCodeController: _trainerCodeController,
                      isLoading: _isPairing,
                      errorMessage: _pairingError,
                      onRetryTrainerCode: _generateTrainerCode,
                      onClaimTrainerCode: _claimTrainerCode,
                      onContinue: _finishPairing,
                      onTrainerCodeChanged: () => setState(() {}),
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
                      onShowLogin: () => setState(() => _step = _AuthStep.login),
                      onShowRoleSelection: () => setState(() => _step = _AuthStep.role),
                      onBack: _backToWelcome,
                      onRoleSelected: _selectRole,
                      onContinueRole: _continueToSignup,
                      onLogin: _login,
                      onRegister: _register,
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

class _GradientScaffold extends StatelessWidget {
  const _GradientScaffold({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.55, -0.92),
          radius: 0.92,
          colors: [
            Color(0x383A82F6),
            _lmBg,
          ],
          stops: [0, 0.72],
        ),
      ),
      child: SafeArea(child: child),
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
    required this.onShowLogin,
    required this.onShowRoleSelection,
    required this.onBack,
    required this.onRoleSelected,
    required this.onContinueRole,
    required this.onLogin,
    required this.onRegister,
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
  final VoidCallback onShowLogin;
  final VoidCallback onShowRoleSelection;
  final VoidCallback onBack;
  final ValueChanged<UserRole> onRoleSelected;
  final VoidCallback onContinueRole;
  final Future<void> Function() onLogin;
  final Future<void> Function() onRegister;
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
          errorMessage: errorMessage,
          onBack: onBack,
          onRegister: onRegister,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 620),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _LiftMateLogo(size: 60),
              SizedBox(width: 15),
              Text(
                'LiftMate',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 31,
                  letterSpacing: -1,
                  color: _lmText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 38),
          const Text(
            'Trenuj bez myślenia\no liczbach.',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
              fontSize: 46,
              height: 1.02,
              letterSpacing: -1.5,
              color: _lmText,
            ),
          ),
          const SizedBox(height: 296),
          _PrimaryActionButton(
            label: 'Załóż konto',
            onPressed: isLoading ? null : onCreateAccount,
            hasGlow: true,
          ),
          const SizedBox(height: 12),
          _SecondaryActionButton(
            label: 'Mam już konto',
            onPressed: isLoading ? null : onLogin,
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(onPressed: onBack),
        const SizedBox(height: 18),
        const _ScreenTitle(
          'Jak korzystasz\nz LiftMate?',
          subtitle: 'Wybierz rolę. Zmienisz ją w ustawieniach.',
        ),
        const SizedBox(height: 28),
        _RoleCard(
          selected: selectedRole == UserRole.trainee,
          emoji: '🏋️',
          title: 'Jestem podopiecznym',
          subtitle: 'Wykonuję plan ułożony przez trenera',
          onTap: () => onRoleSelected(UserRole.trainee),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          selected: selectedRole == UserRole.trainer,
          emoji: '📋',
          title: 'Jestem trenerem',
          subtitle: 'Układam plany i prowadzę podopiecznych',
          onTap: () => onRoleSelected(UserRole.trainer),
        ),
        const SizedBox(height: 24),
        _PrimaryActionButton(label: 'Dalej', onPressed: onContinue),
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
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackButton(onPressed: onBack),
          const SizedBox(height: 18),
          const _ScreenTitle('Mam już konto'),
          const SizedBox(height: 28),
          _DesignedField(
            label: 'E-mail',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _DesignedField(
            label: 'Hasło',
            controller: passwordController,
            obscureText: true,
            suffix: 'Pokaż',
          ),
          _ErrorText(message: errorMessage),
          const SizedBox(height: 24),
          _PrimaryActionButton(
            label: 'Zaloguj',
            onPressed: isLoading ? null : onLogin,
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
    required this.onBack,
    required this.onRegister,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final UserRole role;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController displayNameController;
  final VoidCallback onBack;
  final Future<void> Function() onRegister;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final roleLabel = role == UserRole.trainer ? 'Trener' : 'Podopieczny';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackButton(onPressed: onBack),
          const SizedBox(height: 18),
          const _ScreenTitle('Załóż konto'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Rola: ',
                style: TextStyle(color: _lmMuted, fontSize: 14.5),
              ),
              Text(
                roleLabel,
                style: const TextStyle(
                  color: Color(0xFF9CC1FB),
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _DesignedField(
            label: 'Imię i nazwisko',
            controller: displayNameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _DesignedField(
            label: 'E-mail',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          _DesignedField(
            label: 'Hasło',
            controller: passwordController,
            obscureText: true,
            suffix: 'Pokaż',
          ),
          _ErrorText(message: errorMessage),
          const SizedBox(height: 24),
          _PrimaryActionButton(
            label: 'Utwórz konto',
            onPressed: isLoading ? null : onRegister,
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
    required this.onRetryTrainerCode,
    required this.onClaimTrainerCode,
    required this.onContinue,
    required this.onTrainerCodeChanged,
    this.trainerInviteCode,
    this.errorMessage,
  });

  final UserRole role;
  final TextEditingController trainerCodeController;
  final bool isLoading;
  final Future<void> Function() onRetryTrainerCode;
  final Future<void> Function() onClaimTrainerCode;
  final Future<void> Function() onContinue;
  final VoidCallback onTrainerCodeChanged;
  final String? trainerInviteCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final isTrainer = role == UserRole.trainer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BackButton(onPressed: onContinue),
        const SizedBox(height: 18),
        if (isTrainer)
          _TrainerInvitePanel(
            code: trainerInviteCode,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onRetryTrainerCode: onRetryTrainerCode,
            onContinue: onContinue,
          )
        else
          _TraineePairPanel(
            controller: trainerCodeController,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onChanged: onTrainerCodeChanged,
            onClaimTrainerCode: onClaimTrainerCode,
          ),
      ],
    );
  }
}

class _TrainerInvitePanel extends StatelessWidget {
  const _TrainerInvitePanel({
    required this.isLoading,
    required this.onRetryTrainerCode,
    required this.onContinue,
    this.code,
    this.errorMessage,
  });

  final bool isLoading;
  final Future<void> Function() onRetryTrainerCode;
  final Future<void> Function() onContinue;
  final String? code;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ScreenTitle(
          'Zaproś\npodopiecznego',
          subtitle:
              'Przekaż ten kod podopiecznemu. Po wpisaniu pojawi się na Twojej liście.',
        ),
        const SizedBox(height: 24),
        _InviteCodeCard(code: code, isLoading: isLoading),
        _ErrorText(message: errorMessage),
        const SizedBox(height: 22),
        if (code == null && !isLoading)
          _SecondaryActionButton(
            label: 'Spróbuj ponownie',
            onPressed: onRetryTrainerCode,
          )
        else
          _PrimaryActionButton(
            label: 'Przejdź do pulpitu',
            onPressed: isLoading ? null : onContinue,
          ),
      ],
    );
  }
}

class _TraineePairPanel extends StatelessWidget {
  const _TraineePairPanel({
    required this.controller,
    required this.isLoading,
    required this.onChanged,
    required this.onClaimTrainerCode,
    this.errorMessage,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onChanged;
  final Future<void> Function() onClaimTrainerCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ScreenTitle(
          'Połącz się\nz trenerem',
          subtitle: 'Wpisz kod, który otrzymasz od swojego trenera.',
        ),
        const SizedBox(height: 28),
        _TrainerCodeInput(controller: controller, onChanged: onChanged),
        const SizedBox(height: 18),
        _SuccessHint(
          visible: controller.text.trim().length >= 6,
          text: 'Znaleziono kod trenera',
        ),
        _ErrorText(message: errorMessage),
        const SizedBox(height: 24),
        _PrimaryActionButton(
          label: 'Połącz konto',
          onPressed: isLoading ? null : onClaimTrainerCode,
        ),
      ],
    );
  }
}

class _LiftMateLogo extends StatelessWidget {
  const _LiftMateLogo({
    this.size = 46,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lmBlue, _lmBlueDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: _lmBlue.withValues(alpha: 0.42),
            blurRadius: size * 0.56,
            offset: Offset(0, size * 0.22),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.48,
          height: size * 0.45,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LogoBar(width: size * 0.13, height: size * 0.45),
              _LogoBar(width: size * 0.22, height: size * 0.13),
              _LogoBar(width: size * 0.13, height: size * 0.45),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBar extends StatelessWidget {
  const _LogoBar({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(width),
      ),
    );
  }
}

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle(
    this.title, {
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w700,
            fontSize: 30,
            height: 1.1,
            letterSpacing: -0.8,
            color: _lmText,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            style: const TextStyle(
              color: _lmMuted,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _lmBlue.withValues(alpha: 0.16) : _lmPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _lmBlue : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _lmBlue.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontWeight: FontWeight.w600,
                      fontSize: 19,
                      color: _lmText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _lmMuted,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? _lmBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? _lmBlue : Colors.white.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignedField extends StatelessWidget {
  const _DesignedField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _lmMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('field-$label'),
          controller: controller,
          decoration: InputDecoration(
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: _lmBlue,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          textInputAction: textInputAction,
          validator: _requiredValidator,
        ),
      ],
    );
  }
}

class _TrainerCodeInput extends StatelessWidget {
  const _TrainerCodeInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final normalized = controller.text.trim().toUpperCase();
    final chars = List<String>.generate(
      6,
      (index) => index < normalized.length ? normalized[index] : '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 62,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var index = 0; index < chars.length; index++) ...[
                    Expanded(child: _CodeBox(ch: chars[index])),
                    if (index < chars.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              Positioned.fill(
                child: TextFormField(
                  key: const ValueKey('field-Kod trenera'),
                  controller: controller,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  cursorColor: Colors.transparent,
                  keyboardType: TextInputType.text,
                  obscureText: false,
                  showCursor: false,
                  style: const TextStyle(color: Colors.transparent),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.ch,
  });

  final String ch;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _lmPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ch.isEmpty ? Colors.white.withValues(alpha: 0.08) : _lmBlue,
        ),
      ),
      child: Text(
        ch,
        style: const TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: _lmText,
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.isLoading,
    this.code,
  });

  final bool isLoading;
  final String? code;

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      children: [
        const Text(
          'Twój kod zaproszenia',
          style: TextStyle(
            color: _lmDim,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isLoading ? '...' : code ?? '------',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontWeight: FontWeight.w700,
            fontSize: 44,
            letterSpacing: 8,
            color: _lmText,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: _lmBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '⧉ Kopiuj kod',
              style: TextStyle(
                color: Color(0xFF9CC1FB),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _lmPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// ignore: unused_element
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.user,
  });

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cześć,', style: TextStyle(color: _lmMuted)),
              Text(
                user.displayName,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_lmBlue, _lmBlueDark]),
          ),
          child: Text(
            initials.isEmpty ? 'LM' : initials,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.hasGlow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool hasGlow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: hasGlow && onPressed != null
            ? [
                BoxShadow(
                  color: _lmBlue.withValues(alpha: 0.4),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.chevron_left, size: 30, color: _lmMuted),
      ),
    );
  }
}

class _SuccessHint extends StatelessWidget {
  const _SuccessHint({
    required this.visible,
    required this.text,
  });

  final bool visible;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const Icon(Icons.check, color: _lmSuccess, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF7EE0AD),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ],
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
