class RoleManager {
  final List<String> roles;

  RoleManager(this.roles);

  bool get isPrboOrHigher => roles.contains('PRBO');
  bool get isPo => roles.contains('PO');

  bool get isPrbo => roles.contains('PRBO');
  bool get isSdvbo => roles.contains('SDVBO');
  bool get isOperator => roles.contains('OPERATOR');
  bool get isAdmin => roles.contains('ADMIN');

  bool hasRole(String role) {
    return roles.contains(role);
  }

  @override
  String toString() {
    return 'RoleManager(roles: $roles)';
  }
}