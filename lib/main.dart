import 'dart:async';

import 'dart:convert';

import 'directory_storage.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(

    url: 'https://bpyuomjjshgurkyeouht.supabase.co',

    publishableKey: 'sb_publishable_opFNxFlkbMzK_TIqbHHwKg_QeeTcin0',

  );

  runApp(const AcronymsApp());

}

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

  List<AcronymEntry> _communityEntries = [];

  Timer? _searchDebounce;

  String _query = '';

  String _selectedCategory = 'All';

@override

void initState() {

  super.initState();

  _loadSavedDirectory();

  _loadCommunityEntries();

}

Future<void> _loadCommunityEntries() async {

  try {

    final response = await Supabase.instance.client

        .from('approved_acronyms')

        .select('acronym, meaning, category, description')

        .order('created_at', ascending: false);

    final entries = response.map((item) {

      return AcronymEntry(

        item['acronym'] as String,

        item['meaning'] as String,

        item['category'] as String,

        item['description']?.toString() ?? '',

      );

    }).toList();

    if (!mounted) return;

    setState(() {

      _communityEntries = entries;

    });

  } catch (error) {

    debugPrint('Unable to load community acronyms: $error');

  }

}

  Future<void> _loadSavedDirectory() async {

    try {

      final source = await rootBundle.loadString('assets/acronyms.json');

      final official = _decodeEntries(source);

      final custom = await readDirectory(_savedCustomKey);

      final personal = custom == null ? <AcronymEntry>[] :

          _decodeEntries(custom).where((entry) => entry.category != 'MOD directory').toList();

      if (!mounted) return;

      setState(() {

        _directory

          ..clear()

          ..addAll(_uniqueEntries([...official, ...personal]));

      });

    } catch (error) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Unable to load acronym directory: $error')),

      );

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

  List<AcronymEntry> _uniqueEntries(List<AcronymEntry> entries) {

    final seen = <String>{};

    return entries.where((entry) => seen.add('${entry.shortName}|${entry.meaning}')).toList();

  }

