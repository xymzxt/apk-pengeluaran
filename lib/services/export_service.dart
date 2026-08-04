/// Layanan export laporan pengeluaran — PDF, Excel, dan TXT
/// (SPEC-PENGELUARAN.md: tombol Export PDF, Export Excel, Share;
/// TXT untuk berbagi cepat via WhatsApp seperti di aplikasi kasir) —
/// v1.0.0.
library;

import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants/app_constants.dart';
import '../models/expense_model.dart';
import '../providers/report_provider.dart';
import '../utils/formatters.dart';
import 'file_saver.dart';

class ExportService {
  String _fileBase(ReportData data) =>
      'laporan-pengeluaran-${data.period.name}-'
      '${DateFormat('yyyyMMdd').format(data.range.start)}';

  String _methodLabel(String code) => AppConstants.paymentLabel(code);

  // -----------------------------------------------------------
  // PDF
  // -----------------------------------------------------------
  Future<SaveOutcome> exportPdf(ReportData data, String ownerName) async {
    final doc = pw.Document();

    pw.Widget summaryRow(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text(label), pw.Text(value)],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text('Laporan ${data.period.label} - $ownerName',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Periode: ${data.range.describe()}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          summaryRow('Total Pengeluaran', Formatters.currency(data.total)),
          summaryRow('Jumlah Transaksi', '${data.count}'),
          summaryRow('Rata-rata Pengeluaran',
              Formatters.currency(data.average)),
          summaryRow(
              'Pengeluaran Terbesar',
              data.biggest == null
                  ? '-'
                  : '${data.biggest!.name} (${Formatters.currency(data.biggest!.nominal)})'),
          summaryRow('Kategori Terbanyak',
              data.topCategoryName ?? '-'),
          pw.SizedBox(height: 16),
          pw.Text('Rincian per Kategori',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (data.perCategory.isEmpty)
            pw.Text('Belum ada data', style: const pw.TextStyle(fontSize: 9))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Kategori', 'Transaksi', 'Total'],
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: [
                for (final c in data.perCategory)
                  [
                    c.name,
                    '${c.count}',
                    Formatters.currency(c.total),
                  ],
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Text('Rincian Transaksi',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (data.items.isEmpty)
            pw.Text('Belum ada transaksi',
                style: const pw.TextStyle(fontSize: 9))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Tanggal', 'Nama', 'Kategori', 'Metode', 'Nominal'],
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: [
                for (final e in data.items)
                  [
                    '${e.date} ${e.time}',
                    e.name,
                    data.categoryNameOf(e.categoryId),
                    _methodLabel(e.method),
                    Formatters.currency(e.nominal),
                  ],
              ],
            ),
          pw.SizedBox(height: 12),
          pw.Text('Dicetak oleh ${AppConstants.appName}',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    );

    final bytes = await doc.save();
    return FileSaver.saveOrShare('${_fileBase(data)}.pdf', bytes);
  }

  // -----------------------------------------------------------
  // EXCEL
  // -----------------------------------------------------------
  Future<SaveOutcome> exportExcel(ReportData data, String ownerName) async {
    final excel = Excel.createExcel();

    // --- Sheet 1: Ringkasan ---
    excel.rename('Sheet1', 'Ringkasan');
    final summary = excel['Ringkasan'];
    summary.appendRow([TextCellValue('Laporan ${data.period.label}')]);
    summary.appendRow([TextCellValue(ownerName)]);
    summary.appendRow([TextCellValue('Periode: ${data.range.describe()}')]);
    summary.appendRow([TextCellValue('')]);
    summary.appendRow([
      TextCellValue('Total Pengeluaran'),
      TextCellValue(Formatters.currency(data.total)),
    ]);
    summary.appendRow(
        [TextCellValue('Jumlah Transaksi'), IntCellValue(data.count)]);
    summary.appendRow([
      TextCellValue('Rata-rata Pengeluaran'),
      TextCellValue(Formatters.currency(data.average)),
    ]);
    summary.appendRow([
      TextCellValue('Pengeluaran Terbesar'),
      TextCellValue(data.biggest == null
          ? '-'
          : '${data.biggest!.name} (${Formatters.currency(data.biggest!.nominal)})'),
    ]);
    summary.appendRow([
      TextCellValue('Kategori Terbanyak'),
      TextCellValue(data.topCategoryName ?? '-'),
    ]);

    // --- Sheet 2: Per Kategori ---
    final catSheet = excel['Per Kategori'];
    catSheet.appendRow([
      TextCellValue('Kategori'),
      TextCellValue('Transaksi'),
      TextCellValue('Total'),
    ]);
    for (final c in data.perCategory) {
      catSheet.appendRow([
        TextCellValue(c.name),
        IntCellValue(c.count),
        DoubleCellValue(c.total),
      ]);
    }

    // --- Sheet 3: Rincian Transaksi ---
    final txSheet = excel['Transaksi'];
    txSheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('Nama'),
      TextCellValue('Kategori'),
      TextCellValue('Metode'),
      TextCellValue('Nominal'),
      TextCellValue('Catatan'),
    ]);
    for (final e in data.items) {
      txSheet.appendRow([
        TextCellValue(e.date),
        TextCellValue(e.time),
        TextCellValue(e.name),
        TextCellValue(data.categoryNameOf(e.categoryId)),
        TextCellValue(_methodLabel(e.method)),
        DoubleCellValue(e.nominal),
        TextCellValue(e.note),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Gagal membuat file Excel');

    return FileSaver.saveOrShare('${_fileBase(data)}.xlsx', bytes);
  }

  // -----------------------------------------------------------
  // TXT — untuk tombol Share (kirim cepat via WhatsApp/dll.)
  // -----------------------------------------------------------
  Future<SaveOutcome> exportTxt(ReportData data, String ownerName) async {
    const garis = '========================================';
    final b = StringBuffer()
      ..writeln('LAPORAN PENGELUARAN ${data.period.label.toUpperCase()}')
      ..writeln(ownerName)
      ..writeln('Periode : ${data.range.describe()}')
      ..writeln('Dibuat  : '
          '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}')
      ..writeln(garis)
      ..writeln('Total Pengeluaran : ${Formatters.currency(data.total)}')
      ..writeln('Jumlah Transaksi  : ${data.count}')
      ..writeln('Rata-rata         : ${Formatters.currency(data.average)}')
      ..writeln('Terbesar          : ${data.biggest == null ? '-' : '${data.biggest!.name} (${Formatters.currency(data.biggest!.nominal)})'}')
      ..writeln('Kategori Terbanyak: ${data.topCategoryName ?? '-'}')
      ..writeln(garis)
      ..writeln('PER KATEGORI');
    if (data.perCategory.isEmpty) {
      b.writeln('(belum ada data)');
    } else {
      for (final c in data.perCategory) {
        b.writeln('- ${c.name}: ${Formatters.currency(c.total)} '
            '(${c.count} transaksi)');
      }
    }
    b
      ..writeln(garis)
      ..writeln('RINCIAN TRANSAKSI');
    if (data.items.isEmpty) {
      b.writeln('(belum ada transaksi)');
    } else {
      for (final ExpenseModel e in data.items) {
        b.writeln('${e.date} ${e.time}  ${e.name}  '
            '${data.categoryNameOf(e.categoryId)}  '
            '${_methodLabel(e.method)}  ${Formatters.currency(e.nominal)}');
      }
    }

    return FileSaver.saveOrShare(
      '${_fileBase(data)}.txt',
      utf8.encode(b.toString()),
    );
  }
}
