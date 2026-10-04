import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).parents[2]
TOOL_PATH = ROOT / "tools" / "sync-shell.py"


spec = importlib.util.spec_from_file_location("sync_shell", TOOL_PATH)
assert spec and spec.loader
sync_shell = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync_shell)


class UpstreamBoundaryTests(unittest.TestCase):
    def test_fixture_paths_are_classified_by_ownership_and_content(self) -> None:
        shell = {
            "shared.qml": "same",
            "adapted.qml": "kde-adaptation",
            "kde-only.qml": "port-only",
        }
        upstream = {
            "shared.qml": "same",
            "adapted.qml": "upstream-version",
            "upstream-only.qml": "upstream-only",
        }

        result = sync_shell.classify_paths(shell, upstream)

        self.assertEqual(result["in_sync"], ["shared.qml"])
        self.assertEqual(result["diverged"], ["adapted.qml"])
        self.assertEqual(result["missing"], ["upstream-only.qml"])
        self.assertEqual(result["kde_only"], ["kde-only.qml"])

    def test_classification_does_not_treat_kde_files_as_missing(self) -> None:
        result = sync_shell.classify_paths(
            {"modules/kde.qml": "local"},
            {"modules/upstream.qml": "remote"},
        )

        self.assertEqual(result["missing"], ["modules/upstream.qml"])
        self.assertEqual(result["kde_only"], ["modules/kde.qml"])

    def test_bring_command_requires_force_for_existing_files(self) -> None:
        parser = sync_shell.argparse.ArgumentParser()
        subparsers = parser.add_subparsers(dest="cmd", required=True)
        bring = subparsers.add_parser("bring")
        bring.add_argument("--force", action="store_true")
        bring.add_argument("paths", nargs="+")

        self.assertFalse(parser.parse_args(["bring", "modules/example.qml"]).force)
        self.assertTrue(parser.parse_args(["bring", "--force", "modules/example.qml"]).force)


if __name__ == "__main__":
    unittest.main()
