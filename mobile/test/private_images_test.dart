import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/private_image.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  const path = 'd4000000-0000-0000-0000-000000000003/Photo one.jpg';
  const source =
      'https://storage.test/storage/v1/object/public/item-images/$path';
  String? imagePath(String source) =>
      privateItemImagePath(source, storageOrigin: 'https://storage.test');
  String imageUrl(String source) =>
      privateItemImageUrl(source, storageOrigin: 'https://storage.test');
  Map<String, String>? imageHeaders(String source) =>
      privateItemImageHeaders(source, storageOrigin: 'https://storage.test');
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  test(
    'saved public and signed image locators require an authenticated API request',
    () {
      expect(imagePath(source), path);
      expect(
        imagePath("${source.replaceAll('/public/', '/sign/')}?token=old"),
        path,
      );
      final image = NetworkImage(
        imageUrl(source),
        headers: imageHeaders(source),
      );
      expect(Uri.parse(image.url).path, '/media/item-image');
      expect(Uri.parse(image.url).queryParameters['path'], path);
      expect(image.headers?['Authorization'], startsWith('Bearer '));
      expect(image.url, isNot(contains('Bearer')));
      expect(imageHeaders('https://foreign.test/image.jpg'), isNull);
      expect(
        imageUrl('https://foreign.test/image.jpg'),
        'https://foreign.test/image.jpg',
      );
    },
  );
  test(
    'images cannot reuse an earlier account cache key or credentials',
    () async {
      final first = NetworkImage(
        imageUrl(source),
        headers: imageHeaders(source),
      );
      await fixture.signIn('actor-b');
      final second = NetworkImage(
        imageUrl(source),
        headers: imageHeaders(source),
      );
      expect(second.url, isNot(first.url));
      expect(second.headers, isNot(first.headers));
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      final signedOut = NetworkImage(
        imageUrl(source),
        headers: imageHeaders(source),
      );
      expect(signedOut.headers, isEmpty);
      expect(signedOut.url, isNot(second.url));
      expect(Uri.parse(signedOut.url).path, '/media/item-image');
    },
  );
  test('traversal and unrelated buckets never receive user credentials', () {
    expect(
      imagePath(source.replaceAll('Photo one.jpg', '%252e%252e/secret.jpg')),
      isNull,
    );
    expect(
      imagePath(source.replaceAll('item-images', 'profile-photos')),
      isNull,
    );
    expect(imageHeaders('https://foreign.test/pixel'), isNull);
  });
  testWidgets(
    'image requests follow auth changes without showing an old account photo',
    (tester) async {
      await fixture.signIn('actor-a');
      await tester.pumpWidget(
        MaterialApp(
          home: PrivateImage(
            source,
            storageOrigin: 'https://storage.test',
            errorBuilder: (_, _, _) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first =
          tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      await tester.runAsync(() => fixture.signIn('actor-b'));
      await tester.pumpAndSettle();
      final next =
          tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(next.url, isNot(first.url));
      expect(next.headers?['Authorization'], startsWith('Bearer '));
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      await tester.pumpAndSettle();
      final out =
          tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(out.url, isNot(next.url));
      expect(out.headers, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
