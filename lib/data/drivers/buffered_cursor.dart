import '../../domain/drivers/result.dart';

/// A [ResultCursor] over a fully-materialized row list — for drivers whose
/// package buffers the whole result (`postgres`, `mysql_client`). Fetches serve
/// from memory; `close` is a no-op. Row-by-row streaming can replace this later
/// without changing the port.
class BufferedCursor implements ResultCursor {
  BufferedCursor(this.fields, this._rows);

  @override
  final List<ResultField> fields;
  final List<ResultRow> _rows;
  int _pos = 0;

  @override
  bool get hasMore => _pos < _rows.length;

  @override
  Future<List<ResultRow>> fetch(int n) async {
    final end = (_pos + n).clamp(0, _rows.length);
    final batch = _rows.sublist(_pos, end);
    _pos = end;
    return batch;
  }

  @override
  Future<void> close() async {}
}
