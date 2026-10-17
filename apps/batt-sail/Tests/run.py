#!/usr/bin/env python3
"""Run regression checks with Command Line Tools; XCTest/full Xcode not required."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
subprocess.run(["swift", "build"], cwd=root, check=True)
bin_path = Path(subprocess.check_output(["swift", "build", "--show-bin-path"], cwd=root, text=True).strip())
with tempfile.TemporaryDirectory(prefix="batt-sail-tests-") as directory:
    temp = Path(directory)
    source = (root / "Sources/BattSail/main.swift").read_text()
    entry = "BattSail.main()"
    assert source.rstrip().endswith(entry)
    source = source.rstrip()[:-len(entry)]
    (temp / "main.swift").write_text(source + "\n" + (root / "Tests/HysteresisTests.swift").read_text())
    objects = sorted((bin_path / "ArgumentParser.build").glob("*.o"))
    objects += sorted((bin_path / "ArgumentParserToolInfo.build").glob("*.o"))
    assert objects, "ArgumentParser object files missing"
    subprocess.run(["swiftc", "-I", str(bin_path / "Modules"), str(temp / "main.swift"),
                    str(root / "Sources/BattSail/SMC.swift"), *map(str, objects),
                    "-o", str(temp / "checks")], cwd=root, check=True)
    subprocess.run([str(temp / "checks")], check=True)
