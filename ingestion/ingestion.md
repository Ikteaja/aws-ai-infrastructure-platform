# Document Ingestion

Part of the **Healthcare Operations & Resilience Assistant** in `aws-ai-infrastructure-platform`.

This module prepares hospital operations documents for future search and question answering. It currently reads local Markdown files and compares document fingerprints to identify changes.

**Current milestone:** the document loader, change detection, persistent local state and command-line scan are implemented. Document indexing and integration with `/ask` are not implemented yet.

## 1. Why this module exists

Hospital IT teams need the correct approved procedure when an application becomes unavailable. The assistant will need reliable source documents before it can provide useful guidance.

Example: Hospital A updates its CareRoster login runbook from “Contact Team A” to “Contact Team B.” Ingestion should recognize the change so the searchable knowledge can eventually be updated.

The intended outcome is to process new or changed content without unnecessarily generating embeddings again for unchanged content.

Our sample hospital, application and procedures are fictional. They are development and test data, not approved instructions for a real hospital.

## 2. Current capabilities and boundaries

| Capability | Current status |
| --- | --- |
| Read local `.md` files | Implemented |
| Preserve source filenames and document text | Implemented |
| Skip empty files and unsupported file types | Implemented |
| Report a missing source folder | Implemented |
| Calculate a SHA-256 fingerprint of loaded text | Implemented |
| Compare new, changed, unchanged and removed sources | Implemented |
| Reject duplicate source names within a snapshot | Implemented |
| Save and reload fingerprints between runs | Implemented |
| Run a scan from the command line | Implemented |
| Read documents from S3 or SharePoint | Planned |
| Parse and enforce document approval and access metadata | Planned |
| Split documents into searchable sections and generate embeddings | Planned |
| Write to a search index and provide evidence to `/ask` | Planned |

The loader does not call an AI model. Change detection does not change or delete files.

## 3. File mapping

Paths below are relative to the repository root.

| Path | Responsibility |
| --- | --- |
| `ingestion/__init__.py` | Marks ingestion as a Python package |
| `ingestion/documents.py` | Defines `Document` and loads local Markdown documents |
| `ingestion/change_detection.py` | Builds fingerprints and compares snapshots |
| `ingestion/state.py` | Validates and safely reads or saves scan state as JSON |
| `ingestion/run.py` | Runs a scan from the command line and reports its results |
| `ingestion/tests/test_documents.py` | Tests the loader with temporary files |
| `ingestion/tests/test_change_detection.py` | Tests comparisons with in-memory documents |
| `ingestion/tests/test_state.py` | Tests state validation, persistence and save failures |
| `ingestion/tests/test_run.py` | Tests repeated scans and source-load failure handling |
| `sample_data/hospital-a/careroster/` | Contains the three fictional hospital documents |
| `.github/workflows/ai-app-ci.yml` | Runs ingestion tests as part of application CI |

Place test files inside `ingestion/tests/`. The CI command searches that directory.

## 4. Sample documents

| File | Purpose | Example question it supports |
| --- | --- | --- |
| `01-application-overview.md` | Application purpose, dependencies and ownership | Which team supports authentication? |
| `02-login-failure-runbook.md` | Investigation and escalation steps | What should we check when login fails? |
| `03-recovery-checklist.md` | Technical and operational recovery checks | Does a successful health check prove recovery? |

These files stay in Git so developers and automated tests can use repeatable sample content. A future hospital deployment will read authorized documents from an approved document repository or private storage. A production document update should trigger ingestion without requiring an application code commit or Docker rebuild.

## 5. How the current workflow works

1. A caller supplies a local folder to `load_documents(directory)`.
2. The loader checks that the folder exists.
3. It selects `.md` files directly inside that folder and sorts them by filename.
4. It reads each file as UTF-8, removes surrounding whitespace and skips empty text.
5. It returns `Document` objects containing `source` and `text`.
6. The caller passes those objects to `build_snapshot(documents)`.
7. The function maps each source filename to its text fingerprint.
8. The caller passes a previous and current snapshot to `detect_changes(previous, current)`.
9. The function returns four lists: `new`, `changed`, `unchanged` and `removed`.

A **snapshot** is a dictionary of source filenames and fingerprints. It does not contain a full copy of the documents.

A **fingerprint** is a repeatable value calculated from text. Identical loaded text gives the same fingerprint; changed loaded text gives a different fingerprint in normal use.

| Comparison | Classification |
| --- | --- |
| Source appears only in the current snapshot | `new` |
| Source exists in both snapshots with different fingerprints | `changed` |
| Source exists in both snapshots with identical fingerprints | `unchanged` |
| Source appears only in the previous snapshot | `removed` |

