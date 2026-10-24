import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_presentation.dart';

class AppMenuItem {
  const AppMenuItem(
    this.id,
    this.title,
    this.symbol, {
    this.destructive = false,
  });
  final String id, title, symbol;
  final bool destructive;
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'symbol': symbol,
    'destructive': destructive,
  };
}

/// Real UIMenu on iOS; the existing Flutter menu interaction elsewhere.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.label = 'Options',
  });
  final List<AppMenuItem> items;
  final ValueChanged<String> onSelected;
  final String label;
  @override
  Widget build(BuildContext context) => usesNativePresentation
      ? NativeToolbarButton(
          symbol: 'ellipsis',
          label: label,
          items: items,
          onSelected: onSelected,
        )
      : PopupMenuButton<String>(
          tooltip: label,
          icon: const Icon(Icons.more_horiz),
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final item in items)
              PopupMenuItem(
                value: item.id,
                child: Text(
                  item.title,
                  style: item.destructive
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
          ],
        );
}

class NativeToolbarButton extends StatefulWidget {
  const NativeToolbarButton({
    super.key,
    required this.symbol,
    required this.label,
    this.onPressed,
    this.items = const [],
    this.onSelected,
    this.glass = true,
    this.symbolSize,
  });
  final String symbol, label;
  final VoidCallback? onPressed;
  final List<AppMenuItem> items;
  final ValueChanged<String>? onSelected;
  final bool glass;
  final double? symbolSize;
  @override
  State<NativeToolbarButton> createState() => _NativeToolbarButtonState();
}

class _NativeToolbarButtonState extends State<NativeToolbarButton> {
  MethodChannel? channel;
  Map<String, dynamic> get config => {
    'symbol': widget.symbol,
    'label': widget.label,
    'glass': widget.glass,
    if (widget.symbolSize != null) 'symbolSize': widget.symbolSize,
    'enabled':
        widget.onPressed != null ||
        (widget.items.isNotEmpty && widget.onSelected != null),
    'dark': Theme.of(context).brightness == Brightness.dark,
    'items': [for (final item in widget.items) item.toMap()],
  };
  void configure() {
    channel?.invokeMethod<void>('configure', config);
  }

  @override
  void didUpdateWidget(NativeToolbarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    configure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    configure();
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: UiKitView(
      viewType: 'com.findez.app/toolbar-control',
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: config,
      onPlatformViewCreated: (id) {
        channel = MethodChannel('com.findez.app/toolbar-control/$id');
        channel!.setMethodCallHandler((call) async {
          if (!mounted || call.method != 'selected') return;
          if (call.arguments == '__press__') {
            widget.onPressed?.call();
          } else if (widget.items.any((item) => item.id == call.arguments)) {
            widget.onSelected?.call(call.arguments as String);
          }
        });
        configure();
      },
    ),
  );
}
