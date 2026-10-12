import json
import os
from django.core.management.base import BaseCommand
from shield_api.models import BlacklistedNumber

class Command(BaseCommand):
    help = "Peuple la base de données avec le flux de Threat Intelligence (numéros spams/arnaques vérifiés)"

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default=None,
            help="Chemin vers le fichier JSON des numéros de threat intelligence"
        )

    def handle(self, *args, **options):
        file_path = options.get('file')
        if not file_path:
            candidate_paths = [
                '../ShieldNet/assets/data/preloaded_threat_intel.json',
                '../../ShieldNet/assets/data/preloaded_threat_intel.json',
                'assets/data/preloaded_threat_intel.json',
                'c:/Projet/Projet synthese/ShieldNet/assets/data/preloaded_threat_intel.json',
            ]
            for p in candidate_paths:
                if os.path.exists(p):
                    file_path = p
                    break

        if not file_path or not os.path.exists(file_path):
            self.stdout.write(self.style.ERROR(f"Fichier introuvable: {file_path}"))
            return

        with open(file_path, 'r', encoding='utf-8') as f:
            records = json.load(f)

        created_count = 0
        updated_count = 0

        for r in records:
            obj, created = BlacklistedNumber.objects.update_or_create(
                phone_hash=r['phone_hash'],
                defaults={
                    'masked_number': r.get('masked_number'),
                    'category': r.get('category', 'fraud'),
                    'risk_score': r.get('risk_score', 90),
                    'reports_count': r.get('reports_count', 10),
                    'is_blocked': True,
                    'is_whitelisted': False,
                }
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        total = BlacklistedNumber.objects.count()
        self.stdout.write(self.style.SUCCESS(
            f"[Threat Intelligence] Succès : {created_count} numéros ajoutés, {updated_count} mis à jour. Total en base : {total} numéros."
        ))
