/// Runs [tasks] with at most [limit] in flight at once, preserving result order.
///
/// A drop-in, order-preserving alternative to `Future.wait` for heavy work
/// (large media uploads) where full fan-out would saturate the connection and
/// spike memory. On the first failure it stops pulling **new** tasks and
/// rethrows that error (with its stack) once the already-started ones settle —
/// mirroring `Future.wait`'s "first error wins" contract while avoiding kicking
/// off work that is about to be discarded.
Future<List<T>> mapPooled<T>(
  int limit,
  List<Future<T> Function()> tasks,
) async {
  if (tasks.isEmpty) return <T>[];
  final results = List<T?>.filled(tasks.length, null);
  var next = 0;
  Object? firstError;
  StackTrace? firstStack;

  Future<void> worker() async {
    // `next++` is synchronous between awaits (Dart is single-threaded), so no
    // two workers ever claim the same index.
    while (next < tasks.length && firstError == null) {
      final i = next++;
      try {
        results[i] = await tasks[i]();
      } catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
        return;
      }
    }
  }

  final poolSize = limit < 1 ? 1 : (limit > tasks.length ? tasks.length : limit);
  await Future.wait(List.generate(poolSize, (_) => worker()));

  if (firstError != null) {
    Error.throwWithStackTrace(firstError!, firstStack!);
  }
  return results.cast<T>();
}
