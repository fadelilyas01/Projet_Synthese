import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shieldnet/core/models/regional_threat.dart';
import 'package:shieldnet/core/services/regional_compliance_service.dart';
import 'package:shieldnet/features/call_filtering/presentation/widgets/regional_threat_card.dart';
import 'package:shieldnet/l10n/app_localizations.dart';

void main() {
  group('Radar Régional des Arnaques — Tests de filtrage Québec', () {
    final sampleSummary = RegionalThreatSummary(
      generatedAt: DateTime.now(),
      totalRegionsTracked: 5,
      regions: [
        const RegionalThreatItem(
          areaCode: '514',
          regionName: 'Montréal Centre-Ville (QC)',
          province: 'QC',
          totalSpams: 45,
          topCategory: 'fraud',
          maxRiskScore: 95,
          alertLevel: 'CRITIQUE',
        ),
        const RegionalThreatItem(
          areaCode: '450',
          regionName: 'Laval & Couronnes (QC)',
          province: 'QC',
          totalSpams: 22,
          topCategory: 'telemarketing',
          maxRiskScore: 78,
          alertLevel: 'ÉLEVÉ',
        ),
        const RegionalThreatItem(
          areaCode: '819',
          regionName: 'Outaouais / Gatineau / Laurentides (QC)',
          province: 'QC',
          totalSpams: 18,
          topCategory: 'phishing',
          maxRiskScore: 82,
          alertLevel: 'ÉLEVÉ',
        ),
        const RegionalThreatItem(
          areaCode: '416',
          regionName: 'Toronto Centre (ON)',
          province: 'ON',
          totalSpams: 50,
          topCategory: 'fraud',
          maxRiskScore: 90,
          alertLevel: 'CRITIQUE',
        ),
        const RegionalThreatItem(
          areaCode: '212',
          regionName: 'New York City / Manhattan (NY)',
          province: 'NY',
          totalSpams: 60,
          topCategory: 'fraud',
          maxRiskScore: 99,
          alertLevel: 'CRITIQUE',
        ),
      ],
    );

    test('Identification exacte des indicatifs et villes du Québec', () {
      final itemMtl = sampleSummary.regions.firstWhere((r) => r.areaCode == '514');
      final itemLaval = sampleSummary.regions.firstWhere((r) => r.areaCode == '450');
      final itemGatineau = sampleSummary.regions.firstWhere((r) => r.areaCode == '819');
      final itemToronto = sampleSummary.regions.firstWhere((r) => r.areaCode == '416');
      final itemNy = sampleSummary.regions.firstWhere((r) => r.areaCode == '212');

      expect(itemMtl.isQuebec, isTrue);
      expect(itemLaval.isQuebec, isTrue);
      expect(itemGatineau.isQuebec, isTrue);
      expect(itemToronto.isQuebec, isFalse);
      expect(itemNy.isQuebec, isFalse);
    });

    test('filterByQuebec() conserve uniquement les indicatifs et villes du Québec', () {
      final qcOnly = sampleSummary.filterByQuebec();

      expect(qcOnly.regions.length, equals(3));
      final codes = qcOnly.regions.map((r) => r.areaCode).toList();
      expect(codes, containsAll(['514', '450', '819']));
      expect(codes, isNot(contains('416')));
      expect(codes, isNot(contains('212')));

      // Vérifier que la menace la plus critique pour le Québec est Montréal (514)
      // et non Toronto (416) ou New York (212)
      expect(qcOnly.highestAlert?.areaCode, equals('514'));
      expect(qcOnly.highestAlert?.regionName, contains('Montréal'));
    });

    test('filterByProvince("QC") produit le même résultat strict pour le Québec', () {
      final qcFiltered = sampleSummary.filterByProvince('QC');
      expect(qcFiltered.regions.length, equals(3));
      for (final r in qcFiltered.regions) {
        expect(r.isQuebec, isTrue);
      }
    });

    testWidgets('RegionalThreatCard affiche uniquement les alertes du Québec pour un utilisateur québécois', (tester) async {
      final container = ProviderContainer(
        overrides: [
          regionalComplianceProvider.overrideWith((ref) => RegionalNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RegionalThreatCard(summary: sampleSummary),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Le bandeau doit afficher l'alerte du Québec (514 Montréal)
      expect(find.textContaining('Alerte Québec • (514)'), findsOneWidget);
      expect(find.textContaining('Montréal Centre-Ville (QC)'), findsOneWidget);

      // Toronto et New York ne doivent pas apparaître dans le bandeau
      expect(find.textContaining('416'), findsNothing);
      expect(find.textContaining('Toronto'), findsNothing);
      expect(find.textContaining('212'), findsNothing);
      expect(find.textContaining('New York'), findsNothing);

      // Ouvrir le panneau de détail (bottom sheet)
      await tester.tap(find.byType(RegionalThreatCard));
      await tester.pumpAndSettle();

      // Vérifier le titre et les indicatifs dans la liste modale
      expect(find.text('Radar des arnaques au Québec'), findsOneWidget);
      expect(find.text('514'), findsOneWidget);
      expect(find.text('450'), findsOneWidget);
      expect(find.text('819'), findsOneWidget);

      // Formellement aucun indicatif ni ville hors Québec
      expect(find.text('416'), findsNothing);
      expect(find.text('Toronto Centre (ON)'), findsNothing);
      expect(find.text('212'), findsNothing);
      expect(find.text('New York City / Manhattan (NY)'), findsNothing);
    });
  });
}
