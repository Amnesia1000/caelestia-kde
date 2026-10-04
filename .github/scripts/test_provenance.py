import json
import tempfile
import unittest
from pathlib import Path

from check_provenance import validate


class ProvenanceTests(unittest.TestCase):
    def test_template_has_required_path_independent_fields(self) -> None:
        template = Path(__file__).parents[2] / "shell" / "build-provenance.json.in"
        fields = set(json.loads(template.read_text(encoding="utf-8")).keys())
        self.assertEqual(fields, {
            "source_revision", "dependency_revision", "build_type", "compiler",
            "cmake_version", "qt_version", "source_hashes",
        })

    def test_valid_metadata_passes(self) -> None:
        data = {
            "source_revision": "a" * 40,
            "dependency_revision": "b" * 40,
            "build_type": "Release",
            "compiler": "GNU 14.2",
            "cmake_version": "3.31.0",
            "qt_version": "6.8.0",
            "source_hashes": "install-manifest",
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "provenance.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            self.assertEqual(validate(path), [])

    def test_user_paths_and_invalid_revisions_are_rejected(self) -> None:
        data = {field: "ok" for field in (
            "source_revision", "dependency_revision", "build_type", "compiler",
            "cmake_version", "qt_version", "source_hashes",
        )}
        data["source_revision"] = "C:/Users/camus/repo"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "provenance.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            failures = validate(path)
            self.assertTrue(any("source_revision" in failure for failure in failures))


if __name__ == "__main__":
    unittest.main()