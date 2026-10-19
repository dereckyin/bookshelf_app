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

  test('fromProdRank maps A–E to Chinese labels', () {
    expect(BookCondition.fromProdRank('A'), '全新');
    expect(BookCondition.fromProdRank('b'), '近全新');
    expect(BookCondition.fromProdRank('C'), '良好');
    expect(BookCondition.fromProdRank('D'), '普通');
    expect(BookCondition.fromProdRank('E'), '差強人意');
    expect(BookCondition.fromProdRank('Z'), isNull);
    expect(BookCondition.fromProdRank(null), isNull);
  });
}
