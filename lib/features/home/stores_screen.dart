import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../state/location.dart';
import '../cart/cart_bar.dart';

/// قائمة المتاجر: حسب القسم، أو كل القريب، أو بحث.
class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key, this.storeTypeId, this.title, this.searchMode = false});

  final int? storeTypeId;
  final String? title;
  final bool searchMode;

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  String _sort = 'nearest';
  bool _openNow = false;

  final List<Store> _stores = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.searchMode) _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _page = 1;
    _hasMore = true;
    _stores.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading && _page > 1) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final at = await ref.read(browseLocationProvider.future);
      final page = await ref.read(repositoryProvider).stores(
            at,
            storeTypeId: widget.storeTypeId,
            search: _search.text.trim(),
            sort: _sort,
            openNow: _openNow,
            page: _page,
          );
      if (id != _requestId || !mounted) return; // نتيجة قديمة (المستخدم غيّر البحث)
      setState(() {
        _stores.addAll(page.items);
        _hasMore = page.hasMore;
        _page++;
      });
    } catch (e) {
      if (id == _requestId && mounted) setState(() => _error = e);
    } finally {
      if (id == _requestId && mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_search.text.trim().length >= 2) {
        _reload();
      } else {
        setState(_stores.clear);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showEmptySearch = widget.searchMode && _search.text.trim().length < 2;

    return Scaffold(
      appBar: AppBar(
        title: widget.searchMode
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن متجر أو منتج',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              )
            : Text(widget.title ?? 'المتاجر القريبة'),
      ),
      bottomNavigationBar: const CartBar(),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (key, label) in [('nearest', 'الأقرب'), ('rating', 'الأعلى تقييمًا'), ('fastest', 'الأسرع')])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _sort == key,
                      onSelected: (_) {
                        setState(() => _sort = key);
                        if (!showEmptySearch) _reload();
                      },
                    ),
                  ),
                FilterChip(
                  label: const Text('مفتوح الآن'),
                  selected: _openNow,
                  onSelected: (v) {
                    setState(() => _openNow = v);
                    if (!showEmptySearch) _reload();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(showEmptySearch)),
        ],
      ),
    );
  }

  Widget _buildList(bool showEmptySearch) {
    if (showEmptySearch) {
      return const EmptyView(icon: Icons.search, title: 'ابحث عن مطعم، صيدلية، أو أي منتج');
    }
    if (_stores.isEmpty && _loading) return const LoadingView();
    if (_stores.isEmpty && _error != null) return ErrorView(error: _error!, onRetry: _reload);
    if (_stores.isEmpty) {
      return const EmptyView(icon: Icons.storefront_outlined, title: 'لا توجد نتائج', subtitle: 'جرّب كلمة أخرى أو فلتر مختلف');
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (_hasMore && !_loading && n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: _stores.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => i == _stores.length
              ? const Padding(padding: EdgeInsets.all(16), child: LoadingView())
              : StoreTile(store: _stores[i], onTap: () => context.push('/store/${_stores[i].id}')),
        ),
      ),
    );
  }
}
