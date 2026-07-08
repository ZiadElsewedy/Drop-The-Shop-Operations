/// The result of validating a work **draft** (create-time) or a work
/// **submission** (completion-time). Immutable + pure so it can be asserted on
/// directly in unit tests and surfaced verbatim in the UI.
///
/// Errors are split into [fieldErrors] (keyed by [WorkFieldSpec.key], so the
/// dynamic form can highlight the exact input) and [formErrors] (whole-form
/// problems that aren't tied to one field, e.g. "attach a proof photo").
class WorkValidation {
  final Map<String, String> fieldErrors;
  final List<String> formErrors;

  const WorkValidation._(this.fieldErrors, this.formErrors);

  /// Everything checks out.
  const WorkValidation.valid()
      : fieldErrors = const {},
        formErrors = const [];

  /// One or more field-level problems.
  const WorkValidation.fields(Map<String, String> errors)
      : fieldErrors = errors,
        formErrors = const [];

  /// One or more form-level problems.
  const WorkValidation.form(List<String> errors)
      : fieldErrors = const {},
        formErrors = errors;

  bool get ok => fieldErrors.isEmpty && formErrors.isEmpty;

  /// The first message worth showing (field errors first), or `null` when valid.
  String? get firstError {
    if (fieldErrors.isNotEmpty) return fieldErrors.values.first;
    if (formErrors.isNotEmpty) return formErrors.first;
    return null;
  }

  /// Combines two results (used when a definition layers its own checks on top
  /// of the inherited defaults via `super`).
  WorkValidation merge(WorkValidation other) => WorkValidation._(
        {...fieldErrors, ...other.fieldErrors},
        [...formErrors, ...other.formErrors],
      );
}
