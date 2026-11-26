import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location('kiosk_config', Path(__file__).resolve().parents[1] / 'files' / 'img-frame-config.py')
config = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(config)


class ConfigTests(unittest.TestCase):
    def test_local_urls(self):
        for value in ('http://homeassistant.local:8123/lovelace/0', 'https://192.168.1.10/dashboard?kiosk', 'http://[::1]:8123', 'http://localhost/#view'):
            with self.subTest(value=value):
                self.assertEqual(config.validate_url(value), value)

    def test_rejects_invalid_urls(self):
        for value in ('', 'homeassistant.local:8123', 'file:///etc/passwd', 'javascript:alert(1)', 'http://', 'http://host:99999', 'http://host:abc', 'http://user:secret@host', 'http://host/\ncommand', 'http://host/with space', 'http://host\\other', 'http://[invalid'):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    config.validate_url(value)

    def test_first_start_and_persistence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            self.assertIsNone(config.load_url(path))
            with patch('builtins.input', side_effect=['invalid', 'http://homeassistant.local:8123']):
                config.prompt_url(path)
            self.assertEqual(config.load_url(path), 'http://homeassistant.local:8123')
            config.save_url('https://192.168.1.2/new', path)
            self.assertEqual(config.load_url(path), 'https://192.168.1.2/new')
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_invalid_update_preserves_config(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            config.save_url('http://host', path)
            with self.assertRaises(ValueError):
                config.save_url('file:///etc/passwd', path)
            self.assertEqual(config.load_url(path), 'http://host')

    def test_corrupt_config_can_be_repaired(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            for content in ('not json', '[]', '{}', '{"url": 42}'):
                path.write_text(content, encoding='utf-8')
                with self.assertRaises(ValueError):
                    config.load_url(path)
            with patch('builtins.input', return_value='http://host'):
                config.prompt_url(path)
            self.assertEqual(config.load_url(path), 'http://host')


if __name__ == '__main__':
    unittest.main()