import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from tools.doctor.doctor import inspect


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class DoctorTests(unittest.TestCase):
    def fixture(self):
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        exe = root / "runtime" / "uzdoom.exe"
        support = root / "runtime" / "uzdoom.pk3"
        archive = root / "downloads" / "uzdoom.zip"
        source = root / "source"
        venv = root / ".venv"
        for path in (exe, support, archive):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(path.name.encode())
        source.mkdir()
        source_commit = "a" * 40
        venv.mkdir()
        lock = {
            "schema_version": 1,
            "uzdoom": {"version": "5.0.1", "asset": {"name": "uzdoom.zip", "url": "https://example.invalid/u.zip", "publisher_sha256": digest(archive), "observed_sha256": digest(archive), "download_path": "downloads/uzdoom.zip"}, "executable": {"path": "runtime/uzdoom.exe", "sha256": digest(exe)}, "support_files": [{"path": "runtime/uzdoom.pk3", "sha256": digest(support)}], "source": {"url": "https://example.invalid/u.git", "tag": "5.0.1", "commit": source_commit, "path": "source"}},
            "python": {"version": ".".join(map(str, __import__("sys").version_info[:3])), "venv_path": ".venv"},
        }
        lock_path = root / "toolchain" / "lock.json"
        lock_path.parent.mkdir()
        lock_path.write_text(json.dumps(lock), encoding="utf-8")
        git = lambda command, cwd=None: (0, source_commit if command[1] == "rev-parse" else ("git version test" if command[1] == "--version" else ""), "")
        return temp, root, lock_path, git

    def test_tampered_runtime_fails(self):
        temp, root, lock, git = self.fixture()
        self.assertEqual(inspect(root, lock, git)["status"], "PASS")
        (root / "runtime/uzdoom.exe").write_bytes(b"tampered runtime")
        result = inspect(root, lock, git)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("executable hash mismatch" in error for error in result["errors"]))
        temp.cleanup()

    def test_missing_support_file_fails(self):
        temp, root, lock, git = self.fixture()
        (root / "runtime/uzdoom.pk3").unlink()
        result = inspect(root, lock, git)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("support" in error for error in result["errors"]))
        temp.cleanup()

    def test_unsafe_path_and_malformed_lock_fail(self):
        temp, root, lock, git = self.fixture()
        data = json.loads(lock.read_text())
        data["uzdoom"]["executable"]["path"] = "../outside.exe"
        lock.write_text(json.dumps(data), encoding="utf-8")
        result = inspect(root, lock, git)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("escapes root" in error for error in result["errors"]))
        lock.write_text("{bad", encoding="utf-8")
        self.assertEqual(inspect(root, lock, git)["status"], "FAIL")
        lock.write_bytes(b"\xff\xfe")
        self.assertEqual(inspect(root, lock, git)["status"], "FAIL")
        temp.cleanup()

    def test_conflicting_archive_hashes_fail_even_when_archive_absent(self):
        temp, root, lock, git = self.fixture()
        (root / "downloads/uzdoom.zip").unlink()
        data = json.loads(lock.read_text())
        data["uzdoom"]["asset"]["observed_sha256"] = "b" * 64
        lock.write_text(json.dumps(data), encoding="utf-8")
        result = inspect(root, lock, git)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("disagree" in error for error in result["errors"]))
        temp.cleanup()

    def test_missing_hash_fails(self):
        temp, root, lock, git = self.fixture()
        data = json.loads(lock.read_text())
        data["uzdoom"]["executable"]["sha256"] = ""
        lock.write_text(json.dumps(data), encoding="utf-8")
        result = inspect(root, lock, git)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("required SHA-256" in error for error in result["errors"]))
        temp.cleanup()


if __name__ == "__main__":
    unittest.main()
