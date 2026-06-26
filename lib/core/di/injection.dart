import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fbro/core/services/notification_service.dart';
import 'package:fbro/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:fbro/features/auth/data/datasources/user_remote_datasource.dart';
import 'package:fbro/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fbro/features/auth/domain/repositories/auth_repository.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:fbro/features/auth/domain/usecases/register_with_email.dart';
import 'package:fbro/features/auth/domain/usecases/verify_phone_number.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_otp.dart';
import 'package:fbro/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:fbro/features/auth/domain/usecases/sign_out.dart';
import 'package:fbro/features/auth/domain/usecases/save_user.dart';
import 'package:fbro/features/auth/domain/usecases/get_user.dart';
import 'package:fbro/features/auth/domain/usecases/forgot_password.dart';
import 'package:fbro/features/auth/domain/usecases/send_email_verification.dart';
import 'package:fbro/features/auth/domain/usecases/check_email_verified.dart';
import 'package:fbro/features/auth/domain/usecases/change_password.dart';
import 'package:fbro/features/auth/domain/usecases/delete_account.dart';
import 'package:fbro/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fbro/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:fbro/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:fbro/features/profile/domain/repositories/profile_repository.dart';
import 'package:fbro/features/profile/domain/usecases/get_profile.dart';
import 'package:fbro/features/profile/domain/usecases/update_profile.dart';
import 'package:fbro/features/profile/domain/usecases/upload_profile_image.dart';
import 'package:fbro/features/profile/domain/usecases/upload_cover_image.dart';
import 'package:fbro/features/profile/domain/usecases/check_username.dart';
import 'package:fbro/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:fbro/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:fbro/features/task/data/datasources/task_remote_datasource.dart';
import 'package:fbro/features/task/data/repositories/task_repository_impl.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';
import 'package:fbro/features/task/domain/usecases/create_task.dart';
import 'package:fbro/features/task/domain/usecases/update_task.dart';
import 'package:fbro/features/task/domain/usecases/delete_task.dart';
import 'package:fbro/features/task/domain/usecases/assign_task.dart';
import 'package:fbro/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';
import 'package:fbro/features/branch/data/datasources/branch_remote_datasource.dart';
import 'package:fbro/features/branch/data/repositories/branch_repository_impl.dart';
import 'package:fbro/features/branch/domain/repositories/branch_repository.dart';
import 'package:fbro/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:fbro/features/admin/data/datasources/user_admin_remote_datasource.dart';
import 'package:fbro/features/admin/data/repositories/user_admin_repository_impl.dart';
import 'package:fbro/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:fbro/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:fbro/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:fbro/features/statistics/data/repositories/statistics_repository_impl.dart';
import 'package:fbro/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:fbro/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:fbro/features/schedule/data/datasources/schedule_remote_datasource.dart';
import 'package:fbro/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:fbro/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:fbro/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:fbro/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:fbro/features/operations/presentation/cubit/branch_operations_cubit.dart';
import 'package:fbro/features/communications/data/datasources/broadcast_remote_datasource.dart';
import 'package:fbro/features/communications/data/repositories/broadcast_repository_impl.dart';
import 'package:fbro/features/communications/domain/repositories/broadcast_repository.dart';
import 'package:fbro/features/communications/domain/usecases/send_broadcast.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:fbro/features/communications/data/datasources/broadcast_template_remote_datasource.dart';
import 'package:fbro/features/communications/data/repositories/broadcast_template_repository_impl.dart';
import 'package:fbro/features/communications/domain/repositories/broadcast_template_repository.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_template_cubit.dart';
import 'package:fbro/features/communications/data/datasources/broadcast_schedule_remote_datasource.dart';
import 'package:fbro/features/communications/data/repositories/broadcast_schedule_repository_impl.dart';
import 'package:fbro/features/communications/domain/repositories/broadcast_schedule_repository.dart';
import 'package:fbro/features/communications/presentation/cubit/broadcast_schedule_cubit.dart';
import 'package:fbro/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:fbro/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:fbro/features/notifications/domain/repositories/notification_repository.dart';
import 'package:fbro/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:fbro/features/notifications/domain/usecases/notify_swap_event.dart';
import 'package:fbro/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:fbro/features/notifications/presentation/cubit/notification_cubit.dart';

