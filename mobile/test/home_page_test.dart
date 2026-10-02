import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/features/home/home_page.dart';
import 'package:mobile/features/home/home_overview.dart';
import 'package:mobile/features/shell/home_navigation.dart';
import 'package:mobile/features/chat/chat_page.dart';

class _HomeApi extends ApiClient {
  _HomeApi({this.fail = false}) : super(baseUrl: 'https://api.test');
  final bool fail;
  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    if (fail) throw StateError('offline');
    return SearchItemsResult(
      items: [
        _item('low', quantity: 2),
        _item('empty', quantity: 0),
        _item('loan', quantity: 5),
      ],
      parsed: const {},
    );
  }

  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async {
    if (fail) throw StateError('offline');
    return const ReviewQueueResult(items: [], pendingCount: 7);
  }

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async {
    if (fail) throw StateError('offline');
    return [
      {'id': 'space-1', 'name': 'Garage', 'item_count': 3},
      {'id': 'space-2', 'name': 'Empty shelf', 'item_count': 0},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async {
    if (fail) throw StateError('offline');
    return [
      {'item_id': 'loan'},
      {'item_id': 'loan'},
      {'item_id': 'teammate-item', 'from_teammate': true},
    ];
  }
}

InventoryItem _item(String name, {int quantity = 1}) => InventoryItem(
  itemId: name,
  name: name,
  category: 'Tools',
  quantity: quantity,
  location: 'Legacy location',
  createdAt: DateTime(2026, 9, 30),
);

Widget _overview({
  List<InventoryItem> items = const [],
  ValueChanged<String>? onAsk,
  VoidCallback? onReview,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: HomeOverview(
      items: items,
      spaces: const [
        {'id': 'shelf', 'name': 'Shelf', 'item_count': 0},
      ],
      pendingReviews: 123456,
      lowStock: 0,
      outOfStock: 0,
      lentOut: 0,
      onAsk: onAsk ?? (_) {},
      onChooseSpace: () {},
      onOpenReview: onReview ?? () {},
      onOpenLowStock: () {},
      onOpenOutOfStock: () {},
      onOpenCheckouts: () {},
      onOpenItem: (_) {},
      onOpenSpace: (_) {},
    ),
  ),
);

Widget _page(_HomeApi api, {ValueChanged<Map<String, dynamic>>? onSpace}) =>
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: HomePage(
          api: api,
          onOpenAsk: (_) {},
          onOpenReview: () {},
          onOpenCheckouts: () {},
          onOpenSpace: (space) async => onSpace?.call(space),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });
  setUp(() {
    InventoryCache.clear();
    SharedPreferences.setMockInitialValues({
      'low_stock_thresholds:signed-out': '{"low":3,"empty":3}',
    });
  });

  testWidgets(
    'decision counts use disjoint stock states and owned checkout identities',
    (tester) async {
      await tester.pumpWidget(_page(_HomeApi()));
      await tester.pumpAndSettle();
      final overview = tester.widget<HomeOverview>(find.byType(HomeOverview));
      expect(overview.pendingReviews, 7);
      expect(overview.lowStock, 1);
      expect(overview.outOfStock, 1);
      expect(overview.lentOut, 1);
      expect(find.text('No photo captures yet'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('Spaces come only from persistent records and open by exact ID', (
    tester,
  ) async {
    Map<String, dynamic>? opened;
    await tester.pumpWidget(
      _page(_HomeApi(), onSpace: (space) => opened = space),
    );
    await tester.pumpAndSettle();
    expect(find.text('Legacy location'), findsNothing);
    await tester.ensureVisible(find.text('Empty shelf'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empty shelf'));
    expect(opened?['id'], 'space-2');
    expect(opened?['item_count'], 0);
  });

  testWidgets(
    'failed reads show unknown counts and an error instead of false zeroes',
    (tester) async {
      await tester.pumpWidget(_page(_HomeApi(fail: true)));
      await tester.pumpAndSettle();
      final overview = tester.widget<HomeOverview>(find.byType(HomeOverview));
      expect(overview.pendingReviews, isNull);
      expect(overview.lowStock, isNull);
      expect(overview.outOfStock, isNull);
      expect(overview.lentOut, isNull);
      expect(
        find.text('Some details could not refresh. Pull down to try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Ask overrides themed borders and submits the entered question', (
    tester,
  ) async {
    String? asked;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
        ),
        home: Scaffold(
          body: HomeOverview(
            items: const [],
            spaces: const [],
            pendingReviews: 0,
            lowStock: 0,
            outOfStock: 0,
            lentOut: 0,
            onAsk: (question) => asked = question,
            onChooseSpace: () {},
            onOpenReview: () {},
            onOpenLowStock: () {},
            onOpenOutOfStock: () {},
            onOpenCheckouts: () {},
            onOpenItem: (_) {},
            onOpenSpace: (_) {},
          ),
        ),
      ),
    );
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.decoration?.enabledBorder?.borderSide, BorderSide.none);
    expect(input.decoration?.focusedBorder?.borderSide, BorderSide.none);
    await tester.enterText(find.byType(TextField), 'Where is my drill?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    expect(asked, 'Where is my drill?');
    expect(find.text('Where is my drill?'), findsNothing);
  });

  testWidgets(
    'rounded five-tab icon navigation reserves space below the page',
    (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.expand(key: Key('body')),
            bottomNavigationBar: HomeNavigation(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      );
      expect(
        tester.getBottomLeft(find.byKey(const Key('body'))).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(HomeNavigation)).dy),
      );
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.height, 56);
      expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
      expect(bar.backgroundColor, Colors.transparent);
      // The previous pill has an 18pt outer inset plus its 1pt border.
      expect(tester.getTopLeft(find.byType(NavigationBar)).dx, 19);
      final pill = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(HomeNavigation),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(pill.borderRadius, BorderRadius.circular(30));
      expect(bar.destinations.length, 5);
      expect(
        bar.destinations.map(
          (destination) => (destination as NavigationDestination).label,
        ),
        ['Home', 'Capture', 'Ask', 'Find', 'Profile'],
      );
      expect(find.byType(Icon), findsWidgets);
      expect(find.text('More'), findsNothing);
      expect(tester.getSize(find.byType(HomeNavigation)).height, lessThan(100));
      expect(
        tester.getSize(find.byKey(const Key('body'))).height,
        greaterThan(400),
      );
      await tester.tap(find.byType(NavigationDestination).at(1));
      expect(selected, 1);
      await tester.tap(find.byType(NavigationDestination).at(2));
      expect(selected, 2);
      await tester.tap(find.byType(NavigationDestination).at(3));
      expect(selected, 3);
      await tester.tap(find.byType(NavigationDestination).at(4));
      expect(selected, 4);
    },
  );

  testWidgets('Review and suggested questions have working destinations', (
    tester,
  ) async {
    var reviewed = false;
    String? asked;
    await tester.pumpWidget(
      _overview(
        items: [_item('Soldering iron')],
        onAsk: (question) => asked = question,
        onReview: () => reviewed = true,
      ),
    );
    await tester.tap(find.text('Soldering iron?'));
    expect(asked, 'Where is my Soldering iron?');
    await tester.tap(find.text('need identifying'));
    expect(reviewed, isTrue);
  });

  testWidgets(
    'embedded Ask composer stays near the reserved pill without overlay spacing',
    (tester) async {
      const speechChannel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        speechChannel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          speechChannel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ChatPage(api: _HomeApi(), inPageView: true),
            bottomNavigationBar: HomeNavigation(
              selectedIndex: 2,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      // The empty Ask screen has a repeating shimmer animation.
      await tester.pump(const Duration(milliseconds: 300));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 100));
      final gap =
          tester.getTopLeft(find.byType(HomeNavigation)).dy -
          tester.getBottomLeft(find.byType(TextField)).dy;
      // Includes the composer's internal padding, but not the old 110pt gap.
      expect(gap, inInclusiveRange(12, 40));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'narrow screens and large text keep the overview scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _overview(
          items: [_item('A very long part name for the suggestion chip')],
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Shelf'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo strip uses retained images and does not imply old captures are from today',
    (tester) async {
      final photo = InventoryItem(
        itemId: 'photo',
        name: 'Hex bolt',
        category: 'Supplies',
        quantity: 1,
        location: 'Shelf',
        imageUrl: 'https://api.test/item.jpg',
        createdAt: DateTime(2020),
      );
      await tester.pumpWidget(_overview(items: [photo, _item('No photo')]));
      await tester.pumpAndSettle();
      expect(find.text('Recent captures'), findsOneWidget);
      expect(find.text('Captured today'), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, photo.imageUrl);
      expect(find.text('Hex bolt'), findsOneWidget);
    },
  );
}
