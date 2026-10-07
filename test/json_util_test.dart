import 'package:flutter_test/flutter_test.dart';
import 'package:xtreamcodeapp/core/json_util.dart';
import 'package:xtreamcodeapp/services/xtream_service.dart';

void main() {
  test('asInt accepts ints, doubles and numeric strings', () {
    expect(asInt(12), 12);
    expect(asInt('34'), 34);
    expect(asInt('12.9'), 13);
    expect(asInt(null), isNull);
  });

  test('asBool understands Xtream status flags', () {
    expect(asBool(1), isTrue);
    expect(asBool('Active'), isTrue);
    expect(asBool('0'), isFalse);
  });

  test('normalizeServer adds scheme and strips slash', () {
    expect(
      XtreamService.normalizeServer('portal.example:8080/'),
      'http://portal.example:8080',
    );
    expect(
      XtreamService.normalizeServer('https://portal.example:443'),
      'https://portal.example:443',
    );
  });
}