class AppDependencies {
  AppDependencies._();

  static late final AuthCubit authCubit;
  static late final ProfileCubit profileCubit;
  static late final TaskCubit taskCubit;

  // ─── Admin module (Phase 5) ─────────────────────────────────
  static late final BranchCubit branchCubit;
  static late final AdminUsersCubit adminUsersCubit;

  // ─── Statistics / dashboards (Phase 6) ──────────────────────
  static late final StatisticsCubit statisticsCubit;

  // ─── Weekly schedule + shift swaps (Phase 7) ────────────────
  static late final ScheduleCubit scheduleCubit;
  static late final ShiftSwapCubit shiftSwapCubit;

  // ─── Branch Operations cockpit (task→operations redesign) ───
  static late final BranchOperationsCubit branchOperationsCubit;

  // ─── Communications Center (Phase 1) ────────────────────────
  static late final BroadcastCubit broadcastCubit;

  // ─── Broadcast templates (Phase 2 Commit 2) ─────────────────
  static late final BroadcastTemplateCubit broadcastTemplateCubit;

  // ─── Broadcast schedules (Phase 2 Commit 4) ─────────────────
  static late final BroadcastScheduleCubit broadcastScheduleCubit;

  // ─── Notifications (Notification System Phase 1) ────────────
  static late final NotificationCubit notificationCubit;

  /// FCM foundation (Phase 6) — token registration + foreground handling.
  static late final NotificationService notificationService;

  /// Phase 3 task foundation, activated by the Phase 4 [taskCubit] + use cases.
  static late final TaskRepository taskRepository;

  static void init() {
    final authRemoteDataSource = AuthRemoteDataSourceImpl(FirebaseAuth.instance);
    final userRemoteDataSource = UserRemoteDataSourceImpl(FirebaseFirestore.instance);
    final profileRemoteDataSource = ProfileRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
    final taskRemoteDataSource = TaskRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );

    final AuthRepository authRepository =
        AuthRepositoryImpl(authRemoteDataSource, userRemoteDataSource);

    final ProfileRepository profileRepository =
        ProfileRepositoryImpl(profileRemoteDataSource, authRemoteDataSource);

    taskRepository = TaskRepositoryImpl(taskRemoteDataSource);

    // Branch repository is built early — the TaskCubit needs it for the admin's
    // New Task branch dropdown (the admin module reuses the same instance).
    final branchRemoteDataSource = BranchRemoteDataSourceImpl(
        FirebaseFirestore.instance, FirebaseStorage.instance);
    final BranchRepository branchRepository =
        BranchRepositoryImpl(branchRemoteDataSource);

    // Notification repository is built early — the TaskCubit needs the
    // NotifyTaskEvent use case for its automatic task-event notifications.
    final NotificationRepository notificationRepository =
        NotificationRepositoryImpl(
      NotificationRemoteDataSourceImpl(FirebaseFirestore.instance),
    );

    authCubit = AuthCubit(
      repository: authRepository,
      signInWithEmail: SignInWithEmail(authRepository),
      registerWithEmail: RegisterWithEmail(authRepository),
      verifyPhoneNumber: VerifyPhoneNumber(authRepository),
      signInWithOtp: SignInWithOtp(authRepository),
      signInWithGoogle: SignInWithGoogle(authRepository),
      signOut: SignOut(authRepository),
      saveUser: SaveUser(authRepository),
      getUser: GetUser(authRepository),
      forgotPassword: ForgotPassword(authRepository),
      sendEmailVerification: SendEmailVerification(authRepository),
      checkEmailVerified: CheckEmailVerified(authRepository),
      changePassword: ChangePassword(authRepository),
      deleteAccount: DeleteAccount(authRepository),
      // Drop this device's FCM token before Firebase sign-out (while still
      // authenticated), so the signed-out account stops receiving this device's
      // pushes. `notificationService` is a `late final` static assigned later in
      // init(); the closure is invoked only at sign-out, long after it's set.
      onPreSignOut: () => notificationService.forgetUser(),
    );

