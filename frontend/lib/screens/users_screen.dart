import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../widgets/loading_indicator.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _isLoading = false;
  String? _error;
  List<User> _users = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (authProvider.user == null || authProvider.user?.token == null) {
      setState(() {
        _error = 'Not authorized to view users';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // This would typically fetch users from an API
      // For now, we'll just simulate a delay
      await Future.delayed(const Duration(seconds: 1));
      
      // In a real implementation, you would call a method like:
      // final users = await userProvider.fetchAllUsers(authProvider.user!.token!);
      
      // For now, let's create some dummy data
      setState(() {
        _users = [
          User(
            id: 1,
            username: 'admin',
            email: 'admin@example.com',
            fullName: 'Admin User',
            userType: 'admin',
            isActive: true,
          ),
          User(
            id: 2,
            username: 'officer1',
            email: 'officer1@example.com',
            fullName: 'Officer One',
            userType: 'officer',
            isActive: true,
          ),
          User(
            id: 3,
            username: 'driver1',
            email: 'driver1@example.com',
            fullName: 'Driver One',
            userType: 'vehicle_owner',
            isActive: true,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load users: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _getUserTypeDisplay(String userType) {
    switch (userType) {
      case 'admin':
        return 'Administrator';
      case 'officer':
        return 'Traffic Officer';
      case 'vehicle_owner':
        return 'Vehicle Owner';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: _isLoading
            ? const LoadingIndicator(message: 'Loading users...')
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchUsers,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _users.isEmpty
                    ? const Center(
                        child: Text('No users found'),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                child: Text(
                                  user.fullName != null && user.fullName!.isNotEmpty
                                      ? user.fullName!.substring(0, 1).toUpperCase()
                                      : user.username.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                user.fullName ?? user.username,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.email),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getUserRoleColor(user.userType).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getUserTypeDisplay(user.userType),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getUserRoleColor(user.userType),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  _showUserOptions(user);
                                },
                              ),
                            ),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Show dialog to add a new user
          // This would be implemented in a real app
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add user functionality not implemented yet')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getUserRoleColor(String userType) {
    switch (userType) {
      case 'admin':
        return Colors.purple;
      case 'officer':
        return Colors.blue;
      case 'vehicle_owner':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showUserOptions(User user) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit User'),
                onTap: () {
                  Navigator.pop(context);
                  // Show edit user dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit user functionality not implemented yet')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(user.isActive == true ? 'Deactivate User' : 'Activate User'),
                onTap: () {
                  Navigator.pop(context);
                  // Toggle user active status
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User status toggle functionality not implemented yet')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete User', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // Show delete confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete user functionality not implemented yet')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
} 