class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://api.taaze.tw/api/v1';
  static const String searchPath = '/search/';

  static Uri searchUri(String query, {int pageSize = 5}) {
    return Uri.parse('$baseUrl$searchPath').replace(
      queryParameters: {
        'q': query,
        'page': '1',
        'pageSize': '$pageSize',
      },
    );
  }
}
