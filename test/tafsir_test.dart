import 'package:flutter_test/flutter_test.dart';
import 'package:quran_learn_app/shared/services/tafsir.dart';

void main() {
  test(
      'strips tags, inserts a paragraph break per block element, decodes entities',
      () {
    final text = htmlToPlainText(
      '<h1>Title</h1><p>First &amp; second clause.</p>'
      '<p>Another paragraph with a &quot;quote&quot;.</p>',
    );

    expect(text, contains('Title'));
    expect(text, contains('First & second clause.'));
    expect(text, contains('Another paragraph with a "quote".'));
    expect(text, isNot(contains('<')));
    expect(text, isNot(contains('>')));

    final paragraphs = text.split('\n\n');
    expect(paragraphs.length, 3);
  });

  test('collapses stray whitespace and drops empty lines', () {
    final text = htmlToPlainText('<p>  padded  </p><p></p><p>next</p>');

    expect(text, 'padded\n\nnext');
  });
}
