import 'package:flutter_test/flutter_test.dart';
import 'package:yesbut/models/analysis.dart';

void main() {
  test('severity parsing is forgiving', () {
    expect(SeverityX.parse('red_flag'), Severity.redFlag);
    expect(SeverityX.parse('Heads up'), Severity.headsUp);
    expect(SeverityX.parse('good-news'), Severity.goodNews);
    expect(SeverityX.parse(null), Severity.headsUp);
  });
}
