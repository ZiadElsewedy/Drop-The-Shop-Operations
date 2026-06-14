import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbro/core/di/injection.dart';
import 'package:fbro/core/routes/app_router.dart';
import 'package:fbro/core/theme/app_theme.dart';
import 'package:fbro/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppDependencies.init();
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
      ],
      child: Builder(
        builder: (context) {
          final router = createRouter(AppDependencies.authCubit);
          return MaterialApp.router(
            title: 'FBRO',
            theme: AppTheme.dark,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
