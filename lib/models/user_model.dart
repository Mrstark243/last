class User {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String role;
  final String? rollNumber; // for students
  final String? subject; // for teachers

  User({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.rollNumber,
    this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'rollNumber': rollNumber,
      'subject': subject,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      password: map['password'],
      role: map['role'],
      rollNumber: map['rollNumber'],
      subject: map['subject'],
    );
  }
}
