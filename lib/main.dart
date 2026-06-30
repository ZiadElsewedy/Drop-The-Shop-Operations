import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:drop/core/di/injection.dart';
import 'package:drop/core/routes/app_router.dart';
import 'package:drop/core/routes/route_names.dart';
import 'package:drop/core/theme/app_theme.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/auth/presentation/cubit/auth_state.dart';
import 'package:drop/firebase_options.dart';

/// Background FCM handler. The push carries a `notification` block, so the OS
/// renders it while the app is backgrounded/terminated — no background data
/// processing is needed here. Must be a top-level, vm:entry-point function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Lets the notification service surface foreground pushes as in-app snackbars.
final GlobalKey<ScaffoldMessengerState> _messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The app router, created once so the FCM tap handler can navigate.
late final GoRouter _router;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline-first: enable Firestore local persistence with an unlimited cache so
  // the app survives unstable connections — cached reads, queued writes that
  // sync on reconnect, and no crashes when the network drops. Mobile enables
  // persistence by default; we set it explicitly (and lift the cache cap) for
  // production. Must run before any Firestore operation.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  AppDependencies.init();
  _router = createRouter(AppDependencies.authCubit);

  // FCM engine (best-effort; never blocks startup).
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  AppDependencies.notificationService
    ..onForeground = (title, body) {
      final text = [title, body]
          .where((s) => s != null && s.isNotEmpty)
          .join(' — ');
      if (text.isNotEmpty) {
        _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
      }
    }
    ..onMessageTap = (data) {
      // Notification tapped (from background or cold start). A task push opens
      // the exact task; everything else opens the in-app inbox (a shared route
      // for every role). The router redirects to the right place if the session
      // isn't ready. Log the payload for diagnostics.
      developer.log(
        'Notification tapped — type=${data['type']} task=${data['taskId']} '
        'broadcast=${data['broadcastId']} route=${data['route']}',
        name: 'fcm',
      );
      final taskId = data['taskId'];
      if (data['route'] == 'task_details' && taskId != null && taskId.isNotEmpty) {
        _router.push(RouteNames.taskDetail(taskId));
      } else {
        _router.go(RouteNames.notifications);
      }
    }
    ..init();

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: AppDependencies.authCubit),
        BlocProvider.value(value: AppDependencies.profileCubit),
        BlocProvider.value(value: AppDependencies.taskCubit),
        BlocProvider.value(value: AppDependencies.branchCubit),
        BlocProvider.value(value: AppDependencies.adminUsersCubit),
        BlocProvider.value(value: AppDependencies.statisticsCubit),
        BlocProvider.value(value: AppDependencies.scheduleCubit),
        BlocProvider.value(value: AppDependencies.shiftSwapCubit),
        BlocProvider.value(value: AppDependencies.branchOperationsCubit),
        BlocProvider.value(value: AppDependencies.broadcastCubit),
        BlocProvider.value(value: AppDependencies.broadcastTemplateCubit),
        BlocProvider.value(value: AppDependencies.broadcastScheduleCubit),
        BlocProvider.value(value: AppDependencies.notificationCubit),
      ],
      // Register / clear the FCM token as the auth session changes.
      child: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          state.maybeWhen(
            authenticated: (u) {
              AppDependencies.notificationService.registerToken(u.uid);
              AppDependencies.notificationCubit.load(u.uid);
              // Phase C warm-start: preload the home-critical cubits the moment
              // the session is known (cold-start restore OR fresh login), so the
              // fetch overlaps the splash/route transition and Home paints with
              // real data instead of skeletons. Fire-and-forget + concurrent for
              // per-cubit error isolation; both loads are idempotent (Phase A),
              // so Home's own initState calls then no-op (no double fetch).
              // Gated on access — a pending user (confined to /pending-approval)
              // triggers zero home reads.
              if (u.hasAppAccess) {
                AppDependencies.statisticsCubit.load(u);
                AppDependencies.taskCubit.load(u);
                // Branch directory — small + cached; lets every branch-identity
                // surface (schedule/operations/profile/swap) resolve a branchId
                // to its logo via the app-wide BranchCubit. (§8b)
                AppDependencies.branchCubit.loadIfNeeded();
              }
            },
            unauthenticated: () {
              AppDependencies.notificationService.forgetUser();
              AppDependencies.notificationCubit.clear();
            },
            orElse: () {},
          );
        },
        child: MaterialApp.router(
          title: 'DROP',
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          scaffoldMessengerKey: _messengerKey,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
