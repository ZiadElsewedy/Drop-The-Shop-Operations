import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:drop/core/services/case_seen_store.dart';
import 'package:drop/core/services/notification_service.dart';
import 'package:drop/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:drop/features/auth/data/datasources/user_remote_datasource.dart';
import 'package:drop/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:drop/features/auth/domain/repositories/auth_repository.dart';
import 'package:drop/features/auth/domain/usecases/sign_in_with_email.dart';
import 'package:drop/features/auth/domain/usecases/sign_out.dart';
import 'package:drop/features/auth/domain/usecases/get_user.dart';
import 'package:drop/features/auth/domain/usecases/forgot_password.dart';
import 'package:drop/features/auth/domain/usecases/change_password.dart';
import 'package:drop/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:drop/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:drop/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:drop/features/profile/domain/repositories/profile_repository.dart';
import 'package:drop/features/profile/domain/usecases/get_profile.dart';
import 'package:drop/features/profile/domain/usecases/update_profile.dart';
import 'package:drop/features/profile/domain/usecases/upload_profile_image.dart';
import 'package:drop/features/profile/domain/usecases/upload_cover_image.dart';
import 'package:drop/features/profile/domain/usecases/check_username.dart';
import 'package:drop/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:drop/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:drop/features/task/data/datasources/task_remote_datasource.dart';
import 'package:drop/features/task/data/repositories/task_repository_impl.dart';
import 'package:drop/features/task/domain/repositories/task_repository.dart';
import 'package:drop/features/task/domain/usecases/create_task.dart';
import 'package:drop/features/task/domain/usecases/update_task.dart';
import 'package:drop/features/task/domain/usecases/delete_task.dart';
import 'package:drop/features/task/domain/usecases/assign_task.dart';
import 'package:drop/features/task/domain/usecases/upload_task_attachment.dart';
import 'package:drop/features/task/presentation/cubit/task_cubit.dart';
import 'package:drop/features/branch/data/datasources/branch_remote_datasource.dart';
import 'package:drop/features/branch/data/repositories/branch_repository_impl.dart';
import 'package:drop/features/branch/domain/repositories/branch_repository.dart';
import 'package:drop/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:drop/features/admin/data/datasources/user_admin_remote_datasource.dart';
import 'package:drop/features/admin/data/repositories/user_admin_repository_impl.dart';
import 'package:drop/features/admin/domain/repositories/user_admin_repository.dart';
import 'package:drop/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:drop/features/statistics/data/datasources/statistics_remote_datasource.dart';
import 'package:drop/features/statistics/data/repositories/statistics_repository_impl.dart';
import 'package:drop/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:drop/features/statistics/presentation/cubit/statistics_cubit.dart';
import 'package:drop/features/schedule/data/datasources/schedule_remote_datasource.dart';
import 'package:drop/features/schedule/data/datasources/shift_template_remote_datasource.dart';
import 'package:drop/features/schedule/data/repositories/schedule_repository_impl.dart';
import 'package:drop/features/schedule/data/repositories/shift_template_repository_impl.dart';
import 'package:drop/features/schedule/domain/repositories/schedule_repository.dart';
import 'package:drop/features/schedule/domain/repositories/shift_template_repository.dart';
import 'package:drop/features/schedule/presentation/cubit/schedule_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_swap_cubit.dart';
import 'package:drop/features/schedule/presentation/cubit/shift_template_cubit.dart';
import 'package:drop/features/operations/presentation/cubit/branch_operations_cubit.dart';
import 'package:drop/features/communications/data/datasources/broadcast_remote_datasource.dart';
import 'package:drop/features/communications/data/repositories/broadcast_repository_impl.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_repository.dart';
import 'package:drop/features/communications/domain/usecases/send_broadcast.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_cubit.dart';
import 'package:drop/features/communications/data/datasources/broadcast_template_remote_datasource.dart';
import 'package:drop/features/communications/data/repositories/broadcast_template_repository_impl.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_template_repository.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_template_cubit.dart';
import 'package:drop/features/communications/data/datasources/broadcast_schedule_remote_datasource.dart';
import 'package:drop/features/communications/data/repositories/broadcast_schedule_repository_impl.dart';
import 'package:drop/features/communications/domain/repositories/broadcast_schedule_repository.dart';
import 'package:drop/features/communications/presentation/cubit/broadcast_schedule_cubit.dart';
import 'package:drop/features/notifications/data/datasources/notification_remote_datasource.dart';
import 'package:drop/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:drop/features/notifications/domain/repositories/notification_repository.dart';
import 'package:drop/features/notifications/domain/usecases/mark_notification_read.dart';
import 'package:drop/features/notifications/domain/usecases/notify_swap_event.dart';
import 'package:drop/features/notifications/domain/usecases/notify_task_event.dart';
import 'package:drop/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:drop/features/cases/data/datasources/case_remote_datasource.dart';
import 'package:drop/features/cases/data/repositories/case_repository_impl.dart';
import 'package:drop/features/cases/domain/repositories/case_repository.dart';
import 'package:drop/features/cases/domain/usecases/change_case_status.dart';
import 'package:drop/features/cases/domain/usecases/create_case.dart';
import 'package:drop/features/cases/domain/usecases/send_case_message.dart';
import 'package:drop/features/cases/domain/usecases/upload_case_attachment.dart';
import 'package:drop/features/cases/presentation/cubit/case_conversation_cubit.dart';
import 'package:drop/features/cases/presentation/cubit/case_list_cubit.dart';
import 'package:drop/features/requests/data/datasources/request_remote_datasource.dart';
import 'package:drop/features/requests/data/repositories/request_repository_impl.dart';
import 'package:drop/features/requests/domain/repositories/request_repository.dart';
import 'package:drop/features/requests/domain/usecases/add_request_comment.dart';
import 'package:drop/features/requests/domain/usecases/change_request_status.dart';
import 'package:drop/features/requests/domain/usecases/create_request.dart';
import 'package:drop/features/requests/domain/usecases/upload_request_attachment.dart';
import 'package:drop/features/requests/presentation/cubit/request_detail_cubit.dart';
import 'package:drop/features/requests/presentation/cubit/requests_list_cubit.dart';
import 'package:drop/features/auth/domain/entities/user_entity.dart' show UserEntity;

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

  /// Shift templates (Schedule V2 · Pillar 5). The repository is shared; the
  /// manager cubit is created on demand by the template sheet.
  static late final ShiftTemplateRepository shiftTemplateRepository;
  static ShiftTemplateCubit createShiftTemplateCubit() =>
      ShiftTemplateCubit(shiftTemplateRepository);
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

  /// Case Management — the inbox list cubit (singleton, app-wide).
  static late final CaseListCubit caseListCubit;

  // Case Management — repository + write use cases, kept so a fresh per-case
  // [CaseConversationCubit] can be built on demand (one per opened case).
  static late final CaseRepository _caseRepository;
  static late final SendCaseMessage _sendCaseMessage;
  static late final ChangeCaseStatus _changeCaseStatus;
  static late final UploadCaseAttachment _uploadCaseAttachment;

  /// Builds a fresh conversation cubit for [caseId] (owned + disposed by its
  /// `BlocProvider`; re-created when the selected case changes).
  static CaseConversationCubit createCaseConversationCubit(
    String caseId,
    UserEntity? user,
  ) =>
      CaseConversationCubit(
        repository: _caseRepository,
        sendMessage: _sendCaseMessage,
        changeStatus: _changeCaseStatus,
        uploadCaseAttachment: _uploadCaseAttachment,
        user: user,
        caseId: caseId,
      );

  /// Operations Requests — the inbox list cubit (singleton, app-wide).
  static late final RequestsListCubit requestsListCubit;

  // Operations Requests — repository + write use cases, kept so a fresh per-request
  // [RequestDetailCubit] can be built on demand (one per opened request).
  static late final RequestRepository _requestRepository;
  static late final ChangeRequestStatus _changeRequestStatus;
  static late final AddRequestComment _addRequestComment;
  static late final UploadRequestAttachment _uploadRequestAttachment;

  /// Builds a fresh detail cubit for [requestId] (owned + disposed by its
  /// `BlocProvider`; re-created when the selected request changes).
  static RequestDetailCubit createRequestDetailCubit(
    String requestId,
    UserEntity? user,
  ) =>
      RequestDetailCubit(
        repository: _requestRepository,
        changeStatus: _changeRequestStatus,
        addComment: _addRequestComment,
        uploadAttachment: _uploadRequestAttachment,
        user: user,
        requestId: requestId,
      );

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
      NotificationRemoteDataSourceImpl(
          FirebaseFirestore.instance, FirebaseFunctions.instance),
    );

    authCubit = AuthCubit(
      repository: authRepository,
      signInWithEmail: SignInWithEmail(authRepository),
      signOut: SignOut(authRepository),
      getUser: GetUser(authRepository),
      forgotPassword: ForgotPassword(authRepository),
      changePassword: ChangePassword(authRepository),
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

    // Schedule repository is built early — the TaskCubit needs it to resolve an
    // employee's shift(s) today (Shift Assignment feature) and shift-task
    // notification recipients; reused as-is by scheduleCubit/shiftSwapCubit/
    // branchOperationsCubit below.
    final ScheduleRepository scheduleRepository = ScheduleRepositoryImpl(
      ScheduleRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseFunctions.instance,
      ),
    );

    // Shift templates (Schedule V2 · Pillar 5) — reused by scheduleCubit (to
    // snapshot new weeks + apply scoped hours edits) and the template manager.
    shiftTemplateRepository = ShiftTemplateRepositoryImpl(
      ShiftTemplateRemoteDataSourceImpl(FirebaseFirestore.instance),
    );

    taskCubit = TaskCubit(
      repository: taskRepository,
      branchRepository: branchRepository,
      scheduleRepository: scheduleRepository,
      createTask: CreateTask(taskRepository),
      updateTask: UpdateTask(taskRepository),
      deleteTask: DeleteTask(taskRepository),
      assignTask: AssignTask(taskRepository),
      uploadTaskAttachment: UploadTaskAttachment(taskRepository),
      getUsersByBranch: GetUsersByBranch(authRepository),
      notifyTaskEvent: NotifyTaskEvent(notificationRepository),
    );

    // ─── Case Management (private conversation until resolution) ─────────
    // The list cubit (like TaskCubit): use cases for writes, repository directly
    // for the role-scoped realtime/one-shot case lists. Reuses branchRepository
    // (branch names) + GetUsersByBranch (member directory). The per-case
    // conversation cubit is built on demand via [createCaseConversationCubit].
    // Case notifications are produced server-side.
    final CaseRepository caseRepository = CaseRepositoryImpl(
      CaseRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
      ),
    );
    _caseRepository = caseRepository;
    final uploadCaseAttachment = UploadCaseAttachment(caseRepository);
    _uploadCaseAttachment = uploadCaseAttachment;
    _sendCaseMessage = SendCaseMessage(caseRepository);
    _changeCaseStatus = ChangeCaseStatus(caseRepository);
    caseListCubit = CaseListCubit(
      repository: caseRepository,
      branchRepository: branchRepository,
      createCase: CreateCase(caseRepository),
      uploadCaseAttachment: uploadCaseAttachment,
      getUsersByBranch: GetUsersByBranch(authRepository),
      seenStore: CaseSeenStore(),
    );

    // ─── Operations Requests (in-the-moment approvals) ──────────────────
    // Same hybrid as Cases: the list cubit reads a single role-scoped realtime
    // stream + files new requests (use cases for the write); the per-request
    // detail cubit is built on demand via [createRequestDetailCubit]. Reuses
    // branchRepository for branch names. Notifications are produced server-side
    // by the `onRequest*` Cloud Functions.
    final RequestRepository requestRepository = RequestRepositoryImpl(
      RequestRemoteDataSourceImpl(
        FirebaseFirestore.instance,
        FirebaseStorage.instance,
      ),
    );
    _requestRepository = requestRepository;
    _uploadRequestAttachment = UploadRequestAttachment(requestRepository);
    _changeRequestStatus = ChangeRequestStatus(requestRepository);
    _addRequestComment = AddRequestComment(requestRepository);
    requestsListCubit = RequestsListCubit(
      repository: requestRepository,
      branchRepository: branchRepository,
      createRequest: CreateRequest(requestRepository),
      uploadAttachment: _uploadRequestAttachment,
    );

    // ─── Admin module (Phase 5) ───────────────────────────────
    // Account provisioning (create / reset password) goes through admin-only
    // Cloud Functions (Admin SDK), so the datasource also takes FirebaseFunctions.
    final userAdminRemoteDataSource = UserAdminRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseFunctions.instance,
    );
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
    // (scheduleRepository built earlier, above, so TaskCubit could use it.)
    scheduleCubit = ScheduleCubit(
      scheduleRepository,
      GetUsersByBranch(authRepository),
      shiftTemplateRepository,
    );
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