List<AcronymEntry> get _results {

  final allEntries = _uniqueEntries([

    ..._directory,

    ..._communityEntries,

  ]);

  final query = _query.trim().toLowerCase();

  if (query.isEmpty) {

    return _selectedCategory == 'All'

        ? allEntries

        : allEntries

            .where((entry) => entry.category == _selectedCategory)

            .toList();

  }

  final matches = allEntries.where((entry) {

    if (_selectedCategory != 'All' &&

        entry.category != _selectedCategory) {

      return false;

    }

    return entry.shortName.toLowerCase().contains(query) ||

        entry.meaning.toLowerCase().contains(query) ||

        entry.category.toLowerCase().contains(query) ||

        entry.description.toLowerCase().contains(query);

  }).toList();

  final originalPositions = {

    for (var index = 0; index < allEntries.length; index++)

      allEntries[index]: index,

  };

  matches.sort((left, right) {

    final leftRank = _matchRank(left, query);

    final rightRank = _matchRank(right, query);

    if (leftRank != rightRank) {

      return leftRank.compareTo(rightRank);

    }

    final leftIsPersonal = left.category == 'MOD directory' ? 1 : 0;

    final rightIsPersonal = right.category == 'MOD directory' ? 1 : 0;

    return leftIsPersonal != rightIsPersonal

        ? leftIsPersonal.compareTo(rightIsPersonal)

        : originalPositions[left]!.compareTo(originalPositions[right]!);

  });

  return matches;

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

      floatingActionButton: Column(

  mainAxisSize: MainAxisSize.min,

  crossAxisAlignment: CrossAxisAlignment.end,

  children: [

    FloatingActionButton.extended(

  heroTag: 'submitAcronym',

  onPressed: _showSubmissionDialog,

  icon: const Icon(Icons.cloud_upload_outlined),

  label: const Text('Submit an Acronym'),

),

  ],

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

  Future<void> _showSubmissionDialog() async {

  final formKey = GlobalKey<FormState>();

  var acronym = '';

  var meaning = '';

  var category = 'Other';

  var description = '';

  String? turnstileToken;

  await showDialog<void>(

    context: context,

    builder: (dialogContext) => AlertDialog(

      title: const Text('Submit an Acronym'),

      content: SizedBox(

        width: 420,

        child: SingleChildScrollView(

          child: Form(

            key: formKey,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                const Text(

                  'Suggest a new acronym for administrator approval. '

                  'Only submit information approved for public release.',

                ),

                const SizedBox(height: 18),

                TextFormField(

                  decoration: const InputDecoration(

                    labelText: 'Acronym',

                    hintText: 'e.g. MEI',

                  ),

                  textCapitalization: TextCapitalization.characters,

                  maxLength: 30,

                  validator: (value) =>

                      value == null || value.trim().isEmpty

                          ? 'Enter an acronym'

                          : null,

                  onSaved: (value) => acronym = value?.trim() ?? '',

                ),

                const SizedBox(height: 12),

                TextFormField(

                  decoration: const InputDecoration(

                    labelText: 'Meaning',

                    hintText: 'What does it stand for?',

                  ),

                  maxLength: 200,

                  validator: (value) =>

                      value == null || value.trim().isEmpty

                          ? 'Enter the meaning'

                          : null,

                  onSaved: (value) => meaning = value?.trim() ?? '',

                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(

                  initialValue: category,

                  decoration: const InputDecoration(

                    labelText: 'Category',

                  ),

                  items: _categories

                      .map(

                        (item) => DropdownMenuItem(

                          value: item,

                          child: Text(item),

                        ),

                      )

                      .toList(),

                  onChanged: (value) => category = value ?? 'Other',

                  onSaved: (value) => category = value ?? 'Other',

                ),

                const SizedBox(height: 12),

                TextFormField(

                  decoration: const InputDecoration(

                    labelText: 'Description (optional)',

                    hintText: 'Explain what the acronym refers to',

                    alignLabelWithHint: true,

                  ),

                  minLines: 2,

                  maxLines: 4,

                  maxLength: 500,

                  onSaved: (value) =>

                      description = value?.trim() ?? '',

                ),

              const SizedBox(height: 16),

                CloudflareTurnstile(

                  siteKey: '0x4AAAAAAFq-AjUiS1nkhyX7',

                  onTokenReceived: (token) {

  turnstileToken = token;

  debugPrint('Turnstile verification completed');

},

                ),

              ],

            ),

          ),

        ),

      ),

      actions: [

        TextButton(

          onPressed: () => Navigator.pop(dialogContext),

          child: const Text('Cancel'),

        ),

FilledButton(

  onPressed: () async {

    if (!formKey.currentState!.validate()) return;

    if (turnstileToken == null || turnstileToken!.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Please complete Cloudflare verification first.'),

        ),

      );

      return;

    }

    formKey.currentState!.save();

    try {

      await _submitAcronym(

        acronym: acronym,

        meaning: meaning,

        category: category,

        description: description,

        turnstileToken: turnstileToken!,

      );

      if (!mounted || !dialogContext.mounted) return;

      Navigator.pop(dialogContext);

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text(

            'Thank you! Your acronym has been submitted and is awaiting administrator approval.',

          ),

        ),

      );

    } catch (error) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text('Submission failed: $error'),

        ),

      );

    }

  },

  child: const Text('Submit for Approval'),
),
      ],

    ),

  );

}

Future<void> _submitAcronym({

  required String acronym,

  required String meaning,

  required String category,

  required String description,

  required String turnstileToken,

}) async {

  final response = await Supabase.instance.client.functions.invoke(

    'submit_acronym',

    body: {

      'acronym': acronym,

      'meaning': meaning,

      'category': category,

      'description': description,

      'turnstileToken': turnstileToken,

    },

  );

  if (response.status != 200 ||
    response.data is! Map ||
    response.data['message'] !=
        'Acronym submitted successfully. Awaiting approval.') {
  throw Exception('Submission was not accepted: ${response.data}');
}

debugPrint('Submission accepted and awaiting approval');

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

                      onPressed: () async {

                        _searchDebounce?.cancel();

                        _searchController.clear();

                        setState(() => _query = '');

                      },

                      icon: const Icon(Icons.close_rounded),

                    ),

            ),

          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(

            initialValue: _selectedCategory,

            decoration: const InputDecoration(labelText: 'Filter category'),

            items: ['All', 'MOD directory', ..._categories]

                .map((category) => DropdownMenuItem(value: category, child: Text(category)))

                .toList(),

            onChanged: (value) => setState(() => _selectedCategory = value ?? 'All'),

          ),

          const SizedBox(height: 12),

          Text('Personal additions are saved on this device only. Shared submissions will be added later.',

              style: theme.textTheme.bodySmall),

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
