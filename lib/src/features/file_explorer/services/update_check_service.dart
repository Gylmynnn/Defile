import 'dart:convert';
import 'dart:io';

/// Outcome of an update check against the GitHub releases of the project.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    this.latestVersion,
    this.releaseUrl,
    this.error,
  });

  /// Version the running app was built from (pubspec `version`).
  final String currentVersion;

  /// Latest published version, normalised (leading "v" stripped), or null
  /// when the check did not reach a usable release.
  final String? latestVersion;
  final String? releaseUrl;

  /// Human-readable reason when the check could not complete.
  final String? error;

  bool get succeeded => error == null;

  bool get hasUpdate {
    if (latestVersion == null) return false;
    return compareVersions(latestVersion!, currentVersion) > 0;
  }

  /// Compares dotted numeric versions ("1.2.3", "v1.2.3+4"). Build numbers
  /// after "+" are ignored — releases are keyed on the display version.
  static int compareVersions(String a, String b) {
    final List<int> left = _segments(a);
    final List<int> right = _segments(b);
    final int common = left.length < right.length
        ? left.length
        : right.length;
    for (int i = 0; i < common; i++) {
      if (left[i] != right[i]) return left[i].compareTo(right[i]);
    }
    return left.length.compareTo(right.length);
  }

  static List<int> _segments(String version) {
    final String core = version
        .trim()
        .replaceFirst(RegExp('^v', caseSensitive: false), '')
        .split('+')
        .first;
    return core
        .split('.')
        .map((String part) => int.tryParse(part) ?? 0)
        .toList();
  }
}

/// Queries the GitHub releases API for the newest Defile release.
class UpdateCheckService {
  static const String _apiUrl =
      'https://api.github.com/repos/Gylmynnn/Defile/releases/latest';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches the latest release and compares it against [currentVersion].
  /// Never throws — network/API failures surface as [UpdateCheckResult.error].
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = _timeout;
      final HttpClientRequest request = await client
          .getUrl(Uri.parse(_apiUrl))
          .timeout(_timeout);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      // GitHub rejects API calls without a User-Agent.
      request.headers.set(HttpHeaders.userAgentHeader, 'Defile-Update-Check');
      final HttpClientResponse response = await request.close().timeout(
        _timeout,
      );
      final String body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      if (response.statusCode != HttpStatus.ok) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          error: response.statusCode == HttpStatus.notFound
              ? 'no release published yet'
              : 'GitHub API returned HTTP ${response.statusCode}',
        );
      }

      final Map<String, dynamic> release =
          jsonDecode(body) as Map<String, dynamic>;
      final String tag = (release['tag_name'] as String? ?? '').trim();
      if (tag.isEmpty) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          error: 'latest release carries no version tag',
        );
      }

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: tag.replaceFirst(
          RegExp('^v', caseSensitive: false),
          '',
        ),
        releaseUrl: release['html_url'] as String?,
      );
    } catch (error) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        error: 'network unavailable ($error)',
      );
    } finally {
      client?.close(force: true);
    }
  }
}
