import 'package:flutter/material.dart';

import 'relationship_models.dart';
import 'relationship_screen_styles.dart';

class TrainerTraineeDetailScreen extends StatelessWidget {
  const TrainerTraineeDetailScreen({
    required this.trainee,
    required this.onBack,
    required this.onLogout,
    super.key,
  });

  final TrainerTraineeSummary trainee;
  final VoidCallback onBack;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Wróć',
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_left_rounded, size: 30),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Podopieczny',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Wyloguj',
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  RelationshipAvatar(label: trainee.displayName, size: 62),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trainee.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontWeight: FontWeight.w700,
                            fontSize: 23,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Połączona',
                          style: TextStyle(color: lmMuted, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              RelationshipCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RelationshipSectionLabel('Dane relacji'),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'E-mail', value: trainee.email),
                    const SizedBox(height: 10),
                    const _DetailRow(label: 'Status', value: 'Aktywna relacja'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const RelationshipSectionLabel('Przypisany zestaw'),
              const SizedBox(height: 12),
              const RelationshipCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brak przypisanego zestawu',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Zestawy treningowe pojawią się tutaj w kolejnych etapach produktu.',
                      style: TextStyle(color: lmMuted, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const RelationshipBottomNav(
          items: [
            RelationshipBottomNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Pulpit',
              active: true,
            ),
            RelationshipBottomNavItem(
              icon: Icons.fitness_center_rounded,
              label: 'Zestawy',
            ),
            RelationshipBottomNavItem(
              icon: Icons.play_circle_rounded,
              label: 'Trening',
            ),
            RelationshipBottomNavItem(
              icon: Icons.menu_rounded,
              label: 'Profil',
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(color: lmMuted)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
