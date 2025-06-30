# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a bash-based Git toolkit that provides six core safety-first utilities for Git operations:
- `git-undo`: Safely undo commits while preserving changes in stashes
- `git-redo`: Restore previously undone commits from undo stashes  
- `git-stash`: Stash all changes including untracked files
- `git-clean-branches`: Clean up merged and orphaned branches
- `git-squash`: Squash all commits in a branch into the oldest commit
- `git-show`: Show branch fork points and pending commits

## Architecture

**Single File Structure**: All functions are defined in `git-toolkit.sh` using a shared utility pattern:
1. **Shared constants**: `PROTECTED_BRANCHES_PATTERN`, `DATE_FORMAT`
2. **Utility functions**: Prefixed with `_git_` for validation, confirmation, formatting
3. **Public functions**: Named `git-*` that follow the safety-first pattern:
   - Validation → Preview → Confirmation → Execution → Feedback

**Safety-First Pattern**: Every function validates repository state, shows what will happen, requires user confirmation, then executes with clear success/error reporting.

**Cross-Platform Compatibility**: Uses POSIX-compliant shell syntax, avoids bash-specific features, works on macOS/Linux/Unix.

## Development Commands

### Testing
```bash
# Run full test suite (63 tests across 8 categories)
./test-git-toolkit.sh

# Test specific function (modify test script to run individual test blocks)
# Tests are organized by function in the script with clear section headers
```

### Installation & Usage
```bash
# Source the toolkit in current shell
source git-toolkit.sh

# Add to shell profile for permanent installation
echo "source $(pwd)/git-toolkit.sh" >> ~/.bashrc
```

## Key Implementation Details

**Stash Management**: `git-undo` creates specially formatted stashes with metadata files that `git-redo` can identify and restore. Uses `"undo - TIMESTAMP - COMMIT_MSG"` naming pattern.

**Branch Protection**: All functions protect main/master/develop branches using `PROTECTED_BRANCHES_PATTERN` regex.

**Metadata Preservation**: `git-undo` stores commit hash, message, author, and timestamp in temporary files that get stashed for complete recovery information.

**Base Branch Detection**: `git-squash` and `git-show` automatically detect merge bases with main/master/develop, preferring develop over main when distances are equal.

**Error Handling**: Comprehensive validation at function start, graceful failure modes, and helpful error messages with cleanup.

## Testing Architecture

**Isolated Test Environment**: Each test creates temporary directories under `tests/test-*-$$` to avoid interfering with the parent git repository.

**Test Categories**: 63 tests organized into 8 categories covering error conditions, user interactions, safety mechanisms, and core functionality.

**Cross-Platform Testing**: Validates POSIX compliance, shell syntax compatibility, and timestamp edge cases.

**Development Testing**: All testing and debug sessions must be stored in `tests/` directory. This directory is gitignored to prevent interference with git operations and maintain a clean repository state.

**Test Requirements**: When writing or updating code, always write adequate tests and add them to `test-git-toolkit.sh`. If any tests are updated or added, always update the README.md test output section from the actual test script output (not derived), and update the test breakdown with accurate counts and categories.

## Shell Compatibility

Functions use POSIX-compliant syntax with specific considerations:
- Uses `sed` instead of bash parameter expansion for regex operations
- Avoids bash arrays and associative arrays
- Uses `read -r` for safe input handling
- Temporary files for complex operations to avoid subshell variable issues