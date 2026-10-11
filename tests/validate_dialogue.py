#!/usr/bin/env python3
"""Validate Tidewrack dialogue graphs without needing the Godot engine.

Checks, for every data/dialogue/*.json file:
  - it parses as a JSON object of node_id -> node
  - each node is either a linear node ("next": id|null) or a choice node
    ("choices": [{text, next, set_flag?}]) — not neither, not both
  - routing nodes have branches with flag conditions and a fallback next
  - every referenced target id exists
  - at least one terminal (next == null) is reachable from an entry point
  - reports orphan nodes (unreachable from any known entry) as warnings

Exit code 0 = all valid, 1 = at least one error.

Usage:  python3 tests/validate_dialogue.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Entry-point node ids the game starts graphs from (see scripts/game.gd).
KNOWN_ENTRIES = {"logbook", "radio", "door", "start"}

ROOT = Path(__file__).resolve().parent.parent
DIALOGUE_DIR = ROOT / "data" / "dialogue"


def targets(node: object) -> list:
    """Enumerate all authored edges, tolerating malformed nodes for diagnostics."""
    if not isinstance(node, dict):
        return []
    result = [node["next"]] if "next" in node else []
    for field in ("choices", "branches"):
        edges = node.get(field, [])
        if isinstance(edges, list):
            result.extend(edge.get("next") for edge in edges if isinstance(edge, dict))
    return result


def reachable(graph: dict, entries: set[str]) -> set[str]:
    seen: set[str] = set()
    stack = [e for e in entries if e in graph]
    while stack:
        nid = stack.pop()
        if nid in seen:
            continue
        seen.add(nid)
        for t in targets(graph[nid]):
            if isinstance(t, str) and t in graph:
                stack.append(t)
    return seen


def validate_file(path: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    try:
        graph = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        return [f"{path.name}: invalid JSON — {exc}"], warnings

    if not isinstance(graph, dict):
        return [f"{path.name}: top level must be an object of node_id -> node"], warnings

    has_terminal = False
    for nid, node in graph.items():
        if not isinstance(node, dict):
            errors.append(f"{path.name}:{nid}: node must be an object")
            continue

        if "set_flag" in node and not isinstance(node["set_flag"], dict):
            errors.append(f"{path.name}:{nid}: set_flag must be an object")
        if "journal_entry" in node:
            entry = node["journal_entry"]
            if not isinstance(entry, str) or not entry.strip():
                errors.append(f"{path.name}:{nid}: journal_entry must be a nonempty string")
        if "branches" in node:
            branches = node["branches"]
            if not isinstance(branches, list) or not branches:
                errors.append(f"{path.name}:{nid}: branches must be a nonempty array")
            else:
                for i, branch in enumerate(branches):
                    if not isinstance(branch, dict):
                        errors.append(f"{path.name}:{nid}: branch #{i} must be an object")
                        continue
                    when = branch.get("when")
                    if not isinstance(when, dict) or not when:
                        errors.append(f"{path.name}:{nid}: branch #{i} needs nonempty when flags")
                    target = branch.get("next")
                    if "next" not in branch or (target is not None and
                            (not isinstance(target, str) or target not in graph)):
                        errors.append(f"{path.name}:{nid}: branch #{i} needs a valid next target")
                    if "next" in branch and target is None:
                        has_terminal = True
            if "next" not in node:
                errors.append(f"{path.name}:{nid}: routing node needs a fallback next")
            if any(key in node for key in ("choices", "text", "speaker", "set_flag", "journal_entry")):
                errors.append(f"{path.name}:{nid}: routing node cannot show text, choices, or apply effects")

        has_choices = isinstance(node.get("choices"), list) and len(node["choices"]) > 0
        has_next = "next" in node

        if not has_choices and not has_next:
            errors.append(f"{path.name}:{nid}: node has neither 'next' nor 'choices'")
        if has_choices and has_next:
            errors.append(f"{path.name}:{nid}: node has both 'next' and 'choices' (ambiguous)")

        if has_next and node.get("next") is None:
            has_terminal = True

        if has_next and node["next"] is not None and (not isinstance(node["next"], str) or node["next"] not in graph):
            errors.append(f"{path.name}:{nid}: 'next' points to missing node '{node['next']}'")

        if has_choices:
            for i, choice in enumerate(node["choices"]):
                if not isinstance(choice, dict) or "text" not in choice:
                    errors.append(f"{path.name}:{nid}: choice #{i} needs a 'text' field")
                    continue
                if "set_flag" in choice and not isinstance(choice["set_flag"], dict):
                    errors.append(f"{path.name}:{nid}: choice #{i} set_flag must be an object")
                target = choice.get("next")
                if target is not None and (not isinstance(target, str) or target not in graph):
                    errors.append(f"{path.name}:{nid}: choice #{i} 'next' -> missing node '{target}'")
                if target is None:
                    has_terminal = True

    if not has_terminal:
        errors.append(f"{path.name}: no terminal node (a node with next == null) — the graph never ends")

    entries = KNOWN_ENTRIES & set(graph.keys())
    if not entries:
        warnings.append(f"{path.name}: no known entry point ({sorted(KNOWN_ENTRIES)}) present")
    else:
        seen = reachable(graph, entries)
        for entry in sorted(entries):
            reachable_nodes = reachable(graph, {entry})
            terminal_reachable = any(None in targets(graph[n]) for n in reachable_nodes)
            if not terminal_reachable:
                errors.append(f"{path.name}:{entry}: no reachable terminal")
        for orphan in sorted(set(graph) - seen):
            warnings.append(f"{path.name}:{orphan}: unreachable from entry points {sorted(entries)}")

    return errors, warnings


def main() -> int:
    files = sorted(DIALOGUE_DIR.glob("*.json"))
    if not files:
        print(f"No dialogue files found in {DIALOGUE_DIR}")
        return 1

    all_errors: list[str] = []
    all_warnings: list[str] = []
    for path in files:
        errs, warns = validate_file(path)
        all_errors += errs
        all_warnings += warns
        status = "OK" if not errs else "FAIL"
        print(f"[{status}] {path.relative_to(ROOT)}  ({len(json.loads(path.read_text()))} nodes)")

    for w in all_warnings:
        print(f"  warning: {w}")
    for e in all_errors:
        print(f"  ERROR:   {e}")

    print()
    if all_errors:
        print(f"✗ {len(all_errors)} error(s), {len(all_warnings)} warning(s)")
        return 1
    print(f"✓ all dialogue graphs valid ({len(all_warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
