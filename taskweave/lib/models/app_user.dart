class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  String get name => displayName ?? email.split('@').first;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
    );
  }
}
