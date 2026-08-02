import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/core/widgets/filter_field.dart';

/// Substring, not prefix — the whole reason this exists. Real schema names are
/// prefix-heavy (`ven_factura`, `ven_factura_detalle`, `secuencia_ncf`), so a
/// prefix match makes you type the boring part of every name first.
void main() {
  group('matchesFilter', () {
    test('matches in the middle of a name, not just the start', () {
      expect(matchesFilter('ban_autorizacion_pago_factura', 'factura'), isTrue);
      expect(matchesFilter('ven_secuencia_ncf', 'secuencia'), isTrue);
    });

    test('is case-insensitive both ways', () {
      expect(matchesFilter('CustomerOrders', 'customer'), isTrue);
      expect(matchesFilter('customer_orders', 'ORDERS'), isTrue);
    });

    test('an empty filter matches everything', () {
      expect(matchesFilter('anything', ''), isTrue);
      expect(matchesFilter('', ''), isTrue);
    });

    test('a non-match is a non-match', () {
      expect(matchesFilter('orders', 'zzz'), isFalse);
    });
  });

  group('FilterState', () {
    test('is inactive until it is both open and has text', () {
      expect(const FilterState().active, isFalse);
      expect(const FilterState(open: true).active, isFalse);
      expect(const FilterState(text: 'x').active, isFalse,
          reason: 'text without an open box must not narrow anything');
      expect(const FilterState(open: true, text: 'x').active, isTrue);
    });
  });
}
