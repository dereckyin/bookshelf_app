import 'package:bookshelf_app/models/book_condition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookCondition has five ranks with 全新 as default', () {
    expect(BookCondition.all, [
      '全新',
      '近全新',
      '良好',
      '普通',
      '差強人意',
    ]);
    expect(BookCondition.defaultValue, '全新');
    expect(BookCondition.all, contains(BookCondition.defaultValue));
  });
}
