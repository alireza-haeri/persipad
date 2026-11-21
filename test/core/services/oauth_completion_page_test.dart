import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/backups/oauth_completion_page.dart';

void main() {
  const persian = OAuthCompletionText(
    receivedTitle: 'پاسخ دریافت شد',
    receivedDetail: 'به برنامه برگرد',
    deniedTitle: 'ورود کامل نشد',
    deniedDetail: 'دوباره تلاش کن',
    close: 'بستن صفحه',
    returnToApp: 'بازگشت به برنامه',
    help: 'از دکمه بازگشت استفاده کن',
    isRtl: true,
  );

  test('renders localized responsive RTL page and a package-scoped Android intent', () {
    final page = OAuthCompletionPage.render(
      authorizationReceived: true,
      text: persian,
      androidPackage: 'com.tc.writestory.community',
    );
    expect(page, contains('name="viewport"'));
    expect(page, contains('dir="rtl"'));
    expect(page, contains('پاسخ دریافت شد'));
    expect(page, contains('بازگشت به برنامه'));
    expect(
      page,
      contains(
        'intent://oauth-return#Intent;scheme=com.tc.writestory.community;package=com.tc.writestory.community;end',
      ),
    );
    expect(page, isNot(contains('window.close()')));
    expect(page, contains('از دکمه بازگشت'));
  });

  test('denial uses translated failure and desktop includes manual fallback', () {
    final page = OAuthCompletionPage.render(authorizationReceived: false, text: persian);
    expect(page, contains('ورود کامل نشد'));
    expect(page, contains('دوباره تلاش کن'));
    expect(page, isNot(contains('پاسخ دریافت شد')));
    expect(page, contains('window.close()'));
    expect(page, contains('از دکمه بازگشت'));
  });

  test('invalid package cannot inject markup into the page', () {
    final page = OAuthCompletionPage.render(authorizationReceived: true, text: persian, androidPackage: 'bad"<script>');
    expect(page, isNot(contains('bad"<script>')));
    expect(page, contains('window.close()'));
  });
}
