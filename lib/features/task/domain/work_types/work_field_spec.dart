/// The kind of value a dynamic **work field** captures. Drives which input
/// widget the create form renders and how the value is typed inside the task's
/// `data` map (`Map<String, dynamic>`): numbers stay `num`, dates/times stay
/// `DateTime`, toggles stay `bool` — no string round-trips.
///
/// This is the task-side sibling of `RequestFieldKind` (the `requests` feature),
/// widened for the richer inputs operational work needs (whole numbers, money,
/// yes/no, single-choice).
enum WorkFieldKind {
  /// Single-line free text.
  text,

  /// Multi-line free text (a description / note).
  multiline,

  /// A decimal number. Stored as `num`.
  number,

  /// A whole number (a quantity / count). Stored as `int`.
  integer,

  /// A monetary amount. Stored as `num`; the form renders a currency affordance.
  currency,

  /// A calendar date. Stored as `DateTime` (date picker).
  date,

  /// A time of day. Stored as `DateTime` (time picker; hour/minute meaningful).
  time,

  /// A yes/no flag. Stored as `bool` (a switch).
  toggle,

  /// Exactly one of [WorkFieldSpec.options]. Stored as the option's `value`
  /// (`String`).
  select,
}

/// One choice in a [WorkFieldKind.select] field. Pure data.
class WorkFieldOption {
  final String value;
  final String label;
  const WorkFieldOption(this.value, this.label);
}

/// One field in a work type's dynamic form. **Pure data** — the presentation
/// layer maps [kind] to an input widget and renders [label]/[hint]; the domain
/// keeps this Flutter-free so a work type's schema is unit-testable.
///
/// Values persist in `tasks/{id}.data` keyed by [key] (a stable machine key that
/// is never shown to the user). A field owns its own [validate] so a
/// [WorkTypeDefinition] never re-implements "required"/bounds checking.
class WorkFieldSpec {
  /// Stable storage key inside `data` (never displayed).
  final String key;

  /// Human label shown above the input and in the detail view.
  final String label;

  final WorkFieldKind kind;

  /// Whether the **create** form blocks submission until this field has a value.
  /// (Setup-required; completion requirements are expressed per type in
  /// [WorkTypeDefinition.validateSubmission].)
  final bool required;

  /// Whether this field is captured by the *executing employee* at completion
  /// (a counted quantity, an amount spent) rather than by the creator at setup.
  /// Drives *where* the input appears: setup fields render on the create form,
  /// completion fields render on the details screen while the employee works.
  final bool capturedAtCompletion;

  final String? hint;

  /// Choices for a [WorkFieldKind.select] field. Empty for every other kind.
  final List<WorkFieldOption> options;

  /// Inclusive numeric bounds for [isNumeric] fields (ignored otherwise).
  final num? min;
  final num? max;

  const WorkFieldSpec({
    required this.key,
    required this.label,
    this.kind = WorkFieldKind.text,
    this.required = true,
    this.capturedAtCompletion = false,
    this.hint,
    this.options = const [],
    this.min,
    this.max,
  });

  bool get isTextual =>
      kind == WorkFieldKind.text || kind == WorkFieldKind.multiline;

  bool get isNumeric =>
      kind == WorkFieldKind.number ||
      kind == WorkFieldKind.integer ||
      kind == WorkFieldKind.currency;

  /// Validates a single captured [value] against this field. Returns a
  /// human-readable error, or `null` when valid. Centralizes required + numeric
  /// bounds so definitions don't repeat it (they compose this via
  /// [WorkTypeDefinition.validateSetup]).
  String? validate(Object? value) {
    final isEmpty = value == null || (value is String && value.trim().isEmpty);
    if (required && isEmpty) return '$label is required.';
    if (isEmpty) return null;
    if (isNumeric && value is num) {
      if (min != null && value < min!) return '$label must be at least $min.';
      if (max != null && value > max!) return '$label must be at most $max.';
    }
    if (kind == WorkFieldKind.select &&
        value is String &&
        options.isNotEmpty &&
        !options.any((o) => o.value == value)) {
      return 'Choose a valid $label.';
    }
    return null;
  }
}
