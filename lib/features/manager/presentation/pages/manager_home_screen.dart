import 'package:flutter/material.dart';
import 'package:fbro/core/widgets/role_placeholder.dart';

/// Manager home. A functional Phase 1 placeholder; the real manager experience
/// (shift scheduling, team oversight) is built out in Phase 3.
class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const RolePlaceholder(
        icon: Icons.supervisor_account_outlined,
        title: 'Manager Home',
        subtitle: 'Scheduling & team tools arrive in Phase 3.',
      );
}
