import 'dart:async';
import 'package:flutter/material.dart';
import '../config/debug_config.dart';
import '../services/giphy_service.dart';
import '../models/app_theme.dart';

class GiphyPicker extends StatefulWidget {
  final Function(String url) onGifSelected;
  final AppTheme appTheme;

  const GiphyPicker({
    super.key,
    required this.onGifSelected,
    required this.appTheme,
  });

  @override
  State<GiphyPicker> createState() => _GiphyPickerState();
}

class _GiphyPickerState extends State<GiphyPicker> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  List<GiphyResult> _results = [];
  bool _loading = false;
  bool _initial = true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _initial = true;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _initial = false;
    });
    final results = await GiphyService.search(query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: widget.appTheme.surface,
          border: Border(
            top: BorderSide(color: widget.appTheme.textSecondary.withValues(alpha: 0.3), width: 0.5),
          ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar GIFs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _initial = true;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: widget.appTheme.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              style: TextStyle(color: widget.appTheme.textPrimary, fontSize: 13),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.appTheme.primary,
                    ),
                  )
                : _initial
                    ? Center(
                        child: Text(
                          'Escribe para buscar GIFs',
                          style: TextStyle(
                            color: widget.appTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              'Sin resultados',
                              style: TextStyle(
                                color: widget.appTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1.2,
                            ),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final gif = _results[index];
                              return GestureDetector(
                                onTap: () {
                                  // ignore: avoid_print
                                      debugLog('[GIPHY-PICKER] onTap: index=$index, originalUrl=${gif.originalUrl}, url=${gif.url}');
                                  widget.onGifSelected(gif.originalUrl);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    gif.url,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
                                      if (wasSynchronouslyLoaded || frame != null) return child;
                                      return Container(
                                        color: widget.appTheme.background,
                                        child: Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: widget.appTheme.primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      color: widget.appTheme.background,
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 24,
                                        color: widget.appTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
