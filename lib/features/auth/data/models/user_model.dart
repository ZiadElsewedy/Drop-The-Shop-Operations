import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fbro/features/auth/domain/entities/user_entity.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final String authProvider;
  final bool isEmailVerified;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.authProvider,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.createdAt,
  });

  factory UserModel.fromFirebaseUser(User user, {String authProvider = 'unknown'}) =>
      UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        phoneNumber: user.phoneNumber,
        authProvider: authProvider,
        isEmailVerified: user.emailVerified,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        uid: entity.uid,
        email: entity.email,
        displayName: entity.displayName,
        photoUrl: entity.photoUrl,
        phoneNumber: entity.phoneNumber,
        authProvider: entity.authProvider,
        isEmailVerified: entity.isEmailVerified,
        createdAt: entity.createdAt,
      );

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String,
        email: map['email'] as String,
        displayName: map['displayName'] as String?,
        photoUrl: map['photoUrl'] as String?,
        phoneNumber: map['phoneNumber'] as String?,
        authProvider: map['authProvider'] as String? ?? 'unknown',
        isEmailVerified: map['isEmailVerified'] as bool? ?? false,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'phoneNumber': phoneNumber,
        'authProvider': authProvider,
        'isEmailVerified': isEmailVerified,
      };

  UserEntity toEntity() => UserEntity(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        phoneNumber: phoneNumber,
        authProvider: authProvider,
        isEmailVerified: isEmailVerified,
        createdAt: createdAt,
      );
}
