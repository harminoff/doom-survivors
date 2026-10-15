import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.package.build_package import _validate_name, build_package


class PackageBuilderTests(unittest.TestCase):
    def test_order_and_mtime_do_not_change_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "staging"
            source.mkdir()
            (source / "B.txt").write_bytes(b"bravo")
            (source / "a.txt").write_bytes(b"alpha")
            first = root / "one.ipk3"
            result_one = build_package(source, first)
            (source / "a.txt").touch()
            (source / "B.txt").touch()
            second = root / "two.ipk3"
            reversed_source = root / "reversed"
            reversed_source.mkdir()
            (reversed_source / "a.txt").write_bytes(b"alpha")
            (reversed_source / "B.txt").write_bytes(b"bravo")
            result_two = build_package(reversed_source, second)
            self.assertEqual(result_one["sha256"], result_two["sha256"])
            self.assertEqual(first.read_bytes(), second.read_bytes())
            self.assertEqual(result_one["entries"], ["B.txt", "a.txt"])

    def test_changed_input_changes_hash_and_archive_is_stored(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "staging"
            source.mkdir()
            file = source / "MAP01.txt"
            file.write_bytes(b"one")
            output = root / "game.ipk3"
            first = build_package(source, output)
            file.write_bytes(b"two")
            second = build_package(source, output)
            self.assertNotEqual(first["sha256"], second["sha256"])
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.getinfo("MAP01.txt").compress_type, zipfile.ZIP_STORED)

    def test_rejects_output_under_source_and_case_collision(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "staging"
            source.mkdir()
            (source / "file.txt").write_text("x", encoding="utf-8")
            with self.assertRaises(ValueError):
                build_package(source, source / "nested" / "game.ipk3")
            (source / "file.txt").unlink()
            with self.assertRaises(ValueError):
                _validate_name("a.TXT", {"a.txt"})


if __name__ == "__main__":
    unittest.main()
