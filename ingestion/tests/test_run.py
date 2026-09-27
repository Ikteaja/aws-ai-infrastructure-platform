# Test the complete scan workflow with persistent state.
# Temporary documents are used instead of hospital sample files.

import subprocess
import sys
from pathlib import Path

import pytest

from ingestion.run import scan_documents


# Separate command executions must share the saved baseline.
def test_command_remembers_documents_between_runs(tmp_path):

    source_directory = tmp_path / "documents"
    source_directory.mkdir()

    document_path = source_directory / "runbook.md"
    document_path.write_text("Contact Team A.", encoding="utf-8")

    state_path = tmp_path / "state.json"

    command = [
        sys.executable,
        "-m",
        "ingestion.run",
        "--source",
        str(source_directory),
        "--state",
        str(state_path),
    ]

    # Locate the project root from this test file.
    project_root = Path(__file__).resolve().parents[2]

    def run_command():
        return subprocess.run(
            command,
            cwd=project_root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout

    # First process: the document is new.
    first_output = run_command()
    assert "New: 1" in first_output

    # Second process: it reads the previous state from disk.
    second_output = run_command()
    assert "New: 0" in second_output
    assert "Unchanged: 1" in second_output

    # Third process: the changed text must be detected.
    document_path.write_text("Contact Team B.", encoding="utf-8")

    third_output = run_command()
    assert "Changed: 1" in third_output


# An unreadable source must not erase the previous baseline.
def test_missing_source_preserves_state(tmp_path):

    source_directory = tmp_path / "documents"
    source_directory.mkdir()

    document_path = source_directory / "runbook.md"
    document_path.write_text("Check login.", encoding="utf-8")

    state_path = tmp_path / "state.json"

    scan_documents(source_directory, state_path)
    original_content = state_path.read_bytes()

    # Remove only the temporary test source.
    document_path.unlink()
    source_directory.rmdir()

    with pytest.raises(FileNotFoundError):
        scan_documents(source_directory, state_path)

    assert state_path.read_bytes() == original_content