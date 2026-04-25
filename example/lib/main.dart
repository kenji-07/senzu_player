import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'player_page.dart';
import 'tv_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SenzuPlayer',
      debugShowCheckedModeBanner: false,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF4444),
          secondary: Color(0xFFFF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatelessWidget {
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SenzuPlayer – v2.0'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white10),
        ),
      ),
      body: FocusScope(
        autofocus: true,
        child: Column(
          children: [
            _TvListTile(
              title: 'TV Player',
              autofocus: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TVPlayer()),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            _TvListTile(
              title: 'Basic Player',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BPlayer()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvListTile extends StatefulWidget {
  const _TvListTile({
    required this.title,
    required this.onTap,
    this.autofocus = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TvListTile> createState() => _TvListTileState();
}

class _TvListTileState extends State<_TvListTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowDown) {
          node.nextFocus();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowUp) {
          node.previousFocus();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _focused ? Colors.white12 : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _focused ? const Color(0xFFFF4444) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: ListTile(
          title: Text(
            widget.title,
            style: TextStyle(
              color: _focused ? Colors.white : Colors.white70,
              fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: _focused ? const Color(0xFFFF4444) : Colors.white38,
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class BPlayer extends StatelessWidget {
  const BPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: PlayerPage(),
    );
  }
}

class TVPlayer extends StatelessWidget {
  const TVPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: TVPage(),
    );
  }
}
