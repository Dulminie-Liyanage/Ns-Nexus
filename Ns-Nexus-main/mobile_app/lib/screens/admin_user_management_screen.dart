import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// USER FORM BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _UserFormSheet extends StatefulWidget {
  final UserModel? existing;
  final Future<void> Function({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
    required bool priorityStatus,
    String? userId,
  })
  onSubmit;

  const _UserFormSheet({this.existing, required this.onSubmit});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _first = TextEditingController(
    text: widget.existing?.firstName ?? '',
  );
  late final TextEditingController _last = TextEditingController(
    text: widget.existing?.lastName ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.existing?.email ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.existing?.phone ?? '',
  );
  late String _role;
  late bool _isPriority;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.existing?.role ?? 'retailer';
    _isPriority = widget.existing?.priorityStatus ?? false;
  }

  // Match exact role strings from DB
  static const _roles = [
    'warehouse_manager',
    'retailer',
    'driver',
    '3pl_manager',
    'admin',
  ];
  static const _roleLabels = {
    'warehouse_manager': 'Warehouse Manager',
    'retailer': 'Retailer',
    'driver': 'Delivery Driver',
    '3pl_manager': 'Logistics Manager',
    'admin': 'Admin',
  };

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.onSubmit(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        role: _role,
        priorityStatus: _isPriority,
        userId: widget.existing?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _isEdit ? 'Edit user' : 'Create new user',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _first,
                    'First name',
                    Icons.person_outline,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _last,
                    'Last name',
                    Icons.person_outline,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              _email,
              'Email',
              Icons.email_outlined,
              keyboard: TextInputType.emailAddress,
              readOnly: _isEdit,
              validator: (v) {
                if (v!.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              _phone,
              'Phone',
              Icons.phone_outlined,
              keyboard: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) =>
                  v!.trim().length < 9 ? 'Enter valid phone' : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'Role',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roles.map((r) {
                final selected = _role == r;
                return GestureDetector(
                  onTap: () => setState(() => _role = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0056B3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF0056B3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      _roleLabels[r] ?? r,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            // US-09: Priority Status toggle — only for retailers
            if (_role == 'retailer') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isPriority
                      ? const Color(0xFFFAEEDA)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isPriority
                        ? const Color(0xFFD4A017).withOpacity(0.4)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_outline,
                      color: _isPriority
                          ? const Color(0xFFD4A017)
                          : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Priority Retailer',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: _isPriority
                                  ? const Color(0xFF854F0B)
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            'Can place urgent orders & bypass 48-hour rule',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPriority,
                      activeColor: const Color(0xFFD4A017),
                      onChanged: (v) => setState(() => _isPriority = v),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0056B3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save changes' : 'Create account',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: formatters,
      readOnly: readOnly,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: readOnly,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _svc = UserService();
  List<UserModel> _all = [];
  List<UserModel> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _roleFilter = 'All';

  // Filter options matching exact DB role strings
  static const _roleOptions = [
    'All',
    'warehouse_manager',
    'retailer',
    'driver',
    '3pl_manager',
    'admin',
  ];
  static const _roleLabels = {
    'All': 'All roles',
    'warehouse_manager': 'Warehouse Manager',
    'retailer': 'Retailer',
    'driver': 'Driver',
    '3pl_manager': 'Logistics Manager',
    'admin': 'Admin',
  };
  static const _roleColors = {
    'warehouse_manager': Color(0xFF185FA5),
    'retailer': Color(0xFF534AB7),
    'driver': Color(0xFF854F0B),
    '3pl_manager': Color(0xFF0F6E56),
    'admin': Color(0xFFA32D2D),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await _svc.getAllUsers();
      setState(() {
        _all = users;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((u) {
        final matchSearch =
            _search.isEmpty ||
            u.fullName.toLowerCase().contains(_search.toLowerCase()) ||
            u.email.toLowerCase().contains(_search.toLowerCase());
        final matchRole = _roleFilter == 'All' || u.role == _roleFilter;
        return matchSearch && matchRole;
      }).toList();
    });
  }

  Future<void> _openForm({UserModel? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UserFormSheet(
        existing: existing,
        onSubmit:
            ({
              required firstName,
              required lastName,
              required email,
              required phone,
              required role,
              required bool priorityStatus,
              String? userId,
            }) async {
              if (userId != null) {
                await _svc.updateUser(
                  userId: userId,
                  firstName: firstName,
                  lastName: lastName,
                  phone: phone,
                  role: role,
                  priorityStatus: priorityStatus,
                );
              } else {
                await _svc.createUser(
                  firstName: firstName,
                  lastName: lastName,
                  email: email,
                  phone: phone,
                  role: role,
                  priorityStatus: priorityStatus,
                );
              }
            },
      ),
    );
    if (result == true) {
      _load();
      _snack(existing != null ? 'User updated.' : 'Account created.');
    }
  }

  Future<void> _toggleStatus(UserModel u) async {
    final activate = !u.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${activate ? 'Activate' : 'Deactivate'} account?'),
        content: Text(
          '${activate ? 'Activate' : 'Deactivate'} ${u.fullName}\'s account?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: activate
                  ? Colors.green.shade600
                  : Colors.red.shade600,
            ),
            child: Text(
              activate ? 'Activate' : 'Deactivate',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _svc.toggleUserStatus(u.id, activate);
      _load();
      _snack('${u.fullName} ${activate ? 'activated' : 'deactivated'}.');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = _roleColors[role] ?? Colors.grey;
    final label = _roleLabels[role] ?? role;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _all.where((u) => u.isActive).length;
    final inactiveCount = _all.where((u) => !u.isActive).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: Image.asset(
          'assets/images/nestle_logo.png',
          height: 50,
          fit: BoxFit.contain,
        ),
        actions: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE2E8F0),
            radius: 18,
            child: Icon(Icons.person, color: Colors.black54, size: 20),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF0056B3),
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text(
          'New user',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                // Search
                TextField(
                  onChanged: (v) {
                    _search = v;
                    _applyFilters();
                  },
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Role filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roleOptions.map((r) {
                      final selected = _roleFilter == r;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _roleFilter = r);
                            _applyFilters();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF0056B3)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF0056B3)
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _roleLabels[r] ?? r,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Stats row ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} user${_filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$activeCount active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$inactiveCount inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── User list ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final u = _filtered[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFE6EFFF),
                              child: Text(
                                u.firstName.isNotEmpty
                                    ? u.firstName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: Color(0xFF0056B3),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  u.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: u.isActive
                                        ? Colors.green
                                        : Colors.red.shade300,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  u.email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _roleBadge(u.role),
                                    if (u.priorityStatus) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAEEDA),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 10,
                                              color: Color(0xFFD4A017),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Priority',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: const Color(0xFF854F0B),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Direct toggle switch
                                Transform.scale(
                                  scale: 0.85,
                                  child: Switch(
                                    value: u.isActive,
                                    activeColor: Colors.green,
                                    onChanged: (_) => _toggleStatus(u),
                                  ),
                                ),
                                // Edit button
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  onPressed: () => _openForm(existing: u),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
