#!/usr/bin/env python3
"""Keep analyzer diagnostics fatal except the known SDK Material import transition.

The approved UI remains on Flutter's compatibility export until a coordinated
material_ui migration is scheduled. Do not suppress other deprecated members,
warnings, errors, or informational lints.
"""
import re
import subprocess
import sys

result = subprocess.run(["dart", "analyze", "--fatal-infos", *sys.argv[1:]],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        text=True)
print(result.stdout, end="")
if result.returncode == 0:
    sys.exit(0)
lines = [re.sub(r"\x1b\[[0-9;]*m", "", line) for line in result.stdout.splitlines()]
diagnostics = [line.strip() for line in lines
               if re.match(r"^\s*(info|warning|error)\s+-\s+", line)]
summary = [re.fullmatch(r"\s*(\d+) issues? found\.\s*", line) for line in lines]
counts = [int(match.group(1)) for match in summary if match]
if (result.returncode == 1 and diagnostics and counts == [len(diagnostics)]
    and all(line.startswith("info - ")
            and "'package:flutter/material.dart' is deprecated" in line
            and "package:material_ui/material_ui.dart" in line
            and line.endswith(" - deprecated_member_use") for line in diagnostics)):
    print("Only the documented Flutter Material import compatibility notices remain.")
    sys.exit(0)
sys.exit(result.returncode)
