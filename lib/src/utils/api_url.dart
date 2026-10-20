/// The PC running the server, set by scripts/run_dev.ps1 (--dart-define).
const devHost = String.fromEnvironment('DEV_HOST', defaultValue: '10.0.2.2');

/// Scheme, host and port of the server.
const apiOrigin = 'http://$devHost:5000';

/// A photo address the phone can load. Files the user uploaded
/// (`/uploads/...`) always point at the current server: the server used to
/// store the address the photo was sent through, which stops working when
/// the phone changes network. Web photos (Unsplash) pass through unchanged.
String? mediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.path.startsWith('/uploads/')) return '$apiOrigin${uri.path}';
  return raw;
}
