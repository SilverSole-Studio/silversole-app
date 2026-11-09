import 'dart:math';

import 'package:silversole/core/friends/friend_rules.dart';

// Suggested nicknames for the first-login 「取個名字」 page. A name is built
// from hand-picked parts, so every one reads like something a person would
// call themselves: warm, easy to read aloud, nothing a stranger could take as
// an insult. No slang or internet speak (the people using it are mostly over
// 60), no names that sound like staff (see `friend_rules.dart`).
//
// Two shapes:
//   A. 「<愛散步的><阿桃>」 — a little description plus a name, an animal or a
//      friendly title.
//   B. 「<菜園><小農夫>」 — a theme plus a role; each theme only pairs with
//      roles that make sense for it (no 「海邊小農夫」).
//
// The whole set is small enough (about two thousand) to build once and pick
// from by index. `test/friends/nickname_generator_test.dart` runs every single
// combination through [validateNickname], so a bad word added here fails the
// test instead of reaching a user.

/// Shape A, first half: always ends in 的.
const kNicknameDescriptions = [
  '愛散步的',
  '愛唱歌的',
  '愛種菜的',
  '愛喝茶的',
  '愛下棋的',
  '愛跳舞的',
  '愛旅行的',
  '愛看花的',
  '愛拍照的',
  '愛運動的',
  '愛曬太陽的',
  '愛吃水果的',
  '早起的',
  '慢慢走的',
  '笑咪咪的',
  '笑呵呵的',
  '開心的',
  '快樂的',
  '悠閒的',
  '勤勞的',
  '樂觀的',
  '精神好的',
  '好心情的',
  '腳步輕的',
  '很健康的',
];

/// Shape A, second half: first names, small animals and friendly titles.
const kNicknameCompanions = [
  // 阿 + one character, as people call each other.
  '阿桃', '阿花', '阿福', '阿樂', '阿珠', '阿香', '阿明', '阿財', '阿美', '阿嬌',
  // Titles
  '阿伯', '阿姨', '阿公', '阿嬤', '大哥', '大姐', '鄰居', '夥伴', '旅人', '隊長',
  '達人',
  // Small animals (Taiwan has all of them)
  '小松鼠', '小白鷺', '小蜜蜂', '小蝴蝶', '小麻雀', '小橘貓', '小黑狗', '小烏龜',
  '小白兔', '小山羊', '小青蛙', '螢火蟲',
  // Fruit and plants
  '柚子', '芭樂', '蓮霧', '木瓜', '楊桃', '枇杷', '茶花',
];

/// Shape B: [themes] and [roles] that go together. Each group is a full
/// cross product.
class NicknameGroup {
  const NicknameGroup(this.themes, this.roles);

  final List<String> themes;
  final List<String> roles;

  int get size => themes.length * roles.length;
}

const kNicknameGroups = [
  // Walking and exercise
  NicknameGroup(
    ['健走', '散步', '晨操', '太極', '爬山', '慢跑', '騎車', '體操', '早操'],
    ['小隊長', '達人', '高手', '隊員', '先鋒', '小英雄', '好夥伴', '大王', '好手'],
  ),
  // Gardening
  NicknameGroup(
    ['菜園', '花園', '果園', '茶園', '田園', '陽台', '農場', '盆栽'],
    ['小農夫', '園丁', '達人', '高手', '小管家', '主人', '好幫手', '小專家'],
  ),
  // Mood and weather
  NicknameGroup(
    ['早起', '晚霞', '陽光', '微風', '好心情', '開心', '笑臉', '福氣', '春天'],
    ['小太陽', '夥伴', '代表', '大使', '達人', '好朋友', '小幫手', '使者', '之友'],
  ),
  // Hobbies
  NicknameGroup(
    ['唱歌', '下棋', '跳舞', '拍照', '旅行', '書法', '釣魚', '賞鳥', '看花', '畫畫'],
    ['高手', '達人', '愛好者', '小專家', '好手', '迷', '老手', '同好'],
  ),
  // Food and drink
  NicknameGroup(
    ['茶香', '咖啡', '水果', '點心', '古早味', '米香', '豆花', '蔬菜'],
    ['達人', '小行家', '愛好者', '老饕', '好朋友', '小廚師', '同好'],
  ),
  // Neighbourhood
  NicknameGroup(
    ['社區', '巷口', '老街', '公園', '河邊', '街角', '山腳', '河堤'],
    ['好鄰居', '小幫手', '小管家', '好朋友', '常客', '志工', '代表', '大使'],
  ),
];

/// Every name the generator can produce, in a fixed order. Exposed for the
/// tests; the generator itself uses the same list.
List<String> allNicknameSuggestions() => _all ??= _build();

List<String>? _all;

List<String> _build() {
  final names = <String>{
    for (final d in kNicknameDescriptions)
      for (final c in kNicknameCompanions) '$d$c',
    for (final g in kNicknameGroups)
      for (final t in g.themes)
        for (final r in g.roles) '$t$r',
  };
  return List.unmodifiable(names);
}

/// What is offered if a name never passes [validateNickname] (cannot happen
/// with the lists above; kept so a bad edit still gives the user something).
const kFallbackNickname = '散步小隊長';

/// Hands out suggested nicknames one at a time. Not unique across users: a
/// nickname is only a label, friends are told apart by friend code.
class NicknameGenerator {
  NicknameGenerator([Random? random]) : _random = random ?? Random();

  final Random _random;

  /// A fresh suggestion that passes [validateNickname] and is not [not] (the
  /// one on screen now, so the dice always changes something).
  String next({String? not}) {
    final pool = allNicknameSuggestions();
    for (var i = 0; i < 20; i++) {
      final name = pool[_random.nextInt(pool.length)];
      if (name != not && validateNickname(name) == null) return name;
    }
    return kFallbackNickname;
  }
}
