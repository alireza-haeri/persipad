import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:storypad/core/objects/gallery_template_category_object.dart';
import 'package:storypad/core/objects/gallery_template_object.dart';
import 'package:storypad/gen/assets.gen.dart';
import 'package:yaml/yaml.dart';

class GalleryTemplateService {
  static Future<Map<GalleryTemplateCategoryObject, List<GalleryTemplateObject>>> loadTemplates({String languageCode = 'en'}) async {
    final Map<GalleryTemplateCategoryObject, List<GalleryTemplateObject>> templates = {};

    final Map<String, dynamic> persian = languageCode == 'fa'
        ? jsonDecode(await rootBundle.loadString('assets/template_translations/fa.json')) as Map<String, dynamic>
        : {};

    final List<String> yamlFiles = Assets.templates.values..sort((a, b) => a.compareTo(b));

    for (final String path in yamlFiles) {
      final String yamlString = await rootBundle.loadString(path);
      final dynamic yamlData = loadYaml(yamlString);

      final Map<String, dynamic> json = jsonDecode(jsonEncode(yamlData));
      if (json.containsKey('category')) {
        json['name'] = json['category'];
        json.remove('category');
      }

      final translation = persian[path.split('/').last] as Map<String, dynamic>?;
      if (translation != null) {
        json['name'] = translation['name'];
        json['description'] = translation['description'];
        final translatedTemplates = translation['templates'] as Map<String, dynamic>;
        for (final template in json['templates'] as List<dynamic>) {
          final localized = translatedTemplates[template['id']] as Map<String, dynamic>?;
          if (localized == null) continue;
          template['name'] = localized['name'];
          template['purpose'] = localized['purpose'];
          template['note'] = localized['note'];
          final pages = template['pages'] as List<dynamic>;
          final titles = localized['pages'] as List<dynamic>;
          for (var i = 0; i < pages.length && i < titles.length; i++) {
            pages[i]['title'] = titles[i];
          }
        }
      }

      final GalleryTemplateCategoryObject category = GalleryTemplateCategoryObject.fromJson(json);
      templates[category] = category.templates;
    }

    return templates;
  }
}
