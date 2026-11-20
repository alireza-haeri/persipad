import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/gallery_template_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Persian gallery translates all bundled templates while preserving IDs', () async {
    final english = await GalleryTemplateService.loadTemplates(languageCode: 'en');
    final persian = await GalleryTemplateService.loadTemplates(languageCode: 'fa');
    expect(persian.length, english.length);
    final enCategories = english.keys.toList();
    final faCategories = persian.keys.toList();
    for (var i = 0; i < enCategories.length; i++) {
      final enCategory = enCategories[i];
      final faCategory = faCategories[i];
      expect(faCategory.name, isNot(enCategory.name));
      expect(faCategory.description, isNot(enCategory.description));
      expect(faCategory.templates.length, enCategory.templates.length);
      for (var j = 0; j < enCategory.templates.length; j++) {
        final en = enCategory.templates[j];
        final fa = faCategory.templates[j];
        expect(fa.id, en.id);
        expect(fa.name, isNot(en.name));
        expect(fa.purpose, isNot(en.purpose));
        if (en.note != null) expect(fa.note, isNot(en.note));
        expect(fa.pages.length, en.pages.length);
        for (var k = 0; k < en.pages.length; k++) {
          expect(fa.pages[k].title, isNot(en.pages[k].title));
          expect(fa.pages[k].content, en.pages[k].content);
        }
      }
    }
  });

  test('other languages fall back to English', () async {
    final en = await GalleryTemplateService.loadTemplates(languageCode: 'en');
    final other = await GalleryTemplateService.loadTemplates(languageCode: 'fr');
    expect(other.keys.first.name, en.keys.first.name);
    expect(other.values.first.first.name, en.values.first.first.name);
  });
}
