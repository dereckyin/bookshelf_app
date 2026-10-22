class ApiConfig {
  ApiConfig._();

  /// 讀冊公開查書
  static const String baseUrl = 'https://api.taaze.tw/api/v1';
  static const String searchPath = '/search/';
  static const String bookLookupPath = '/book/lookup';

  /// 冊格子 account／social（與網站相同的群組 Bearer）
  static const String accountBaseUrl = 'https://account.wecollect.fun';
  static const String socialBaseUrl = 'https://wecollectfun.taaze.tw/social';
  static const String bearerToken =
      'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJncm91cF9jb2RlIjoid2Vjb2xsZWN0ZnVuIiwiZ3JvdXBfbmFtZSI6IuWGiuagvOWtkCIsImdyb3VwX3N1dWlkIjoiVmZ3MlVwUDlUanY1QTMzVTNVb00iLCJtYW5hZ2VyX3N1dWlkIjoic0lGQVlkVHdhR09KbHpZbFh6d3ciLCJpYXQiOjE3NjA0NTA2NjEsImV4cCI6MjUzODA1MDY2MSwiYXVkIjoiVGFhemUgQWNjb3VudCIsImlzcyI6ImF1dGhvcml6YXRpb24tbWFuYWdlci1jZW50ZXIiLCJzdWIiOiJCZWFyZXIgVG9rZW4ifQ.FFT-L1WBhmZC2aHv3wRfJs8L9zI5pLq2Ic8hgpr6tnIelSXNt6OB5Axo-eACEn0UOwkaSg-nlSwkTQZmt-3vIQ';

  static const String deviceCodePrefix = 'wecollect-bookshelf:';

  /// 網頁授權頁（App 開瀏覽器登入後 deep link 回呼）
  static const String webBaseUrl = 'https://wecollect.fun';
  static const String bookshelfLinkPath = '/user/bookshelf-link';
  static const String appAuthScheme = 'wecollect-bookshelf';
  static const String appAuthHost = 'auth';

  static Uri bookshelfLinkUri({bool returnToApp = true}) {
    return Uri.parse('$webBaseUrl$bookshelfLinkPath').replace(
      queryParameters: returnToApp ? const {'return': 'app'} : null,
    );
  }

  /// wecollect-bookshelf://auth?code=XXXX
  static String? deviceCodeFromAuthUri(Uri uri) {
    if (uri.scheme != appAuthScheme) return null;
    if (uri.host != appAuthHost) return null;
    final code = uri.queryParameters['code']?.trim() ?? '';
    return code.isEmpty ? null : code;
  }

  static Uri searchUri(String query, {int pageSize = 5}) {
    return Uri.parse('$baseUrl$searchPath').replace(
      queryParameters: {
        'q': query,
        'page': '1',
        'pageSize': '$pageSize',
      },
    );
  }

  static Uri bookLookupUri(String barcode) {
    return Uri.parse('$baseUrl$bookLookupPath').replace(
      queryParameters: {'barcode': barcode},
    );
  }

  static Uri accountUri(String path) => Uri.parse('$accountBaseUrl$path');

  static Uri socialUri(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$socialBaseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  static Map<String, String> get jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearerToken',
      };
}