These helper functions compare snapshots in memory. The command-line scan described next loads the prior snapshot from a JSON file and saves the new one for a later run.

## 6. Persistent state and runnable document scan

The command-line scan remembers the previous comparison baseline in a local JSON file. It stores source filenames and content fingerprints, not document text or indexing results. The fingerprint details are described in section 5.

### Scan workflow

1. Read and validate the saved snapshot. If the state file does not exist, use an empty snapshot for the first run.
2. Load the current Markdown documents and calculate their fingerprints.
3. Compare the current snapshot with the previous one.
4. Save the new snapshot only after loading and comparison succeed.
5. Print counts and filenames for new, changed, unchanged and removed sources.

Malformed state, unsupported state versions and state belonging to a different source folder cause the scan to fail. The command does not silently discard the previous baseline. A missing or unreadable source folder also fails without replacing saved state.

### Example: Hospital A login procedure

The sample contains an application overview, a login-failure procedure and a recovery checklist. With the same state path on each run, expected classifications are:

| Scenario | Expected scan result |
| --- | --- |
| First scan with no saved state | Three new documents |
| Scan again without editing files | Three unchanged documents |
| Edit the login-failure procedure | One changed and two unchanged documents |
| Add another non-empty Markdown document | One new document |
| Remove a document | That source is reported as removed from the snapshot |

“Removed” means absent from the current loaded snapshot. An empty document or a file that no longer has a `.md` extension is not loaded and can therefore also appear as removed. A missing source folder fails the scan instead of treating every document as removed.

### Run the scan

Run from the repository root in PowerShell, using the same state path on later runs:

```powershell
python -m ingestion.run `
    --source sample_data/hospital-a/careroster `
    --state .local/ingestion/hospital-a-careroster.json
```

On the first run, the three sample documents are new. On an unchanged later run, they are unchanged. The command reports counts and source filenames, then confirms the state path. It records a scan baseline only; it does not create embeddings, delete indexed content or make documents searchable through the API.

The state file is local runtime data and `.local/ingestion/` is excluded by `.gitignore`.

## 7. Run the loader on the sample documents

Run all commands from the **repository root**, not from inside `ingestion/`.

Use the project's existing virtual environment with pytest installed. The loader and change detector use Python's standard library; they do not need additional runtime packages.

### Step 1 — Confirm the files are present

```powershell
Get-ChildItem .\sample_data\hospital-a\careroster\*.md
```

Expected: the three Markdown files listed above.

### Step 2 — Read the sample documents

```powershell
python -c "from pathlib import Path; from ingestion.documents import load_documents; docs = load_documents(Path('sample_data/hospital-a/careroster')); print(f'{len(docs)} documents loaded successfully.'); print('\n'.join(doc.source for doc in docs))"
```

Expected output:

```text
3 documents loaded successfully.
01-application-overview.md
02-login-failure-runbook.md
03-recovery-checklist.md
```

This checks the actual sample folder. It does not create embeddings or make those documents searchable through the API.

## 8. Try change detection without editing your files

Paste this complete block into PowerShell from the repository root:

```powershell
@'
from ingestion.documents import Document
from ingestion.change_detection import build_snapshot, detect_changes

# Represent a document before an update.
previous = build_snapshot([
    Document(source="runbook.md", text="Contact Team A."),
])

# Represent the same document after an update.
current = build_snapshot([
    Document(source="runbook.md", text="Contact Team B."),
])

# Compare the text fingerprints.
result = detect_changes(previous=previous, current=current)

print("New:", result.new)
print("Changed:", result.changed)
print("Unchanged:", result.unchanged)
print("Removed:", result.removed)
'@ | python -
```

Expected output:

```text
New: []
Changed: ['runbook.md']
Unchanged: []
Removed: []
```

The example creates Python objects only. It does not write or modify `runbook.md` on disk.

## 9. Run the automated tests

### Loader tests only

```powershell
python -m pytest ingestion/tests/test_documents.py -v
```

Expected: **3 passed**.

### Change-detection tests only

```powershell
python -m pytest ingestion/tests/test_change_detection.py -v
```

Expected: **4 passed**.

### All ingestion tests

```powershell
python -m pytest ingestion/tests -v
```

Expected: **15 passed** for the current implementation.

