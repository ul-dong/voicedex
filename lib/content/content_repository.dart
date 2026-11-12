import 'dart:convert';

import 'package:flutter/services.dart';

import 'species.dart';
import 'world_catalog.dart';

/// 월드 데이터를 에셋에서 읽는다.
class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, WorldContent> _cache = {};

  Future<WorldContent> load(WorldDef world) async {
    final cached = _cache[world.id];
    if (cached != null) return cached;
    final raw = await _bundle.loadString(world.dataAsset);
    final content = WorldContent.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache[world.id] = content;
    return content;
  }
}
