# Save and reload document fingerprints between program runs.
# This state records a successful scan, not completed indexing.

import json
import os
import re
import tempfile
from pathlib import Path


# Check that the state contains source names and SHA-256 fingerprints.
def validate_snapshot(snapshot: object) -> dict[str, str]:

    if not isinstance(snapshot, dict):
        raise ValueError("State documents must be a dictionary.")

    for source, fingerprint in snapshot.items():

        if not isinstance(source, str) or not source:
            raise ValueError("State contains an invalid document source.")

        if (
            not isinstance(fingerprint, str)
            or re.fullmatch(r"[0-9a-f]{64}", fingerprint) is None
        ):
            raise ValueError("State contains an invalid fingerprint.")

    return snapshot


# Read the previous snapshot for this particular source folder.
def load_state(
    state_path: Path,
    source_directory: Path,
) -> dict[str, str]:

    try:
        content = state_path.read_text(encoding="utf-8")

    except FileNotFoundError:
        # A missing state file means this is the first run.
        return {}

    # Invalid JSON raises an error.
    # It must not be interpreted as an empty previous snapshot.
    data = json.loads(content)

    if not isinstance(data, dict):
        raise ValueError("State must contain a JSON object.")

    if data.get("schema_version") != 1:
        raise ValueError("Unsupported state schema version.")

    # Use the resolved path to identify the local source folder.
    expected_source = str(source_directory.resolve())

    if data.get("source_directory") != expected_source:
        raise ValueError("State belongs to a different source directory.")

    return validate_snapshot(data.get("documents"))


# Save a snapshot without directly overwriting the previous file.
def save_state(
    state_path: Path,
    source_directory: Path,
    snapshot: dict[str, str],
) -> None:

    # Validate before creating or replacing any file.
    validate_snapshot(snapshot)

    data = {
        "schema_version": 1,
        "source_directory": str(source_directory.resolve()),
        "documents": snapshot,
    }

    # Create the state directory if necessary.
    state_path.parent.mkdir(parents=True, exist_ok=True)

    temporary_path = None

    try:
        # Write beside the destination so replacement stays
        # on the same filesystem.
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=state_path.parent,
            prefix=f".{state_path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:

            temporary_path = Path(temporary_file.name)

            json.dump(
                data,
                temporary_file,
                indent=2,
                sort_keys=True,
                ensure_ascii=False,
            )

            temporary_file.write("\n")
            temporary_file.flush()
            os.fsync(temporary_file.fileno())

        # Replace the old state only after the new file is complete.
        os.replace(temporary_path, state_path)

    finally:
        # Remove a temporary file left behind after a failed save.
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)