/// 讀冊現行書況分級（與 my_app／vision 一致）
class BookCondition {
  BookCondition._();

  static const String brandNew = '全新';
  static const String likeNew = '近全新';
  static const String good = '良好';
  static const String fair = '普通';
  static const String poor = '差強人意';

  static const String defaultValue = brandNew;

  static const List<String> all = [
    brandNew,
    likeNew,
    good,
    fair,
    poor,
  ];
}
