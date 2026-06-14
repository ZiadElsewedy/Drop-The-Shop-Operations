import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
import 'package:fbro/features/shift/data/datasources/shift_remote_datasource.dart';
import 'package:fbro/features/shift/data/repositories/shift_repository_impl.dart';
import 'package:fbro/features/shift/domain/repositories/shift_repository.dart';
import 'package:fbro/features/auth/domain/usecases/get_users_by_branch.dart';
import 'package:fbro/features/task/data/datasources/task_remote_datasource.dart';
import 'package:fbro/features/task/data/repositories/task_repository_impl.dart';
import 'package:fbro/features/task/domain/repositories/task_repository.dart';
import 'package:fbro/features/task/domain/usecases/get_all_tasks.dart';
import 'package:fbro/features/task/domain/usecases/get_tasks_by_branch.dart';
import 'package:fbro/features/task/domain/usecases/get_employee_tasks.dart';
import 'package:fbro/features/task/domain/usecases/create_task.dart';
import 'package:fbro/features/task/domain/usecases/update_task.dart';
import 'package:fbro/features/task/domain/usecases/delete_task.dart';
import 'package:fbro/features/task/domain/usecases/assign_task.dart';
import 'package:fbro/features/task/domain/usecases/change_task_status.dart';
import 'package:fbro/features/task/domain/usecases/review_task.dart';
import 'package:fbro/features/task/domain/usecases/upload_task_proof.dart';
import 'package:fbro/features/task/presentation/cubit/task_cubit.dart';

class AppDependencies {
  AppDependencies._();

  static late final AuthCubit authCubit;
  static late final ProfileCubit profileCubit;
  static late final TaskCubit taskCubit;

  /// Phase 2 shift foundation. Composed here and ready for the shift UI (a
  /// `ShiftCubit` + use cases) to consume in the next phase; no in-app shift
  /// management screens drive it yet.
  static late final ShiftRepository shiftRepository;

  /// Phase 3 task foundation, activated by the Phase 4 [taskCubit] + use cases.
  static late final TaskRepository taskRepository;

  static void init() {
    final authRemoteDataSource = AuthRemoteDataSourceImpl(FirebaseAuth.instance);
    final userRemoteDataSource = UserRemoteDataSourceImpl(FirebaseFirestore.instance);
    final profileRemoteDataSource = ProfileRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
    final shiftRemoteDataSource =
        ShiftRemoteDataSourceImpl(FirebaseFirestore.instance);
    final taskRemoteDataSource = TaskRemoteDataSourceImpl(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );

    final AuthRepository authRepository =
        AuthRepositoryImpl(authRemoteDataSource, userRemoteDataSource);

    final ProfileRepository profileRepository =
        ProfileRepositoryImpl(profileRemoteDataSource, authRemoteDataSource);

    shiftRepository = ShiftRepositoryImpl(shiftRemoteDataSource);
    taskRepository = TaskRepositoryImpl(taskRemoteDataSource);

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
    );

    profileCubit = ProfileCubit(
      getProfile: GetProfile(profileRepository),
      updateProfile: UpdateProfile(profileRepository),
      uploadProfileImage: UploadProfileImage(profileRepository),
      uploadCoverImage: UploadCoverImage(profileRepository),
      checkUsername: CheckUsername(profileRepository),
    );

    taskCubit = TaskCubit(
      getAllTasks: GetAllTasks(taskRepository),
      getTasksByBranch: GetTasksByBranch(taskRepository),
      getEmployeeTasks: GetEmployeeTasks(taskRepository),
      createTask: CreateTask(taskRepository),
      updateTask: UpdateTask(taskRepository),
      deleteTask: DeleteTask(taskRepository),
      assignTask: AssignTask(taskRepository),
      changeTaskStatus: ChangeTaskStatus(taskRepository),
      reviewTask: ReviewTask(taskRepository),
      uploadTaskProof: UploadTaskProof(taskRepository),
      getUsersByBranch: GetUsersByBranch(authRepository),
    );
  }
}
