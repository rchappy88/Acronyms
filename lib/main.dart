import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'directory_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

void main() => runApp(const AcronymsApp());

class AcronymsApp extends StatelessWidget {
  const AcronymsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17202A);
    return MaterialApp(
      title: 'Acronyms',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7490),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        textTheme: const TextTheme(
          displaySmall: TextStyle(color: ink, fontSize: 42, fontWeight: FontWeight.w800),
          headlineSmall: TextStyle(color: ink, fontWeight: FontWeight.w800),
          bodyLarge: TextStyle(color: Color(0xFF53616A), height: 1.4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
      ),
      home: const AcronymSearchPage(),
    );
  }
}

class AcronymEntry {
  const AcronymEntry(this.shortName, this.meaning, this.category, [this.description = '']);

  final String shortName;
  final String meaning;
  final String category;
  final String description;
}

const acronymDirectory = [
  AcronymEntry('API', 'Application Programming Interface', 'Technology'),
  AcronymEntry('ASAP', 'As Soon As Possible', 'Everyday'),
  AcronymEntry('CPU', 'Central Processing Unit', 'Technology'),
  AcronymEntry('ETA', 'Estimated Time of Arrival', 'Everyday'),
  AcronymEntry('FAQ', 'Frequently Asked Questions', 'Everyday'),
  AcronymEntry('HTML', 'HyperText Markup Language', 'Technology'),
  AcronymEntry('NASA', 'National Aeronautics and Space Administration', 'Science'),
  AcronymEntry('PDF', 'Portable Document Format', 'Technology'),
  AcronymEntry('RAM', 'Random Access Memory', 'Technology'),
  AcronymEntry('RSVP', 'Repondez s il vous plait', 'Everyday'),
  AcronymEntry('URL', 'Uniform Resource Locator', 'Technology'),
  AcronymEntry('WWW', 'World Wide Web', 'Technology'),
];

class AcronymSearchPage extends StatefulWidget {
  const AcronymSearchPage({super.key});

  @override
  State<AcronymSearchPage> createState() => _AcronymSearchPageState();
}

