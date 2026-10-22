"""Geometry regression for one compatibility candidate, not a native renderer test."""

import importlib.util
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("card_spike", Path(__file__).with_name("export-card-spike.py"))
spike = importlib.util.module_from_spec(spec)
spec.loader.exec_module(spike)


class TextHeightCompatibilityTests(unittest.TestCase):
    def test_only_two_transparent_text_heights_change(self):
        original = json.loads((ROOT / "art/spikes/card-editor/card.source.json").read_text(encoding="utf-8"))
        snapshot = json.dumps(original, sort_keys=True)
        candidate = spike.native_text_height_candidate(original)
        self.assertEqual(json.dumps(original, sort_keys=True), snapshot, "preserve upstream comparison input")
        self.assertEqual(candidate["canvas"], original["canvas"])
        self.assertEqual(candidate["meta"], original["meta"])
        changed = []
        for before, after in zip(original["elements"], candidate["elements"], strict=True):
            if before != after:
                changed.append(before["id"])
                self.assertEqual(before["type"], "textbox")
                self.assertEqual(before["textBox"]["bgOpacity"], 0)
                self.assertEqual(before["textBox"]["alignV"], "middle")
                self.assertEqual(after["height"], 40)
                self.assertEqual({k: v for k, v in before.items() if k != "height"},
                                 {k: v for k, v in after.items() if k != "height"},
                                 "glyph center, font, text, style, width and stacking must stay unchanged")
        self.assertEqual(changed, ["card-title", "card-type"])

    def test_candidate_is_idempotent(self):
        original = json.loads((ROOT / "art/spikes/card-editor/card.source.json").read_text(encoding="utf-8"))
        candidate = spike.native_text_height_candidate(original)
        self.assertEqual(spike.native_text_height_candidate(candidate), candidate)

    def test_exported_candidate_changes_only_the_two_heights(self):
        output = ROOT / "art/spikes/card-editor"
        original = json.loads((output / "card.json").read_text(encoding="utf-8"))
        actual = json.loads((output / "text-height-compat/card.json").read_text(encoding="utf-8"))
        self.assertEqual(actual, spike.native_text_height_candidate(original))
        self.assertEqual((output / "card.png").read_bytes(),
                         (output / "text-height-compat/card.png").read_bytes(),
                         "Pillow appearance comparison only; not a native platform rendering assertion")


if __name__ == "__main__":
    unittest.main()
