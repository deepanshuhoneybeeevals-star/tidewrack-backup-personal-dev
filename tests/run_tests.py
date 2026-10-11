#!/usr/bin/env python3
"""Run graph and Godot regressions without touching the player's save slot.

Usage: python3 tests/run_tests.py --godot /path/to/godot
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(command, env):
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    print(result.stdout, end="")
    # Godot can return zero even when a GDScript failed to parse.
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
        raise SystemExit(result.returncode or 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="tidewrack-tests-") as directory:
        env = dict(os.environ, XDG_DATA_HOME=directory, TIDEWRACK_TEST_DATA=directory)
        run(["python3", "tests/validate_dialogue.py"], env)
        run(["python3", "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], env)
        run([args.godot, "--headless", "--path", ".", "--editor", "--import", "--quit"], env)
        run([args.godot, "--headless", "--path", ".", "tests/test_choice_carry.tscn"], env)
        run([args.godot, "--headless", "--path", ".", "tests/test_pause_menu.tscn"], env)
        run([args.godot, "--headless", "--path", ".", "tests/test_controller_input.tscn"], env)
        run([args.godot, "--headless", "--path", ".", "tests/test_lamp_room.tscn"], env)
        for mode in ("--journal-write", "--journal-read"):
            run([args.godot, "--headless", "--path", ".", "tests/test_choice_carry.tscn", "--", mode], env)

        for mode in ("--lamp-write", "--lamp-read"):
            run([args.godot, "--headless", "--path", ".", "tests/test_lamp_room.tscn", "--", mode], env)


if __name__ == "__main__":
    main()
