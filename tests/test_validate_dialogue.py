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


    def test_journal_entry_requires_nonempty_id(self):
        for value in (None, 4, [], {}, "", "   "):
            self.assertTrue(self.validate({"start": {"journal_entry": value, "next": None}})[0])
        self.assertEqual(self.validate({"start": {"journal_entry": "keeper_log", "next": None}}), ([], []))

    def test_routing_cannot_discover_unshown_logs(self):
        graph = self.graph()
        graph["start"]["journal_entry"] = "keeper_log"
        self.assertTrue(self.validate(graph)[0])

    def test_journal_only_graph_has_an_entry_point(self):
        graph = {"entry_keeper": {"next": "page"}, "page": {"next": None}}
        self.assertEqual(self.validate(graph), ([], []))

    def test_journal_entry_requires_its_own_reachable_terminal(self):
        graph = {"entry_loop": {"next": "entry_loop"}, "unrelated_end": {"next": None}}
        errors, warnings = self.validate(graph)
        self.assertIn("test.json:entry_loop: no reachable terminal", errors)
        self.assertTrue(any(":unrelated_end: unreachable" in warning for warning in warnings))
        self.assertFalse(any("no known entry point" in warning for warning in warnings))

    def test_mixed_normal_and_journal_entries_contribute_to_reachability(self):
        graph = {"start": {"next": "normal_end"}, "normal_end": {"next": None},
                 "entry_one": {"choices": [{"text": "Read", "next": "journal_end"}]},
                 "entry_two": {"branches": [{"when": {"skeptic": True}, "next": "journal_end"}],
                               "next": "journal_end"},
                 "journal_end": {"next": None}, "orphan": {"next": None}}
        errors, warnings = self.validate(graph)
        self.assertEqual(errors, [])
        self.assertEqual(len(warnings), 1)
        self.assertIn(":orphan: unreachable", warnings[0])

    def test_each_journal_entry_is_checked_even_when_another_can_end(self):
        graph = {"entry_ok": {"next": None}, "entry_stuck": {"next": "entry_stuck"}}
        errors, warnings = self.validate(graph)
        self.assertEqual(errors, ["test.json:entry_stuck: no reachable terminal"])
        self.assertEqual(warnings, [])

    def test_similar_names_do_not_count_as_journal_entries(self):
        errors, warnings = self.validate({"entryish": {"next": None}})
        self.assertEqual(errors, [])
        self.assertTrue(any("no known entry point" in warning for warning in warnings))
