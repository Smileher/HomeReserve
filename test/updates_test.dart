import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_reserve/updates.dart';

Map<String, dynamic> release(String tag) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'assets': [
    for (final name in [
      'HomeReserve-android-arm64.apk',
      'HomeReserve-windows-x64.zip',
      'HomeReserve-macos-arm64.dmg',
    ])
      {
        'name': name,
        'browser_download_url':
            'https://github.com/Smileher/HomeReserve/releases/download/$tag/$name',
      },
  ],
};

class UpdateTestClient extends Fake implements HttpClient {
  UpdateTestClient(this.payload, {this.status = 200, this.error});
  final Map<String, dynamic> payload;
  final int status;
  final Object? error;
  bool closed = false;
  Uri? requested;
  final headers = _Headers();
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    if (error != null) throw error!;
    return _Request(headers, _Response(payload, status));
  }

  @override
  void close({bool force = false}) => closed = true;
}

class _Headers extends Fake implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.headers, this.response);
  @override
  final HttpHeaders headers;
  final HttpClientResponse response;
  @override
  Future<HttpClientResponse> close() async => response;
}

class _Response extends Fake implements HttpClientResponse {
  _Response(this.payload, this.statusCode);
  final Map<String, dynamic> payload;
  @override
  final int statusCode;
  @override
  Future<T> fold<T>(T initialValue, T Function(T, List<int>) combine) {
    return Stream.value(utf8.encode(jsonEncode(payload)))
        .fold(initialValue, combine);
  }
}

void main() {
  test('更新版本按数字比较，不把较旧版本当作升级', () {
    expect(
      AppRelease.fromJson(release('v1.10.0')).isNewerThan('1.9.9'),
      isTrue,
    );
    expect(
      AppRelease.fromJson(release('v2.0.0')).isNewerThan('1.99.99'),
      isTrue,
    );
    expect(
      AppRelease.fromJson(release('v1.3.0')).isNewerThan('1.3.0'),
      isFalse,
    );
    expect(
      AppRelease.fromJson(release('v1.2.1')).isNewerThan('1.3.0'),
      isFalse,
    );
  });
  test('下载只接受对应平台的正式发布文件，缺失时保留发布页', () {
    final info = AppRelease.fromJson(release('v1.4.0'));
    expect(info.downloads['windows']!.path, endsWith('.zip'));
    expect(info.downloads['android']!.path, endsWith('.apk'));
    expect(info.downloads['macos']!.path, endsWith('.dmg'));
    final missing = release('v1.4.0')..['assets'] = [];
    final fallback = AppRelease.fromJson(missing);
    expect(fallback.downloads, isEmpty);
    expect(fallback.page.toString(), endsWith('/releases/tag/v1.4.0'));
    final forged = release('v1.4.0');
    (forged['assets'] as List).first['browser_download_url'] =
        'https://example.com/file.apk';
    expect(AppRelease.fromJson(forged).downloads['android'], isNull);
  });
  test('拒绝草稿、预发布和无效版本信息', () {
    for (final invalid in [
      release('v1.4.0')..['draft'] = true,
      release('v1.4.0')..['prerelease'] = true,
      release('v1.4.0-beta'),
      release('v1.4.0')..['assets'] = 'invalid',
      <String, dynamic>{},
    ]) {
      expect(() => AppRelease.fromJson(invalid), throwsFormatException);
    }
  });
  test('检查更新访问公开GitHub接口并关闭连接，不发送账本数据', () async {
    final client = UpdateTestClient(release('v1.4.0'));
    final result = await HttpOverrides.runZoned(
      checkLatestRelease,
      createHttpClient: (_) => client,
    );
    expect(result.version, '1.4.0');
    expect(
      client.requested.toString(),
      'https://api.github.com/repos/Smileher/HomeReserve/releases/latest',
    );
    expect(
      client.headers.values[HttpHeaders.userAgentHeader],
      'HomeReserve/$appVersion',
    );
    expect(client.closed, isTrue);
  });
  test('限流、离线和超时返回可理解的提示并释放连接', () async {
    for (final client in [
      UpdateTestClient({}, status: 403),
      UpdateTestClient({}, status: 500),
      UpdateTestClient({}, error: const SocketException('offline')),
      UpdateTestClient({}, error: TimeoutException('timeout')),
    ]) {
      await expectLater(
        HttpOverrides.runZoned(
          checkLatestRelease,
          createHttpClient: (_) => client,
        ),
        throwsFormatException,
      );
      expect(client.closed, isTrue);
    }
  });
}
