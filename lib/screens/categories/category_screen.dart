/// Halaman Kelola Kategori (v1.0.0) — sesuai SPEC: kategori dapat
/// ditambah, diubah, dihapus; tiap kategori punya nama, warna, ikon.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../database/expense_repository.dart';
import '../../models/category_model.dart';
import '../../providers/data_providers.dart';
import '../../utils/icon_map.dart';
import '../../utils/validators.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/realtime_clock.dart';
import '../../widgets/skeleton.dart';

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori Baru'),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(dataVersionProvider.notifier).bump(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            const RealtimeClock(),
            const SizedBox(height: 16),
            categories.when(
              loading: () => const SkeletonList(itemCount: 4),
              error: (e, _) => const EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Gagal memuat kategori'),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'Belum ada kategori',
                    message:
                        'Tekan "Kategori Baru" untuk menambah kategori pertamamu.',
                  );
                }
                return Column(
                  children: [
                    for (final c in list) _categoryCard(context, ref, c),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryCard(
      BuildContext context, WidgetRef ref, CategoryModel c) {
    final theme = Theme.of(context);
    final color = IconMap.colorFromHex(c.colorHex);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(IconMap.of(c.iconKey), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            IconButton(
              tooltip: 'Ubah',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showCategoryForm(context, ref, existing: c),
            ),
            IconButton(
              tooltip: 'Hapus',
              icon: Icon(Icons.delete_outline_rounded,
                  color: theme.colorScheme.error),
              onPressed: () => _delete(context, ref, c),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, CategoryModel c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Kategori?',
      message: 'Kategori "${c.name}" akan dihapus. Pengeluaran yang '
          'memakai kategori ini tidak ikut terhapus — hanya menjadi '
          'tanpa kategori.',
      confirmText: 'Hapus',
    );
    if (!ok) return;
    await ExpenseRepository.instance.deleteCategory(c.id);
    ref.read(dataVersionProvider.notifier).bump();
    if (context.mounted) {
      showAppSnackBar(context, 'Kategori "${c.name}" berhasil dihapus.');
    }
  }

  // -----------------------------------------------------------
  // FORM TAMBAH / UBAH KATEGORI (nama + warna + ikon)
  // -----------------------------------------------------------
  Future<void> _showCategoryForm(BuildContext context, WidgetRef ref,
      {CategoryModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String color = existing?.colorHex ??
        IconMap.hexFromColor(AppColors.categoryPalette.first);
    String iconKey = existing?.iconKey ?? IconMap.keys.first;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewColor = IconMap.colorFromHex(color);
            return AlertDialog(
              title:
                  Text(existing == null ? 'Kategori Baru' : 'Ubah Kategori'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: previewColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(IconMap.of(iconKey),
                                  color: previewColor, size: 30),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Kategori',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                        validator: (v) =>
                            Validators.required(v, 'Nama kategori'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      const Text('Warna',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in AppColors.categoryPalette)
                            GestureDetector(
                              onTap: () => setDialogState(
                                  () => color = IconMap.hexFromColor(c)),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: 2.6,
                                    color:
                                        IconMap.hexFromColor(c) == color
                                            ? Colors.black87
                                            : Colors.transparent,
                                  ),
                                ),
                                child:
                                    IconMap.hexFromColor(c) == color
                                        ? const Icon(Icons.check_rounded,
                                            color: Colors.white, size: 18)
                                        : null,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Ikon',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: GridView.count(
                          crossAxisCount: 5,
                          shrinkWrap: true,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: [
                            for (final key in IconMap.keys)
                              GestureDetector(
                                onTap: () =>
                                    setDialogState(() => iconKey = key),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: key == iconKey
                                        ? previewColor
                                            .withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                      color: key == iconKey
                                          ? previewColor
                                          : Colors.grey
                                              .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Icon(IconMap.of(key),
                                      color: key == iconKey
                                          ? previewColor
                                          : Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final repo = ExpenseRepository.instance;
      if (existing == null) {
        await repo.addCategory(
          name: nameController.text,
          colorHex: color,
          iconKey: iconKey,
          userId: '', // diisi SyncService saat push
        );
        if (context.mounted) {
          showAppSnackBar(context, 'Kategori baru berhasil ditambahkan.');
        }
      } else {
        await repo.updateCategory(existing.copyWith(
          name: nameController.text.trim(),
          colorHex: color,
          iconKey: iconKey,
        ));
        if (context.mounted) {
          showAppSnackBar(context, 'Kategori berhasil diubah.');
        }
      }
      ref.read(dataVersionProvider.notifier).bump();
    }
    nameController.dispose();
  }
}