class _AcronymSearchPageState extends State<AcronymSearchPage> {
  static const _savedDirectoryKey = 'saved_acronym_directory_v2';
  static const _savedCustomKey = 'saved_custom_acronyms_v1';
  static const _categories = [
    'REME',
    'RLC',
    'Royal Engineers',
    'Med Regt',
    'AGC',
    'MI',
    'Science',
    'Other',
  ];
  final _searchController = TextEditingController();
  final _directory = [...acronymDirectory];
  Timer? _searchDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadSavedDirectory();
  }

  Future<void> _loadSavedDirectory() async {
    final saved = await readDirectory(_savedDirectoryKey);
    final custom = await readDirectory(_savedCustomKey);
    final customEntries = custom == null ? <AcronymEntry>[] : _decodeEntries(custom);
    if (saved != null) {
      final restored = _decodeEntries(saved);
      if (restored.isNotEmpty && mounted) {
        setState(() {
          _directory
            ..clear()
            ..addAll(_uniqueEntries([...restored, ...customEntries]));
        });
        return;
      }
    }
    await _loadDocument();
    if (customEntries.isNotEmpty && mounted) {
      setState(() => _directory.addAll(_uniqueEntries(customEntries)));
      await _saveDirectory();
    }
  }

  List<AcronymEntry> _decodeEntries(String encoded) {
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map((item) => AcronymEntry(
              item['shortName'] as String,
              item['meaning'] as String,
              item['category'] as String,
              item['description']?.toString() ?? '',
            ))
        .toList();
  }

  Future<void> _loadDocument() async {
    final bytes = await rootBundle.load('assets/acronyms_mod.docx');
    final archive = ZipDecoder().decodeBytes(bytes.buffer.asUint8List());
    final document = archive.findFile('word/document.xml');
    if (document == null) return;

    final xml = XmlDocument.parse(utf8.decode(document.content as List<int>));
    final imported = <AcronymEntry>[];
    for (final paragraph in xml.descendants.whereType<XmlElement>().where((element) => element.name.local == 'p')) {
      final parts = <String>[];
      var current = StringBuffer();
      for (final element in paragraph.descendants.whereType<XmlElement>()) {
        if (element.name.local == 'tab' && element.parent is XmlElement && (element.parent! as XmlElement).name.local == 'r') {
          parts.add(current.toString());
          current = StringBuffer();
        } else if (element.name.local == 't') {
          current.write(element.innerText);
        }
      }
      parts.add(current.toString());
      imported.addAll(_parseParts(parts));
    }

    if (!mounted || imported.isEmpty) return;
    setState(() {
      _directory
        ..clear()
        ..addAll(_uniqueEntries(imported));
    });
    await _saveDirectory();
  }

  Future<void> _saveDirectory() async {
    final encoded = jsonEncode(_directory.map((entry) => {
          'shortName': entry.shortName,
          'meaning': entry.meaning,
          'category': entry.category,
          'description': entry.description,
        }).toList());
    await writeDirectory(_savedDirectoryKey, encoded);
  }

  Future<void> _saveCustomEntries() async {
    final custom = _directory.where((entry) => entry.category != 'MOD directory').toList();
    final encoded = jsonEncode(custom.map((entry) => {
          'shortName': entry.shortName,
          'meaning': entry.meaning,
          'category': entry.category,
          'description': entry.description,
        }).toList());
    await writeDirectory(_savedCustomKey, encoded);
  }

  String _clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  List<AcronymEntry> _parseParts(List<String> parts) {
    if (parts.length < 2) return [];
    final entries = <AcronymEntry>[];
    var shortName = _clean(parts.first);
    for (var index = 1; index < parts.length; index++) {
      final segment = _clean(parts[index]);
      if (index == parts.length - 1) {
        if (shortName.isNotEmpty && segment.isNotEmpty) {
          entries.add(AcronymEntry(shortName, segment, 'MOD directory'));
        }
        break;
      }

      final nextAcronym = RegExp(r"\s+([A-Z0-9][A-Z0-9&/().*\-']{1,})$").firstMatch(segment);
      if (nextAcronym == null) continue;
      final meaning = _clean(segment.substring(0, nextAcronym.start));
      if (shortName.isNotEmpty && meaning.isNotEmpty) {
        entries.add(AcronymEntry(shortName, meaning, 'MOD directory'));
      }
      shortName = nextAcronym.group(1)!;
    }
    return entries;
  }

  List<AcronymEntry> _uniqueEntries(List<AcronymEntry> entries) {
    final seen = <String>{};
    return entries.where((entry) => seen.add('${entry.shortName}|${entry.meaning}')).toList();
  }

  List<AcronymEntry> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _directory;
    final matches = _directory.where((entry) {
      return entry.shortName.toLowerCase().contains(query) ||
          entry.meaning.toLowerCase().contains(query) ||
          entry.category.toLowerCase().contains(query) ||
          entry.description.toLowerCase().contains(query);
    }).toList();
    final originalPositions = {
      for (var index = 0; index < _directory.length; index++) _directory[index]: index,
    };
    matches.sort((left, right) {
      final leftRank = _matchRank(left, query);
      final rightRank = _matchRank(right, query);
        if (leftRank != rightRank) return leftRank.compareTo(rightRank);
        final leftIsPersonal = left.category == 'MOD directory' ? 1 : 0;
        final rightIsPersonal = right.category == 'MOD directory' ? 1 : 0;
        return leftIsPersonal != rightIsPersonal
          ? leftIsPersonal.compareTo(rightIsPersonal)
          : originalPositions[left]!.compareTo(originalPositions[right]!);
    });
    return matches.take(10).toList();
  }

  int _matchRank(AcronymEntry entry, String query) {
    final acronym = entry.shortName.toLowerCase();
    if (acronym.startsWith(query)) return 0;
    if (acronym.contains(query)) return 1;
    return 2;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add acronym'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(theme)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: _results.isEmpty
                  ? SliverFillRemaining(hasScrollBody: false, child: _emptyState(theme))
                  : SliverList.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) => _resultTile(_results[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    final formKey = GlobalKey<FormState>();
    var shortName = '';
    var meaning = '';
    var category = 'Other';
    var description = '';

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add an acronym'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Acronym'),
                  onSaved: (value) => shortName = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter an acronym' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'What it stands for'),
                  onSaved: (value) => meaning = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter the meaning' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => category = value ?? 'Other',
                  onSaved: (value) => category = value ?? 'Other',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Explain what this acronym is or does',
                    alignLabelWithHint: true,
                  ),
                  onSaved: (value) => description = value?.trim() ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              setState(() {
                _directory.add(AcronymEntry(
                  shortName,
                  meaning,
                  category,
                  description,
                ));
              });
              _saveDirectory();
              _saveCustomEntries();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('ACRONYMS', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 26),
          Text('Find the words\nbehind the letters.', style: theme.textTheme.displaySmall),
          const SizedBox(height: 12),
          Text('Search a growing directory of common abbreviations.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _query = value);
              });
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search MOD Acronyms and Abbreviations',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${_results.length} ${_results.length == 1 ? 'result' : 'results'}',
            style: theme.textTheme.labelLarge?.copyWith(color: const Color(0xFF53616A)),
          ),
        ],
      ),
    );
  }

  Widget _resultTile(AcronymEntry entry) {
    final theme = Theme.of(context);
    final acronymWidth = MediaQuery.sizeOf(context).width < 500 ? 126.0 : 190.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAE8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: acronymWidth,
            child: Text(
              entry.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.meaning, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(entry.category.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, letterSpacing: 1.2)),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(entry.description, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit acronym',
            onPressed: () => _showEditDialog(entry),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(AcronymEntry entry) async {
    final formKey = GlobalKey<FormState>();
    var shortName = entry.shortName;
    var meaning = entry.meaning;
    var category = entry.category;
    var description = entry.description;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit acronym'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: entry.shortName,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Acronym'),
                  onSaved: (value) => shortName = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter an acronym' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: entry.meaning,
                  decoration: const InputDecoration(labelText: 'What it stands for'),
                  onSaved: (value) => meaning = value?.trim() ?? '',
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter the meaning' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categories.contains(entry.category) ? entry.category : 'Other',
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    ..._categories.map((item) => DropdownMenuItem(value: item, child: Text(item))),
                    if (!_categories.contains(entry.category))
                      DropdownMenuItem(value: entry.category, child: Text(entry.category)),
                  ],
                  onChanged: (value) => category = value ?? 'Other',
                  onSaved: (value) => category = value ?? 'Other',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: entry.description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Explain what this acronym is or does',
                    alignLabelWithHint: true,
                  ),
                  onSaved: (value) => description = value?.trim() ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              final index = _directory.indexOf(entry);
              if (index < 0) return;
              setState(() {
                _directory[index] = AcronymEntry(shortName, meaning, category, description);
              });
              _saveDirectory();
              _saveCustomEntries();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 54, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text('No acronym found', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Try a different word or abbreviation.', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
