import 'dart:async';
import 'dart:convert';
import 'dart:io';

const appVersion = '1.3.1';
const releasesUrl = 'https://github.com/Smileher/HomeReserve/releases/latest';

class AppRelease {
  AppRelease._(this.version, this.page, this.downloads);
  final String version;
  final Uri page;
  final Map<String, Uri> downloads;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String ||
        !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag) ||
        json['draft'] == true ||
        json['prerelease'] == true) {
      throw const FormatException('GitHub 版本信息无效，请前往下载页查看');
    }
    final page = Uri.parse(
      'https://github.com/Smileher/HomeReserve/releases/tag/$tag',
    );
    const names = {
      'android': 'HomeReserve-android-arm64.apk',
      'windows': 'HomeReserve-windows-x64.zip',
      'macos': 'HomeReserve-macos-arm64.dmg',
    };
    final assets = json['assets'];
    if (assets != null && assets is! List) {
      throw const FormatException('GitHub 下载文件信息无效，请前往下载页查看');
    }
    final downloads = <String, Uri>{};
    for (final asset in assets as List? ?? const []) {
      if (asset is! Map) continue;
      for (final platform in names.entries) {
        if (asset['name'] != platform.value) continue;
        final expected = Uri.parse(
          'https://github.com/Smileher/HomeReserve/releases/download/$tag/${platform.value}',
        );
        if (asset['browser_download_url'] == expected.toString()) {
          downloads[platform.key] = expected;
        }
      }
    }
    return AppRelease._(tag.substring(1), page, downloads);
  }

  bool isNewerThan(String installed) {
    final latest = version.split('.').map(int.parse).toList();
    final current = installed.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (latest[i] != current[i]) return latest[i] > current[i];
    }
    return false;
  }
}

Future<AppRelease> checkLatestRelease() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client
        .getUrl(
          Uri.https(
            'api.github.com',
            '/repos/Smileher/HomeReserve/releases/latest',
          ),
        )
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'HomeReserve/$appVersion');
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const FormatException('GitHub 请求较频繁，请稍后重试或前往下载页');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw const FormatException('暂时无法获取版本信息，请稍后重试或前往下载页');
    }
    final bytes = await response
        .fold<List<int>>([], (bytes, chunk) {
          if (bytes.length + chunk.length > 1024 * 1024) {
            throw const FormatException('GitHub 版本信息过大，请前往下载页查看');
          }
          return bytes..addAll(chunk);
        })
        .timeout(const Duration(seconds: 12));
    final payload = jsonDecode(utf8.decode(bytes));
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('GitHub 版本信息无效，请前往下载页查看');
    }
    return AppRelease.fromJson(payload);
  } on TimeoutException {
    throw const FormatException('检查更新超时，请检查网络或前往下载页');
  } on SocketException {
    throw const FormatException('无法连接 GitHub，请检查网络或前往下载页');
  } on HandshakeException {
    throw const FormatException('无法建立安全连接，请检查网络或前往下载页');
  } finally {
    client.close(force: true);
  }
}
