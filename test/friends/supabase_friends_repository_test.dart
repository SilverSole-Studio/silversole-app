import 'package:flutter_test/flutter_test.dart';
import 'package:silversole/core/friends/supabase_friends_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('photos storage would not sign fall back to the mascot', () {
    const base = 'https://x.supabase.co/storage/v1';
    final urls = SupabaseFriendsRepository.signedPhotoUrls(const [
      SignedUrl(
        path: 'a/1.jpg',
        signedUrl: '$base/object/sign/avatars/a/1.jpg?token=t',
      ),
      // Refused: storage-api answers with a null signedURL (and sometimes a
      // null path), which the client turns into these.
      SignedUrl(path: 'b/2.jpg', signedUrl: '${base}null'),
      SignedUrl(path: '', signedUrl: '${base}null'),
    ]);
    expect(urls, {'a/1.jpg': '$base/object/sign/avatars/a/1.jpg?token=t'});
  });
}
