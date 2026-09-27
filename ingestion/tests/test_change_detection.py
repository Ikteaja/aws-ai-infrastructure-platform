# Test document change detection using small in-memory examples.
# These tests do not modify the hospital sample documents.

import pytest

# Import the document structure and change-detection functions.
from ingestion.documents import Document
from ingestion.change_detection import build_snapshot, detect_changes


# Test the first run, when no previous snapshot exists.
def test_first_run_identifies_new_documents():

    # Prepare one document.
    current = build_snapshot([
        Document(source="overview.md", text="CareRoster overview."),
    ])

    # Compare against an empty previous snapshot.
    result = detect_changes(previous={}, current=current)

    # The document must be classified as new.
    assert result.new == ["overview.md"]
    assert result.changed == []
    assert result.unchanged == []
    assert result.removed == []


# Test a later run containing all four change categories.
def test_detects_new_changed_unchanged_and_removed_documents():

    # Represent the documents from an earlier run.
    previous = build_snapshot([
        Document(source="overview.md", text="CareRoster overview."),
        Document(source="runbook.md", text="Contact Team A."),
        Document(source="old-guide.md", text="Old guidance."),
    ])

    # Represent the documents available now.
    current = build_snapshot([
        Document(source="overview.md", text="CareRoster overview."),
        Document(source="runbook.md", text="Contact Team B."),
        Document(source="recovery.md", text="Verify login."),
    ])

    # Compare the two snapshots.
    result = detect_changes(previous=previous, current=current)

    # Confirm the exact classification of every document.
    assert result.new == ["recovery.md"]
    assert result.changed == ["runbook.md"]
    assert result.unchanged == ["overview.md"]
    assert result.removed == ["old-guide.md"]


# Test a repeated run without document changes.
def test_repeated_content_is_unchanged():

    # Build the two snapshots separately from identical text.
    previous = build_snapshot([
        Document(source="runbook.md", text="Check login."),
    ])

    current = build_snapshot([
        Document(source="runbook.md", text="Check login."),
    ])

    result = detect_changes(previous=previous, current=current)

    # No document needs content processing.
    assert result.new == []
    assert result.changed == []
    assert result.unchanged == ["runbook.md"]
    assert result.removed == []


# Test that duplicate source names cannot silently overwrite data.
def test_duplicate_sources_are_rejected():

    documents = [
        Document(source="runbook.md", text="First document."),
        Document(source="runbook.md", text="Different document."),
    ]

    with pytest.raises(ValueError, match="Duplicate document source"):
        build_snapshot(documents)