"""Catalog generation tests. Temporary output only; no repository/cloud writes."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('catalog_generator', ROOT / 'tool/generate_observation_catalog.py')
generator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generator)
CATALOG = json.loads((ROOT / 'shared/observation_catalog.json').read_text())


class CatalogGenerationTest(unittest.TestCase):
    def test_committed_bindings_have_no_drift(self):
        for relative, generated in generator.render(CATALOG).items():
            self.assertEqual((ROOT / relative).read_text(), generated)

    def test_catalog_changes_generate_both_languages(self):
        changed = copy.deepcopy(CATALOG)
        changed['version'] = 'observation_catalog_v2'
        appetite = changed['items'][0]
        appetite.update(label='食欲の様子', order=100, active=False,
                        legacyNames=['食欲'])
        changed['items'].append(dict(id='newObservation', label='追加項目',
            order=0, active=True, legacyIds=[], legacyNames=[],
            insightEligible=True, defaultNormal=False))
        for generated in generator.render(changed).values():
            self.assertIn('observation_catalog_v2', generated)
            self.assertIn('食欲の様子', generated)
            self.assertIn('newObservation', generated)
            self.assertIn('追加項目', generated)
            self.assertIn('poop', generated)
            self.assertIn('chewing', generated)

    def test_check_detects_any_single_language_drift(self):
        with tempfile.TemporaryDirectory(prefix='hamcare-catalog-') as directory:
            root = Path(directory)
            for relative, generated in generator.render(CATALOG).items():
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(generated)
            command = ['python3', str(ROOT / 'tool/generate_observation_catalog.py'),
                       '--check', '--output-root', str(root)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            dart = root / 'lib/models/observation_catalog.generated.dart'
            dart.write_text(dart.read_text() + '// manual drift\n')
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('observation_catalog.generated.dart', result.stderr)

    def test_ambiguous_alias_is_rejected(self):
        changed = copy.deepcopy(CATALOG)
        changed['items'][0]['legacyIds'] = ['poop']
        with self.assertRaisesRegex(ValueError, 'ambiguous'):
            generator.render(changed)

    def test_dart_label_escaping(self):
        changed = copy.deepcopy(CATALOG)
        changed['items'][0]['label'] = '記号 $value'
        rendered = generator.render(changed)
        self.assertIn(r'\$value', rendered['lib/models/observation_catalog.generated.dart'])
        self.assertIn('$value', rendered['functions/src/health/observationCatalog.generated.ts'])


if __name__ == '__main__':
    unittest.main()
