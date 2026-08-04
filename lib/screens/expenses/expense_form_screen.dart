/// Form Tambah / Edit Pengeluaran (v1.0.0) — sesuai SPEC:
/// Nama, Nominal (format Rupiah otomatis), Kategori, Tanggal, Jam,
/// Metode Pembayaran, Catatan, Upload Foto Nota (kamera/galeri,
/// preview, ganti, hapus). Validasi: semua wajib kecuali catatan &
/// foto; nominal tidak boleh nol; tanggal tidak boleh kosong.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../database/expense_repository.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../providers/data_providers.dart';
import '../../services/image_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../utils/currency_input.dart';
import '../../utils/formatters.dart';
import '../../utils/validators.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/realtime_clock.dart';
import '../categories/category_screen.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  /// Bila diisi -> mode Edit; bila null -> mode Tambah.
  final ExpenseModel? existing;

  const ExpenseFormScreen({super.key, this.existing});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nominalController;
  late final TextEditingController _noteController;

  String? _categoryId;
  late String _method;
  late DateTime _date;
  late TimeOfDay _time;
  String? _photoLocal;
  bool _photoRemoved = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _nominalController = TextEditingController(
        text: e == null ? '' : CurrencyInputFormatter.format(e.nominal));
    _noteController = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _method = e?.method ?? 'tunai';
    final now = DateTime.now();
    if (e != null) {
      final parts = e.date.split('-');
      _date = DateTime(int.parse(parts[0]), int.parse(parts[1]),
          int.parse(parts[2]));
      final tp = e.time.split(':');
      _time = TimeOfDay(hour: int.parse(tp[0]), minute: int.parse(tp[1]));
      _photoLocal = e.photoLocal;
    } else {
      _date = now;
      _time = TimeOfDay.fromDateTime(now);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nominalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------
  // PICKERS
  // -----------------------------------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2021),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickPhoto() async {
    // Sumber foto: kamera atau galeri (SPEC).
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final id = widget.existing?.id ?? 'baru-${DateTime.now().millisecondsSinceEpoch}';
    final service = ImageService();
    final path = source == 'camera'
        ? await service.pickFromCamera(id)
        : await service.pickFromGallery(id);
    if (path != null && mounted) {
      setState(() {
        _photoLocal = path;
        _photoRemoved = false;
      });
      showAppSnackBar(context, 'Foto nota berhasil dipilih.');
    }
  }

  Future<void> _removePhoto() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Foto Nota?',
      message: 'Foto nota akan dihapus dari pengeluaran ini.',
      confirmText: 'Hapus',
    );
    if (!ok) return;
    setState(() {
      _photoLocal = null;
      _photoRemoved = true;
    });
    showAppSnackBar(context, 'Foto nota dihapus.');
  }

  void _previewPhoto() {
    if (_photoLocal == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              // Zoom (SPEC): pinch-to-zoom preview nota.
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.file(File(_photoLocal!)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // SIMPAN
  // -----------------------------------------------------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final repo = ExpenseRepository.instance;
      // uid owner untuk kolom user_id (kosong saat offline penuh).
      final uid = SupabaseService.instance.currentUser?.id ?? '';
      final date =
          '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
      final time =
          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';
      final nominal = CurrencyInputFormatter.parse(_nominalController.text);

      if (_isEdit) {
        final old = widget.existing!;
        // Foto dihapus -> buang file lokal & tandai remote agar
        // ikut dihapus server saat sinkron.
        var remote = old.photoRemote;
        if (_photoRemoved) {
          await ImageService().deleteIfExists(old.photoLocal);
        }
        if (_photoLocal != null && _photoLocal != old.photoLocal) {
          // Foto diganti -> foto lama dibuang; remote akan tertimpa
          // saat sinkron berikutnya.
          if (old.photoLocal != null && old.photoLocal != _photoLocal) {
            await ImageService().deleteIfExists(old.photoLocal);
          }
          remote = null; // paksa unggah ulang
        }
        await repo.updateExpense(old.copyWith(
          name: _nameController.text.trim(),
          nominal: nominal,
          method: _method,
          date: date,
          time: time,
          note: _noteController.text.trim(),
          categoryId: _categoryId,
          clearCategory: _categoryId == null,
          photoLocal: _photoLocal,
          clearPhotoLocal: _photoLocal == null,
          photoRemote: remote,
          clearPhotoRemote: remote == null,
        ));
      } else {
        await repo.addExpense(
          name: _nameController.text,
          nominal: nominal,
          categoryId: _categoryId,
          method: _method,
          date: date,
          time: time,
          note: _noteController.text,
          photoLocal: _photoLocal,
          userId: uid,
        );
      }

      ref.read(dataVersionProvider.notifier).bump();
      // Dorong perubahan ke cloud di latar belakang (best-effort).
      // ignore: discarded_futures
      SyncService.instance.syncNow();

      if (!mounted) return;
      showAppSnackBar(
        context,
        _isEdit
            ? 'Pengeluaran berhasil diubah.'
            : 'Pengeluaran berhasil ditambahkan.',
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // -----------------------------------------------------------
  // UI
  // -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Pengeluaran' : 'Tambah Pengeluaran'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const RealtimeClock(),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Nama ---
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pengeluaran *',
                    hintText: 'mis. Beli es batu, Bayar listrik',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (v) => Validators.required(v, 'Nama pengeluaran'),
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),

                // --- Nominal (format Rupiah otomatis) ---
                TextFormField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nominal *',
                    hintText: '0',
                    prefixIcon: Icon(Icons.payments_outlined),
                    prefixText: 'Rp ',
                  ),
                  validator: Validators.nominal,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // --- Kategori ---
                _CategoryPicker(
                  categories: categories,
                  selectedId: _categoryId,
                  onChanged: (id) => setState(() => _categoryId = id),
                  onManage: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CategoryScreen()),
                    );
                    ref.read(dataVersionProvider.notifier).bump();
                  },
                ),
                const SizedBox(height: 14),

                // --- Tanggal & Jam (berdampingan) ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.calendar_month_rounded,
                            size: 20),
                        label: Text(
                          Formatters.date(_date),
                          style: theme.textTheme.bodyMedium,
                        ),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon:
                            const Icon(Icons.schedule_rounded, size: 20),
                        label: Text(
                          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        onPressed: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // --- Metode Pembayaran (chips) ---
                Text('Metode Pembayaran *',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in AppConstants.paymentMethods)
                      ChoiceChip(
                        label: Text(m['label']!),
                        selected: _method == m['code'],
                        onSelected: (_) =>
                            setState(() => _method = m['code']!),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // --- Catatan (opsional) ---
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'mis. untuk stok warung minggu ini',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 14),

                // --- Foto Nota (opsional) ---
                _PhotoSection(
                  photoLocal: _photoLocal,
                  onPick: _pickPhoto,
                  onPreview: _previewPhoto,
                  onRemove: _removePhoto,
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(_isEdit
                          ? Icons.save_rounded
                          : Icons.add_circle_outline_rounded),
                  label: Text(_saving
                      ? 'Menyimpan...'
                      : _isEdit
                          ? 'Simpan Perubahan'
                          : 'Simpan Pengeluaran'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bagian Foto Nota: preview, ganti, hapus (SPEC).
class _PhotoSection extends StatelessWidget {
  final String? photoLocal;
  final VoidCallback onPick;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  const _PhotoSection({
    required this.photoLocal,
    required this.onPick,
    required this.onPreview,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Foto Nota (opsional)',
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 8),
        if (photoLocal == null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Tambah Foto Nota (Kamera / Galeri)'),
            onPressed: onPick,
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(photoLocal!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        width: 64,
                        height: 64,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.06),
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Nota terlampir',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Lihat / Zoom',
                    icon: const Icon(Icons.zoom_in_rounded),
                    onPressed: onPreview,
                  ),
                  IconButton(
                    tooltip: 'Ganti Foto',
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: onPick,
                  ),
                  IconButton(
                    tooltip: 'Hapus Foto',
                    icon: Icon(Icons.delete_outline_rounded,
                        color: theme.colorScheme.error),
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Pemilih kategori + tautan kelola kategori.
class _CategoryPicker extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManage;

  const _CategoryPicker({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Kategori',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.hintColor)),
            const Spacer(),
            TextButton.icon(
              onPressed: onManage,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Kelola Kategori'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tanpa Kategori'),
              selected: selectedId == null,
              onSelected: (_) => onChanged(null),
            ),
            // ignore: avoid_function_literals_in_foreach_calls
            for (final c in categories)
              ChoiceChip(
                avatar: CircleAvatar(
                  radius: 7,
                  backgroundColor: _catColor(c),
                ),
                label: Text(c.name),
                selected: selectedId == c.id,
                onSelected: (_) => onChanged(c.id),
              ),
          ],
        ),
      ],
    );
  }

  Color _catColor(CategoryModel c) {
    // Warna kategori dari hex tersimpan.
    final hex = c.colorHex.replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return Colors.green;
    return Color(0xFF000000 | value);
  }
}
