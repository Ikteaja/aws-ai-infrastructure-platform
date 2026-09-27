# Compare document fingerprints to identify changes between snapshots.
# This module does not modify documents or save processing state.
# Store the comparison results in clearly named fields.
from dataclasses import dataclass

# Calculate a repeatable fingerprint from document text.
from hashlib import sha256

# Use the document structure provided by our loader.
from ingestion.documents import Document


# Describe the differences between two document snapshots.
@dataclass(frozen=True)
class DocumentChanges:

    # Documents that were not in the previous snapshot.
    new: list[str]

    # Existing documents whose text has changed.
    changed: list[str]

    # Existing documents whose text remains the same.
    unchanged: list[str]

    # Documents no longer present in the current snapshot.
    removed: list[str]


# Build a mapping of source filenames to text fingerprints.
def build_snapshot(documents: list[Document]) -> dict[str, str]:

    snapshot = {}

    for document in documents:

        # Reject duplicate source names instead of overwriting a record.
        if document.source in snapshot:
            raise ValueError(
                f"Duplicate document source: {document.source}"
            )

        # Convert text to bytes and calculate its SHA-256 fingerprint.
        fingerprint = sha256(
            document.text.encode("utf-8")
        ).hexdigest()

        # Associate the fingerprint with its source document.
        snapshot[document.source] = fingerprint

    return snapshot


# Compare the previous snapshot with the current snapshot.
def detect_changes(
    previous: dict[str, str],
    current: dict[str, str],
) -> DocumentChanges:

    # Convert source names into sets for comparison.
    previous_sources = set(previous)
    current_sources = set(current)

    # Identify documents present in both snapshots.
    shared_sources = previous_sources & current_sources

    return DocumentChanges(

        # Present now, but absent previously.
        new=sorted(current_sources - previous_sources),

        # Present in both, but with different fingerprints.
        changed=sorted(
            source
            for source in shared_sources
            if previous[source] != current[source]
        ),

        # Present in both, with identical fingerprints.
        unchanged=sorted(
            source
            for source in shared_sources
            if previous[source] == current[source]
        ),

        # Present previously, but absent now.
        removed=sorted(previous_sources - current_sources),
    )