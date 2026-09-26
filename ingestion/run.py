# Run a local document scan and remember its fingerprints.
# This command reports changes; it does not create a search index.

import argparse
from pathlib import Path

from ingestion.documents import load_documents
from ingestion.change_detection import (
    DocumentChanges,
    build_snapshot,
    detect_changes,
)
from ingestion.state import load_state, save_state


# Perform one complete scan and save its comparison baseline.
def scan_documents(
    source_directory: Path,
    state_path: Path,
) -> DocumentChanges:

    # Read the previous successful scan.
    previous = load_state(state_path, source_directory)

    # Load all supported documents before changing saved state.
    # A loading failure stops the run.
    documents = load_documents(source_directory)

    # Calculate current fingerprints and compare them.
    current = build_snapshot(documents)
    changes = detect_changes(previous=previous, current=current)

    # Save only after loading and comparison have succeeded.
    save_state(state_path, source_directory, current)

    return changes


# Provide a command-line interface.
def main() -> int:

    parser = argparse.ArgumentParser(
        description="Compare local documents with a saved scan."
    )

    parser.add_argument(
        "--source",
        type=Path,
        required=True,
        help="Folder containing Markdown source documents.",
    )

    parser.add_argument(
        "--state",
        type=Path,
        required=True,
        help="JSON file used to remember the previous scan.",
    )

    args = parser.parse_args()

    try:
        changes = scan_documents(args.source, args.state)

    except (OSError, ValueError) as exc:
        # Print a clear error and exit unsuccessfully.
        parser.exit(status=1, message=f"Scan failed: {exc}\n")

    # Display counts and filenames for each category.
    for label, sources in (
        ("New", changes.new),
        ("Changed", changes.changed),
        ("Unchanged", changes.unchanged),
        ("Removed from snapshot", changes.removed),
    ):
        print(f"{label}: {len(sources)}")

        for source in sources:
            print(f"  - {source}")

    print(f"Scan state saved to: {args.state}")
    print("This records a scan baseline; no indexing was performed.")

    return 0


# Run main only when this module is executed as a command.
if __name__ == "__main__":
    raise SystemExit(main())