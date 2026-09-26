# Test saving, loading and protecting document scan state.
# All files are created in pytest's temporary directory.

import json

import pytest

from ingestion.state import load_state, save_state


# A missing state file represents the first run.
def test_missing_state_returns_empty_snapshot(tmp_path):

    result = load_state(
        tmp_path / "state.json",
        tmp_path / "documents",
    )

    assert result == {}


# Saved fingerprints must survive loading in a later call.
def test_state_round_trip(tmp_path):

    state_path = tmp_path / "state" / "snapshot.json"
    source_directory = tmp_path / "documents"
    snapshot = {"runbook.md": "a" * 64}

    save_state(state_path, source_directory, snapshot)

    assert load_state(state_path, source_directory) == snapshot


# Corrupt state must not silently become an empty snapshot.
def test_invalid_json_is_rejected(tmp_path):

    state_path = tmp_path / "state.json"
    state_path.write_text("{broken", encoding="utf-8")

    with pytest.raises(ValueError):
        load_state(state_path, tmp_path / "documents")


# State from another source folder must not be reused accidentally.
def test_wrong_source_is_rejected(tmp_path):

    state_path = tmp_path / "state.json"

    save_state(
        state_path,
        tmp_path / "hospital-a",
        {"runbook.md": "a" * 64},
    )

    with pytest.raises(ValueError, match="different source"):
        load_state(state_path, tmp_path / "hospital-b")


# JSON can be valid while its fingerprint data is invalid.
def test_invalid_fingerprint_is_rejected(tmp_path):

    state_path = tmp_path / "state.json"
    source_directory = tmp_path / "documents"

    state_path.write_text(
        json.dumps({
            "schema_version": 1,
            "source_directory": str(source_directory.resolve()),
            "documents": {"runbook.md": "not-a-sha256"},
        }),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="invalid fingerprint"):
        load_state(state_path, source_directory)


# A failed replacement must preserve the previous state.
def test_failed_save_preserves_previous_state(tmp_path, monkeypatch):

    state_path = tmp_path / "state.json"
    source_directory = tmp_path / "documents"

    save_state(
        state_path,
        source_directory,
        {"runbook.md": "a" * 64},
    )

    original_content = state_path.read_bytes()

    def fail_replace(source, destination):
        raise OSError("Simulated replacement failure.")

    monkeypatch.setattr(
        "ingestion.state.os.replace",
        fail_replace,
    )

    with pytest.raises(OSError, match="replacement failure"):
        save_state(
            state_path,
            source_directory,
            {"runbook.md": "b" * 64},
        )

    assert state_path.read_bytes() == original_content
    assert list(tmp_path.glob(".state.json.*.tmp")) == []