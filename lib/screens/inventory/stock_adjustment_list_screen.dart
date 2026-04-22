import 'package:flutter/material.dart';
import '../../models/stock_adjustment_model.dart';
import '../../services/database_service.dart';
import 'add_stock_adjustment_screen.dart';

class StockAdjustmentListScreen extends StatelessWidget {
  const StockAdjustmentListScreen({super.key});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điều Chỉnh Tồn Kho'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<StockAdjustment>>(
        stream: db.getStockAdjustments(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có phiếu điều chỉnh.\nNhấn + để tạo mới.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final adj = items[i];
              final isIncrease = adj.delta > 0;
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    isIncrease ? Icons.add_circle : Icons.remove_circle,
                    color: isIncrease ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  title: Text(adj.productNameSnapshot,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${adj.reason}${adj.note != null && adj.note!.isNotEmpty ? " — ${adj.note}" : ""}\n${_fmtDate(adj.adjustedAt)}',
                  ),
                  trailing: Text(
                    '${isIncrease ? '+' : ''}${adj.delta}',
                    style: TextStyle(
                      color: isIncrease ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AddStockAdjustmentScreen()),
        ),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
