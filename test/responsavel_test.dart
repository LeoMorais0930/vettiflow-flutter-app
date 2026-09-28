import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

void main() {
  test(
    'responsaveis include every collaborator from operators without duplicates',
    () {
      final expectedNames = <String>{
        for (final operator in Operator.all)
          if (operator.area != WorkArea.system) operator.name,
      };
      final responsavelNames = Responsavel.todos.map((r) => r.nome).toList();

      expect(responsavelNames.toSet(), expectedNames);
      expect(responsavelNames.length, expectedNames.length);
      expect(Responsavel.byNome('Andressa')?.iniciais, 'AN');
      expect(Responsavel.byNome('VettiFlow TV'), isNull);
    },
  );
}
