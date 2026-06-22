import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fbro/core/theme/app_theme.dart';
import 'package:fbro/core/widgets/app_search_field.dart';

/// Regression test for the "search box looks like a field-inside-a-field" bug.
///
/// The global [InputDecorationTheme] sets `filled: true` + outline
/// `enabledBorder`/`focusedBorder`; the search field must neutralise ALL of them
/// so it renders as one clean surface. This locks those overrides in.
void main() {
  testWidgets('AppSearchField neutralises the global input theme (no inner box)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppSearchField(hint: 'Search branches', onChanged: (_) {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Search branches'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    final d = field.decoration!;
    expect(d.filled, isFalse, reason: 'must not inherit the theme fill');
    expect(d.border, InputBorder.none);
    expect(d.enabledBorder, InputBorder.none);
    expect(d.focusedBorder, InputBorder.none);
    expect(d.isCollapsed, isTrue, reason: 'no default 48px min-height box');
  });
}
