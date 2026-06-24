import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../relationships/relationship_screen_styles.dart';
import 'post_workout_feedback_controller.dart';

class PostWorkoutFeedbackScreen extends StatefulWidget {
  const PostWorkoutFeedbackScreen({
    required this.controller,
    required this.onSaved,
    required this.onSkipped,
    super.key,
  });

  final PostWorkoutFeedbackController controller;
  final Future<void> Function() onSaved;
  final Future<void> Function() onSkipped;

  @override
  State<PostWorkoutFeedbackScreen> createState() =>
      _PostWorkoutFeedbackScreenState();
}

class _PostWorkoutFeedbackScreenState extends State<PostWorkoutFeedbackScreen> {
  late final TextEditingController _commentController;
  bool _savedCallbackSent = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(
      text: widget.controller.state.comment,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmSkip();
        }
      },
      child: Scaffold(
        backgroundColor: lmBackground,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final state = widget.controller.state;
              if (state.status == PostWorkoutFeedbackStatus.submitted) {
                return const _FeedbackSuccess();
              }

              final isSubmitting =
                  state.status == PostWorkoutFeedbackStatus.submitting;
              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: lmBlueSoft,
                    size: 42,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Jak się czujesz po treningu?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Twoja odpowiedź pomoże trenerowi lepiej dopasować kolejne treningi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: lmMuted, height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      for (var rating = 1; rating <= 5; rating++) ...[
                        Expanded(
                          child: _RatingButton(
                            rating: rating,
                            selected: state.wellbeingRating == rating,
                            enabled: !isSubmitting,
                            onTap: () => widget.controller.setRating(rating),
                          ),
                        ),
                        if (rating < 5) const SizedBox(width: 7),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const ValueKey('feedback-comment'),
                    controller: _commentController,
                    enabled: !isSubmitting,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 1000,
                    inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                    onChanged: widget.controller.setComment,
                    decoration: InputDecoration(
                      labelText: 'Komentarz (opcjonalnie)',
                      alignLabelWithHint: true,
                      hintText: 'Napisz, co było łatwe lub trudne.',
                      counter: Text(
                        '${_commentController.text.length}/1000',
                        style: const TextStyle(color: lmMutedDark),
                      ),
                    ),
                  ),
                  if (state.status == PostWorkoutFeedbackStatus.error) ...[
                    const SizedBox(height: 12),
                    _FeedbackError(
                      message:
                          state.message ?? 'Nie udało się wysłać feedbacku.',
                      onRetry: isSubmitting ? null : _submit,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: state.wellbeingRating == null || isSubmitting
                        ? null
                        : _submit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSubmitting) ...[
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                        ],
                        const Text('Wyślij feedback'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSubmitting ? null : _confirmSkip,
                    child: const Text('Pomiń'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final result = await widget.controller.submit();
    if (!mounted || !result.isSuccess || _savedCallbackSent) {
      return;
    }
    _savedCallbackSent = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) {
      return;
    }
    await widget.onSaved();
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pominąć feedback?'),
          content: const Text(
            'Możesz dodać feedback później z historii treningu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Wróć'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pomiń'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      await widget.onSkipped();
    }
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int rating;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _ratingLabel(rating);
    return Semantics(
      label: '$rating $label',
      button: true,
      selected: selected,
      container: true,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('feedback-rating-$rating'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? lmBlue.withValues(alpha: 0.2) : lmSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? lmBlue : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$rating',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: selected ? lmBlueSoft : lmText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: lmMuted, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackError extends StatelessWidget {
  const _FeedbackError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RelationshipCard(
      borderColor: Colors.redAccent.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSuccess extends StatelessWidget {
  const _FeedbackSuccess();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: lmGreen, size: 58),
            SizedBox(height: 18),
            Text(
              'Dzięki! Feedback został zapisany.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 23,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _ratingLabel(int rating) {
  return switch (rating) {
    1 => 'Bardzo źle',
    2 => 'Źle',
    3 => 'W porządku',
    4 => 'Dobrze',
    5 => 'Bardzo dobrze',
    _ => throw ArgumentError.value(rating, 'rating'),
  };
}
