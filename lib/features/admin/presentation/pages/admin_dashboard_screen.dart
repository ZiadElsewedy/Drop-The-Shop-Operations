import 'package:flutter/material.dart';
import 'package:fbro/core/widgets/role_placeholder.dart';

/// Admin dashboard. A functional Phase 1 placeholder; the real admin console
/// (user/branch/role management, metrics) is built out in Phase 5.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const RolePlaceholder(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Admin Dashboard',
        subtitle: 'Management tools arrive in Phase 5.',
      );
}
