import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İlaç Bilgi Asistanı',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.teal.shade50,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      themeMode: _themeMode,
      home: IlacBilgiAsistani(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class IlacBilgiAsistani extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const IlacBilgiAsistani({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<IlacBilgiAsistani> createState() => _IlacBilgiAsistaniState();
}

class _IlacBilgiAsistaniState extends State<IlacBilgiAsistani> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  String _cevap = '';
  List<String> _history = [];
  List<String> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('search_history') ?? [];
      _favorites = prefs.getStringList('favorite_ilaclar') ?? [];
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_ilaclar', _favorites);
  }

  Future<void> _addQueryToHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];

    history.remove(query);
    history.insert(0, query);
    if (history.length > 20) history.removeLast();

    await prefs.setStringList('search_history', history);
    setState(() => _history = history);
  }

  Future<String> _getIlacBilgiFromGemini(String ilacAdi) async {
    const apiKey = 'AIzaSyAyHdI1Be2kepmqP7oIEin2FqZAtHjTxY4';
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                    "$ilacAdi adlı ilacın kullanım alanı, yan etkileri ve saklama koşulları nedir?"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'];
      return text;
    } else {
      return 'Bilgi alınamadı. Lütfen tekrar deneyin.';
    }
  }

  Future<void> _onSearch() async {
    final ilacAdi = _controller.text.trim();
    if (ilacAdi.isEmpty) return;

    setState(() => _cevap = 'Bilgi alınıyor...');
    final result = await _getIlacBilgiFromGemini(ilacAdi);
    setState(() => _cevap = result);
    await _addQueryToHistory(ilacAdi);
  }

  Future<void> _speak() async {
    await _flutterTts.setLanguage("tr-TR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(_cevap);
  }

  Future<void> _stop() async => _flutterTts.stop();

  void _toggleFavorite(String ilac) async {
    setState(() {
      if (_favorites.contains(ilac)) {
        _favorites.remove(ilac);
      } else {
        _favorites.add(ilac);
      }
    });
    await _saveFavorites();
  }

  bool _isFavorite(String ilac) => _favorites.contains(ilac);

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ilacAdi = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('💊 İlaç Bilgi Asistanı'),
        leadingWidth: 100,
        leading: Row(
          children: [
            IconButton(
              onPressed: widget.onToggleTheme,
              icon: Icon(widget.isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode),
            ),
            IconButton(
              onPressed: ilacAdi.isNotEmpty
                  ? () => _toggleFavorite(ilacAdi)
                  : null,
              icon: Icon(
                _isFavorite(ilacAdi)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'İlaç Adı Girin',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _onSearch(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    onPressed: _onSearch,
                    label: const Text('Bilgi Al'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _cevap.isNotEmpty ? _speak : null,
                  icon: const Icon(Icons.volume_up, size: 28),
                ),
                IconButton(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.grey[850]
                      : Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _cevap.isEmpty
                        ? 'İlaç bilgisi burada görünecek.'
                        : _cevap,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_favorites.isNotEmpty) ...[
              const Text('⭐ Favori İlaçlar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final ilac = _favorites[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _controller.text = ilac;
                          _onSearch();
                        },
                        icon: const Icon(Icons.medication),
                        label: Text(ilac),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade400,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_history.isNotEmpty) ...[
              const Text('📜 Geçmiş Sorgular',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final ilac = _history[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _controller.text = ilac;
                          _onSearch();
                        },
                        icon: const Icon(Icons.history),
                        label: Text(ilac),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
