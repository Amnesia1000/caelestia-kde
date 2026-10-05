#!/usr/bin/env python3

import tempfile
import unittest
from pathlib import Path

from check_artifact_parity import compare_trees, main


class ArtifactParityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        root = Path(self.tempdir.name)
        self.left = root / "left"
        self.right = root / "right"
        self.left.mkdir()
        self.right.mkdir()

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def write_both(self, relative: str, content: str) -> None:
        for root in (self.left, self.right):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")

    def test_identical_trees_pass(self) -> None:
        self.write_both("bin/caelestia", "#!/bin/sh\n")
        self.assertEqual([], compare_trees(self.left, self.right))

    def test_missing_file_fails(self) -> None:
        self.write_both("lib/caelestia/module", "module")
        (self.right / "lib/caelestia/module").unlink()
        self.assertEqual(
            ["missing from right tree: lib/caelestia/module"],
            compare_trees(self.left, self.right),
        )

    def test_hash_drift_fails(self) -> None:
        self.write_both("quickshell/shell.qml", "old")
        (self.right / "quickshell/shell.qml").write_text("new", encoding="utf-8")
        failures = compare_trees(self.left, self.right)
        self.assertEqual(1, len(failures))
        self.assertIn("hash mismatch: quickshell/shell.qml", failures[0])

    def test_compiled_artifacts_are_compared_by_presence_only(self) -> None:
        """Two build trees differ in every .so; that is not packaging drift."""
        self.write_both("lib/qt6/qml/Caelestia/lib/libcaelestia-core.so", "build-source")
        (self.right / "lib/qt6/qml/Caelestia/lib/libcaelestia-core.so").write_text(
            "build-package", encoding="utf-8"
        )
        self.assertEqual([], compare_trees(self.left, self.right))

    def test_missing_compiled_artifact_still_fails(self) -> None:
        self.write_both("lib/qt6/qml/Caelestia/lib/libcaelestia-core.so", "binary")
        (self.right / "lib/qt6/qml/Caelestia/lib/libcaelestia-core.so").unlink()
        self.assertEqual(
            ["missing from right tree: lib/qt6/qml/Caelestia/lib/libcaelestia-core.so"],
            compare_trees(self.left, self.right),
        )

    def test_cli_applies_the_packaging_contract_without_flags(self) -> None:
        """Callers cannot forget the contract: it is the default."""
        self.write_both("share/caelestia/shell.qml", "qml")
        extra = self.right / "share/sddm/themes/caelestia/Main.qml"
        extra.parent.mkdir(parents=True)
        extra.write_text("theme", encoding="utf-8")
        self.assertEqual(0, main([str(self.left), str(self.right)]))

    def test_documented_package_only_file_is_allowed(self) -> None:
        self.write_both("bin/caelestia", "binary")
        extra = self.right / "etc/sddm.conf.d/zz-caelestia.conf"
        extra.parent.mkdir(parents=True)
        extra.write_text("[Theme]\nCurrent=caelestia\n", encoding="utf-8")
        self.assertEqual(
            [],
            compare_trees(
                self.left,
                self.right,
                {"etc/sddm.conf.d/zz-caelestia.conf"},
            ),
        )

    def test_documented_package_only_prefix_is_allowed(self) -> None:
        self.write_both("bin/caelestia", "binary")
        extra = self.right / "usr/share/sddm/themes/caelestia/theme.conf"
        extra.parent.mkdir(parents=True)
        extra.write_text("theme", encoding="utf-8")
        self.assertEqual(
            [],
            compare_trees(
                self.left,
                self.right,
                allowed_right_only_prefixes={"usr/share/sddm/themes/caelestia"},
            ),
        )

    def test_cli_rejects_undocumented_extra(self) -> None:
        self.write_both("bin/caelestia", "binary")
        extra = self.right / "unexpected"
        extra.write_text("drift", encoding="utf-8")
        self.assertEqual(1, main([str(self.left), str(self.right)]))


if __name__ == "__main__":
    unittest.main()
