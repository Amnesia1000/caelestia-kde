import json
import tempfile
import unittest
from pathlib import Path

from check_provenance import validate
from write_provenance_hash import update


class ProvenanceTests(unittest.TestCase):
    def test_template_has_required_path_independent_fields(self) -> None:
        template = Path(__file__).parents[2] / "shell" / "build-provenance.json.in"
        fields = set(json.loads(template.read_text(encoding="utf-8")).keys())
        self.assertEqual(fields, {
            "source_revision", "dependency_revision", "build_type", "compiler",
            "cmake_version", "qt_version", "hash_algorithm", "artifact_root_hash",
        })

    def test_valid_metadata_passes(self) -> None:
        data = {
            "source_revision": "a" * 40,
            "dependency_revision": "b" * 40,
            "build_type": "Release",
            "compiler": "GNU 14.2",
            "cmake_version": "3.31.0",
            "qt_version": "6.8.0",
            "hash_algorithm": "sha256",
            "artifact_root_hash": "c" * 64,
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "provenance.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            self.assertEqual(validate(path), [])

    def test_user_paths_and_invalid_revisions_are_rejected(self) -> None:
        data = {field: "ok" for field in (
            "source_revision", "dependency_revision", "build_type", "compiler",
            "cmake_version", "qt_version", "hash_algorithm", "artifact_root_hash",
        )}
        data["source_revision"] = "C:/Users/camus/repo"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "provenance.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            failures = validate(path)
            self.assertTrue(any("source_revision" in failure for failure in failures))

    def test_artifact_hash_is_deterministic_and_excludes_metadata(self) -> None:
        data = {
            "source_revision": "unknown", "dependency_revision": "unknown",
            "build_type": "Release", "compiler": "GNU", "cmake_version": "3",
            "qt_version": "unknown", "hash_algorithm": "sha256",
            "artifact_root_hash": "pending-install",
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "usr"
            metadata = root / "share/caelestia/build-provenance.json"
            metadata.parent.mkdir(parents=True)
            (root / "bin/tool").parent.mkdir(parents=True)
            (root / "bin/tool").write_text("stable", encoding="utf-8")
            metadata.write_text(json.dumps(data), encoding="utf-8")
            update(metadata, root, ())
            first = json.loads(metadata.read_text(encoding="utf-8"))["artifact_root_hash"]
            update(metadata, root, ())
            second = json.loads(metadata.read_text(encoding="utf-8"))["artifact_root_hash"]
            self.assertEqual(first, second)
            self.assertEqual(len(first), 64)


if __name__ == "__main__":
    unittest.main()