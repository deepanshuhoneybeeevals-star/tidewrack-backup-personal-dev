import json
from pathlib import Path
import tempfile
import unittest

from validate_dialogue import validate_file


class RoutingValidationTests(unittest.TestCase):
    def validate(self, graph):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.json"
            path.write_text(json.dumps(graph))
            return validate_file(path)

    def graph(self):
        return {"start": {"branches": [{"when": {"trusted_edith": False}, "next": "quiet"}],
                          "next": "new"},
                "quiet": {"text": "Remember quiet", "next": None},
                "new": {"text": "First visit", "next": None}}

    def test_branch_target_is_reachable(self):
        self.assertEqual(self.validate(self.graph()), ([], []))

    def test_missing_branch_target(self):
        graph = self.graph()
        graph["start"]["branches"][0]["next"] = "missing"
        self.assertTrue(self.validate(graph)[0])

    def test_missing_fallback(self):
        graph = self.graph()
        del graph["start"]["next"]
        self.assertTrue(self.validate(graph)[0])

    def test_empty_or_invalid_condition(self):
        for condition in ({}, [], None):
            graph = self.graph()
            graph["start"]["branches"][0]["when"] = condition
            self.assertTrue(self.validate(graph)[0])

    def test_routing_cannot_hide_dialogue_or_effects(self):
        for field, value in (("text", "hidden"), ("set_flag", {"skeptic": True}), ("choices", [])):
            graph = self.graph()
            graph["start"][field] = value
            self.assertTrue(self.validate(graph)[0])

    def test_unreachable_terminal_does_not_make_entry_valid(self):
        graph = {"start": {"next": "start"}, "orphan": {"next": None}}
        self.assertTrue(self.validate(graph)[0])

    def test_malformed_choices_do_not_crash_reachability(self):
        graph = {"start": {"choices": [None, {"text": "End", "next": None}]}}
        self.assertTrue(self.validate(graph)[0])
