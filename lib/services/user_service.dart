import '../db/database_helper.dart';
import '../models/user_model.dart';

class UserService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Register user
  Future<String?> registerUser(User user) async {
    // Check if email already exists
    bool exists = await _dbHelper.emailExists(user.email);
    if (exists) {
      return "Email already exists";
    }

    // Insert user
    await _dbHelper.insertUser(user);
    return null; // null means success
  }

  // Login user
  Future<User?> loginUser(String email, String password) async {
    return await _dbHelper.getUserByEmailAndPassword(email, password);
  }
}
