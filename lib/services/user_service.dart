class User {
  String username;
  String password;
  String role;

  User({required this.username, required this.password, required this.role});
}

List<User> users = []; // In-memory storage for users

void registerUser(String username, String password, String role) {
  users.add(User(username: username, password: password, role: role));
}
