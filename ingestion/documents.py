# Read Markdown documents from a local folder.
# Return each document's filename and text for later ingestion steps.
# Skip empty files and report a missing folder.
# Represent each document with clearly named fields.
from dataclasses import dataclass

# Work with file paths on Windows and Linux.
from pathlib import Path


# Store the information read from one source document.
@dataclass(frozen=True)
class Document:

    # Keep the original filename for source references.
    source: str

    # Keep the document text for later processing.
    text: str


# Read Markdown documents from a supplied local folder.
def load_documents(directory: Path) -> list[Document]:

    # Report a missing or invalid directory clearly.
    if not directory.is_dir():
        raise FileNotFoundError(
            f"Document directory does not exist: {directory}"
        )

    # Collect the documents that contain usable text.
    documents = []

    # Read Markdown files in a predictable order.
    # This first version reads only the supplied folder.
    for file_path in sorted(directory.glob("*.md")):

        # Ignore directories whose names happen to end in .md.
        if not file_path.is_file():
            continue

        # Read UTF-8 text and remove surrounding whitespace.
        text = file_path.read_text(encoding="utf-8").strip()

        # Skip files containing no usable text.
        if not text:
            continue

        # Preserve both the source filename and its contents.
        documents.append(
            Document(
                source=file_path.name,
                text=text,
            )
        )

    # Return the documents to the caller.
    return documents