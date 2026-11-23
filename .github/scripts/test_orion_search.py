import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "shell" / "scripts" / "orion_search.py"

spec = importlib.util.spec_from_file_location("orion_search", MODULE_PATH)
orion_search = importlib.util.module_from_spec(spec)
spec.loader.exec_module(orion_search)


class TextExtractionTests(unittest.TestCase):
    def test_drops_script_contents_even_with_attributes_on_the_end_tag(self):
        html = '<body>Hello<script>alert(1)</script foo="bar">World</body>'
        self.assertEqual(orion_search._extract_text(html), "Hello World")

    def test_drops_comment_ending_in_bang(self):
        html = "<body>Alpha<!-- hidden --!>Beta</body>"
        self.assertEqual(orion_search._extract_text(html), "Alpha Beta")

    def test_drops_page_furniture(self):
        html = (
            "<body><header>Head</header><nav>Nav</nav>"
            "Content<footer>Foot</footer><aside>Side</aside></body>"
        )
        self.assertEqual(orion_search._extract_text(html), "Content")

    def test_unclosed_head_does_not_swallow_the_body(self):
        html = "<html><head><title>Title</title><body>Body text</body></html>"
        self.assertEqual(orion_search._extract_text(html), "Body text")

    def test_collapses_whitespace(self):
        html = "<body>  one\n\n two\tthree  </body>"
        self.assertEqual(orion_search._extract_text(html), "one two three")


if __name__ == "__main__":
    unittest.main()
