class AdminUserModel {
  const AdminUserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.is2FAEnabled,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool is2FAEnabled;

  factory AdminUserModel.fromFirestoreMap({
    required String uid,
    required String email,
    required Map<String, dynamic> data,
  }) {
    return AdminUserModel(
      uid: uid,
      email: email,
      displayName: data['displayName']?.toString(),
      is2FAEnabled: data['is2FAEnabled'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'is2FAEnabled': is2FAEnabled,
    };
  }
}
