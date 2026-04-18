export function can(user, permission) {
  return Array.isArray(user?.permissions) && user.permissions.includes(permission);
}

export function canAny(user, ...permissions) {
  return permissions.some((p) => can(user, p));
}