    profileCubit = ProfileCubit(
      getProfile: GetProfile(profileRepository),
      updateProfile: UpdateProfile(profileRepository),
      uploadProfileImage: UploadProfileImage(profileRepository),
      uploadCoverImage: UploadCoverImage(profileRepository),
      checkUsername: CheckUsername(profileRepository),
    );

    taskCubit = TaskCubit(
      repository: taskRepository,
      branchRepository: branchRepository,
      createTask: CreateTask(taskRepository),
      updateTask: UpdateTask(taskRepository),
      deleteTask: DeleteTask(taskRepository),
      assignTask: AssignTask(taskRepository),
      uploadTaskAttachment: UploadTaskAttachment(taskRepository),
      getUsersByBranch: GetUsersByBranch(authRepository),
      notifyTaskEvent: NotifyTaskEvent(notificationRepository),
    );

    // ─── Admin module (Phase 5) ───────────────────────────────
    final userAdminRemoteDataSource =
        UserAdminRemoteDataSourceImpl(FirebaseFirestore.instance);
    final UserAdminRepository userAdminRepository =
        UserAdminRepositoryImpl(userAdminRemoteDataSource);

    branchCubit = BranchCubit(branchRepository);
    adminUsersCubit = AdminUsersCubit(userAdminRepository, branchRepository);

    // ─── Statistics / dashboards (Phase 6) ────────────────────
    final StatisticsRepository statisticsRepository = StatisticsRepositoryImpl(
      StatisticsRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    statisticsCubit = StatisticsCubit(statisticsRepository);

    // ─── Weekly schedule + shift swaps (Phase 7) ──────────────
    final ScheduleRepository scheduleRepository = ScheduleRepositoryImpl(
      ScheduleRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseFunctions.instance,
      ),
    );
    scheduleCubit =
        ScheduleCubit(scheduleRepository, GetUsersByBranch(authRepository));
    shiftSwapCubit = ShiftSwapCubit(
      scheduleRepository,
      NotifySwapEvent(notificationRepository),
      GetUsersByBranch(authRepository),
    );

    // ─── Branch Operations cockpit ────────────────────────────
    // Read/derive cubit composing the task stream × branch members × today's
    // roster; writes still flow through [taskCubit].
    branchOperationsCubit = BranchOperationsCubit(
      taskRepository: taskRepository,
      scheduleRepository: scheduleRepository,
      getUsersByBranch: GetUsersByBranch(authRepository),
    );

    // ─── Communications Center (Phase 1 + Phase 2 send engine) ─
    // Hybrid cubit (like TaskCubit): the SendBroadcast use case for the write
    // (→ the callable `sendBroadcast` Cloud Function), the repository directly
    // for the realtime feed stream (Firestore).
    final BroadcastRepository broadcastRepository = BroadcastRepositoryImpl(
      BroadcastRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseFunctions.instance,
      ),
    );
    broadcastCubit = BroadcastCubit(
      repository: broadcastRepository,
      sendBroadcast: SendBroadcast(broadcastRepository),
      branchRepository: branchRepository,
      getUsersByBranch: GetUsersByBranch(authRepository),
    );

    // ─── Broadcast templates (Phase 2 Commit 2) ───────────────
    final BroadcastTemplateRepository broadcastTemplateRepository =
        BroadcastTemplateRepositoryImpl(
      BroadcastTemplateRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    broadcastTemplateCubit =
        BroadcastTemplateCubit(broadcastTemplateRepository);

    // ─── Broadcast schedules (Phase 2 Commit 4) ───────────────
    final BroadcastScheduleRepository broadcastScheduleRepository =
        BroadcastScheduleRepositoryImpl(
      BroadcastScheduleRemoteDataSourceImpl(FirebaseFirestore.instance),
    );
    broadcastScheduleCubit =
        BroadcastScheduleCubit(broadcastScheduleRepository);

    // ─── Notifications (Notification System Phase 1) ──────────
    notificationCubit = NotificationCubit(
      repository: notificationRepository,
      markRead: MarkNotificationRead(notificationRepository),
    );

    notificationService = NotificationService(
      FirebaseMessaging.instance,
      FirebaseFirestore.instance,
    );
  }
}
