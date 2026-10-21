"""Run complete recipe scripts with isolated commands, no network or installers."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = sorted(
    p
    for p in (ROOT / "harbor_cookbook/recipes").rglob("*.sh")
    if "https://astral.sh/uv/0.13.4/install.sh" in p.read_text()
)


class AuthenticatedBootstrapTests(unittest.TestCase):
    def run_recipe(self, script, mode, verifier_exit=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = root / "bin"
            binaries.mkdir()
            logs = root / "logs/verifier"
            logs.mkdir(parents=True)
            (logs / "reward.txt").write_text("1\n")
            (logs / "reward.json").write_text('{"correctness":1,"performance":1}')
            home = root / "home"
            (home / ".local/bin").mkdir(parents=True)
            (home / ".local/bin/env").write_text('echo sourced >> "$TRACE"\n')
            scratch = root / "scratch"
            scratch.mkdir()
            commands = {
                "apt-get": "exit 0",
                "curl": """echo download >> "$TRACE"
while [ "$1" != -o ]; do shift; done
printf '#!/bin/sh\\nexit 0\\n' > "$2"
[ "$MODE" != download ]""",
                "sha256sum": """echo checksum >> "$TRACE"
cat > /dev/null
[ "$MODE" != checksum ]""",
                "sh": 'echo installer >> "$TRACE"; [ "$MODE" != installer ]',
                "uv": 'echo verifier >> "$TRACE"; exit "$VERIFIER_EXIT"',
                "uvx": 'echo verifier >> "$TRACE"; exit "$VERIFIER_EXIT"',
            }
            for name, body in commands.items():
                binary = binaries / name
                binary.write_text("#!/bin/bash\n" + body + "\n")
                binary.chmod(0o755)
            copy = root / "recipe.sh"
            copy.write_text(script.read_text().replace("/logs/verifier", str(logs)))
            trace = root / "trace"
            result = subprocess.run(
                ["bash", str(copy)],
                cwd=root,
                capture_output=True,
                text=True,
                env=dict(
                    os.environ,
                    PATH=str(binaries) + os.pathsep + os.environ["PATH"],
                    HOME=str(home),
                    TMPDIR=str(scratch),
                    TRACE=str(trace),
                    MODE=mode,
                    VERIFIER_EXIT=str(verifier_exit),
                ),
            )
            events = trace.read_text().splitlines()
            self.assertFalse(list(scratch.iterdir()))
            if mode != "success":
                self.assertNotEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("sourced", events)
                self.assertNotIn("verifier", events)
                expected = {
                    "download": ["download"],
                    "checksum": ["download", "checksum"],
                    "installer": ["download", "checksum", "installer"],
                }
                self.assertEqual(events, expected[mode])
            else:
                self.assertEqual(
                    events[:4], ["download", "checksum", "installer", "sourced"]
                )
                self.assertIn("verifier", events)
            if "/tests/" in str(script):
                expected_reward = 1 if mode == "success" and verifier_exit == 0 else 0
                if "/multi-reward/" in str(script):
                    self.assertEqual(
                        json.loads((logs / "reward.json").read_text()),
                        {
                            "correctness": expected_reward,
                            "performance": expected_reward,
                        },
                    )
                else:
                    self.assertEqual(
                        (logs / "reward.txt").read_text().strip(), str(expected_reward)
                    )

    def test_all_recipes_refuse_cached_tools_after_each_bootstrap_failure(self):
        self.assertEqual(len(SCRIPTS), 10)
        for script in SCRIPTS:
            for mode in ("download", "checksum", "installer"):
                with self.subTest(script=str(script.relative_to(ROOT)), mode=mode):
                    self.run_recipe(script, mode)

    def test_success_and_pytest_failure_keep_reward_handling(self):
        for script in SCRIPTS:
            for exit_code in (0, 1):
                with self.subTest(
                    script=str(script.relative_to(ROOT)), verifier_exit=exit_code
                ):
                    self.run_recipe(script, "success", exit_code)


if __name__ == "__main__":
    unittest.main()