| Test | What it verifies |
| --- | --- |
| `test_load_documents_preserves_text_and_source` | Correct filenames, text and filename order |
| `test_load_documents_skips_empty_and_non_markdown_files` | Empty Markdown and `.txt` files are skipped |
| `test_load_documents_rejects_missing_directory` | A missing folder raises an error |
| `test_first_run_identifies_new_documents` | An empty previous snapshot classifies current documents as new |
| `test_detects_new_changed_unchanged_and_removed_documents` | All four classifications are correct |
| `test_repeated_content_is_unchanged` | Identical text is classified as unchanged |
| `test_duplicate_sources_are_rejected` | Duplicate source names raise an error instead of overwriting a record |
| `test_missing_state_returns_empty_snapshot`, `test_state_round_trip` | Missing state starts empty; saved fingerprints can be loaded again |
| State validation and save-failure tests | Invalid state is rejected and a failed save preserves the prior state |
| `test_command_remembers_documents_between_runs` | Separate command runs share state and detect later document changes |
| `test_missing_source_preserves_state` | A missing source folder does not replace the saved baseline |

Tests use temporary files and in-memory document objects; they do not modify the hospital sample documents or require a running API, model service, Docker container or Kubernetes cluster.

## 10. GitHub Actions integration

The existing ingestion step is:

```yaml
      # Test document loading and change detection.
      - name: Run ingestion document-loader tests
        run: python -m pytest ingestion/tests -v
```

Although the step name mentions the loader, its command discovers all four test modules in the directory, including the state and command-line tests. It can optionally be renamed to `Run ingestion tests` for clarity; do not add a duplicate step.

To verify a run:

1. Open the pull request's GitHub Actions check.
2. Expand the ingestion test step.
3. Confirm `collected 15 items` and `15 passed`.
4. Confirm that the run includes the commit containing the state and command-line implementation.

The current 15-test suite has been confirmed locally; verify the updated CI run after pushing the new code.

## 11. Current limitations

- **One folder per load:** nested folders are not scanned.
- **Markdown only:** PDFs, Word documents and images need additional readers.
- **Text fingerprints:** the loader strips surrounding whitespace and normalizes line endings while reading text. The fingerprint is of loaded text, not raw file bytes.
- **Filename identity:** renaming a file appears as one removed source and one new source. A future multi-source design needs stable IDs scoped to each source or hospital.
- **Missing from snapshot is not proven deletion:** an empty file is skipped by the loader and can therefore appear as removed.
- **No automatic cleanup:** change detection only reports differences. It does not delete indexed content.
- **No access enforcement yet:** metadata written inside Markdown is currently plain text. Approval and permissions are not validated by these functions.
- **Local state only:** the JSON baseline is specific to a source folder on this machine; shared or cloud-backed state is not implemented.

Before adding index deletion, require a successfully completed, authoritative source scan or an explicit deletion event. A failed or incomplete source read must not cause mass deletion.

## 12. Troubleshooting

| Symptom | Likely cause | What to check |
| --- | --- | --- |
| `No module named ingestion.change_detection` | Implementation missing, misnamed or unsaved | Confirm `ingestion/change_detection.py` exists and save it |
| `No module named ingestion` | Wrong working directory or package layout | Run from the repository root; check `ingestion/__init__.py` |
| `collected 0 items` | Tests missing, unsaved or incorrectly named | Check `test_*.py` filenames and top-level `def test_...` functions |
| `file or directory not found: ingestion/tests` in CI | Correct folder not committed or wrong commit checked out | Confirm tracked paths and the workflow's commit |
| `Document directory does not exist` | Incorrect source path | Check the folder path relative to the repository root |
| Fewer documents loaded than expected | Empty files, unsupported extensions or nested files | Inspect the source folder and file contents |
| `Duplicate document source` | Two input documents share a source name | Provide unique source identifiers within the snapshot |
| `Scan failed` for invalid or mismatched state | Corrupt state, unsupported schema or a different source folder | Check the `--state` path and source folder; preserve the file unless intentionally resetting the baseline |

Useful checks:

```powershell
# Show tracked ingestion files.
git ls-files ingestion

# Confirm both implementation modules exist.
Test-Path .\ingestion\documents.py
Test-Path .\ingestion\change_detection.py

# List the saved test files.
Get-ChildItem .\ingestion\tests\test_*.py
```

## 13. Next milestones

| Order | Milestone | Acceptance check |
| --- | --- | --- |
| 1 | Create private S3 storage with Terraform | Sample documents are stored in the cloud with controlled access |
| 2 | Add an S3 source connector | Existing comparison logic works with documents read from S3 |
| 3 | Add processing and indexing | New or changed documents become searchable |
| 4 | Add independent cloud processing | Uploads trigger work without redeploying FastAPI |

The local state file records a successful comparison baseline, not that content is indexed. Once indexing exists, processing state must advance only after the corresponding processing succeeds. Generated runtime state should remain excluded from Git.

**Milestone goal:** reliably determine which document content needs work before adding persistent processing and cloud storage.
