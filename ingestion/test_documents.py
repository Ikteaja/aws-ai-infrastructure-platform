
# Test the document loader using temporary sample files.
# Verify that filenames and text are preserved, empty and unsupported
# files are skipped, and missing folders raise an error.
# pytest provides temporary folders and exception assertions.

import pytest

# Import the document loader we want to test.
from ingestion.documents import load_documents


# Test whether document text and source filenames are preserved.
def test_load_documents_preserves_text_and_source(tmp_path):

    # ARRANGE:
    # Create two documents in a temporary folder.
    (tmp_path / "02-runbook.md").write_text(
        "# Login Runbook\nCheck the identity service.",
        encoding="utf-8",
    )

    (tmp_path / "01-overview.md").write_text(
        "# Application Overview\nCareRoster scheduling.",
        encoding="utf-8",
    )

    # ACT:
    # Load the temporary documents.
    documents = load_documents(tmp_path)

    # ASSERT:
    # Confirm that both documents were loaded in filename order.
    assert [document.source for document in documents] == [
        "01-overview.md",
        "02-runbook.md",
    ]

    # Confirm that the document contents were preserved.
    assert documents[0].text == (
        "# Application Overview\nCareRoster scheduling."
    )

    assert documents[1].text == (
        "# Login Runbook\nCheck the identity service."
    )


# Test whether empty files and unsupported file types are skipped.
def test_load_documents_skips_empty_and_non_markdown_files(tmp_path):

    # Create one usable Markdown document.
    (tmp_path / "valid.md").write_text(
        "# Recovery Checklist",
        encoding="utf-8",
    )

    # Create an empty Markdown document.
    (tmp_path / "empty.md").write_text(
        "   \n",
        encoding="utf-8",
    )

    # Create a file that this loader does not support.
    (tmp_path / "notes.txt").write_text(
        "This text file should not be loaded.",
        encoding="utf-8",
    )

    # Load the folder.
    documents = load_documents(tmp_path)

    # Confirm that only the usable Markdown document was loaded.
    assert len(documents) == 1
    assert documents[0].source == "valid.md"


# Test whether a missing document directory is reported.
def test_load_documents_rejects_missing_directory(tmp_path):

    # Prepare a path that does not exist.
    missing_directory = tmp_path / "missing"

    # Confirm that the loader reports the missing directory.
    with pytest.raises(
        FileNotFoundError,
        match="Document directory does not exist",
    ):
        load_documents(missing_directory)