import 'package:storypad/core/databases/adapters/base_db_adapter.dart';
import 'package:storypad/core/databases/models/base_db_model.dart';
import 'package:storypad/core/repositories/backup_repository.dart';

class JsonTablesToModelService {
  // {
  //   "stories": [ story1, story2 ],
  //   "todos": [ todo1, todo2 ]
  // }
  /// Decodes [tables] against [databases], defaulting to the real table set.
  ///
  /// The parameter exists so merge tests can decode against fake adapters — the
  /// alternative is opening ObjectBox, which a unit test cannot do.
  static Map<String, List<BaseDbModel>> decode(
    Map<String, dynamic> tables, {
    List<BaseDbAdapter>? databases,
  }) {
    Map<String, List<BaseDbModel>> maps = {};

    for (BaseDbAdapter db in databases ?? BackupRepository.databases) {
      dynamic contents = tables[db.tableName];
      if (contents is List) {
        maps[db.tableName] = _decodeContents(contents, db);
      }
    }

    return maps;
  }

  static List<T> _decodeContents<T extends BaseDbModel>(
    List contents,
    BaseDbAdapter<T> db,
  ) {
    List<T> items = [];

    for (dynamic json in contents) {
      if (json is Map<String, dynamic>) {
        T? item = db.modelFromJson(json);
        items.add(item);
      }
    }

    return items;
  }
}
