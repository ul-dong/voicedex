import 'dart:convert';
import 'dart:io';

import 'package:voicedex/content/species.dart';

/// 테스트는 실제 데이터 파일을 그대로 읽는다.
WorldContent loadAnimals() => WorldContent.fromJson(
  jsonDecode(File('assets/data/animals.json').readAsStringSync())
      as Map<String, dynamic>,
);

Species byId(WorldContent w, String id) =>
    w.species.firstWhere((s) => s.id == id);
