# git-toolkit

A collection of safe cross-platform Git utilities that provide interactive ways to undo commits, stash changes, and clean up branches while preserving your work.

## Overview

This toolkit provides four essential Git utilities:

| Function | Purpose | Key Benefits |
|----------|---------|--------------|
| **`git-undo`** | Safely undo the last commit while preserving changes in a stash | Interactive preview, metadata preservation, safe rollback |
| **`git-redo`** | Restore previously undone commits from undo stashes | Smart stash detection, interactive selection, conflict-safe |
| **`git-stash`** | Stash all changes (including untracked files) to get a clean working directory | Complete file coverage, preview mode, guaranteed clean state |
| **`git-clean-branches`** | Clean up merged and orphaned branches with detailed previews | Branch protection, detailed reporting, selective cleanup |

All functions follow the same safe pattern: show what will happen, ask for confirmation, then execute with clear feedback.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/git-toolkit.git
   cd git-toolkit
   ```

2. Source the script in your shell:
   ```bash
   source git-toolkit.sh
   ```

3. Or add it to your shell configuration file (`.bashrc`, `.zshrc`, etc.):
   ```bash
   echo "source /path/to/git-toolkit.sh" >> ~/.bashrc
   ```

## Functions

### git-undo
Safely undo the last commit while preserving all changes.

```bash
git-undo
```

**Features:**
- Shows complete commit details before undoing
- Stashes changes with metadata for easy recovery
- Protects against undoing initial commits
- Requires clean working directory

### git-stash  
Stash all changes including untracked files to get a clean branch.

```bash
git-stash
```

**Features:**
- Handles modified, staged, and untracked files
- Shows preview of what will be stashed
- Uses `--include-untracked` for complete cleanup
- Timestamped stash messages for easy identification

### git-redo
Restore previously undone commits by selecting from available undo stashes.

```bash
git-redo
```

**Features:**
- Lists all available undo operations with details
- Shows commit message, timestamp, and original hash
- Interactive selection of which undo to restore
- Applies changes to working directory (not as commit)
- Preserves stash for potential future use

### git-clean-branches
Clean up merged branches and branches gone from remote.

```bash
git-clean-branches
```

**Features:**
- Identifies merged and orphaned branches
- Shows branch details and last commit info
- Protects current branch and main/master/develop
- Force-deletes branches gone from remote
- Provides guidance for unmerged branches

## Examples

### git-undo
```bash
$ git-undo
About to undo commit:
  Hash: a1b2c3d
  Message: Add new feature
  Author: John Doe <john@example.com>
  Date: 2024-01-15 10:30:00

Proceed with undo? (y/N): y
✓ Commit undone and changes stashed
```

### git-redo
```bash
$ git-redo
Available undo operations to redo:

  1. Add new feature
     Undone: 2024-01-15 10:30:00
     Original hash: a1b2c3d
     Stash: stash@{0}

  2. Fix bug in parser
     Undone: 2024-01-15 09:15:00
     Original hash: e4f5g6h
     Stash: stash@{1}

Enter the number of the undo to redo (or 'q' to quit): 1
About to redo (restore) commit:
  Commit: Add new feature
  Stash: stash@{0}

Proceed with redo? (y/N): y
✓ Redo completed successfully!

The changes have been restored to your working directory.
You can now:
  - Review the changes with: git diff
  - Commit them again with: git commit
  - Drop the stash with: git stash drop stash@{0}
```

### git-stash
```bash
$ git-stash
Stashing all changes (including untracked files)...

Files to be stashed:
  Modified files:
  src/main.js
  Staged files:
  src/utils.js
  Untracked files:
  temp.txt

Proceed with stashing all changes? (y/N): y
✓ All changes stashed successfully!
Working directory is now clean.
```

### git-clean-branches
```bash
$ git-clean-branches
About to delete branches:
  Branch: feature-1 (merged)
  Last commit: a1b2c3d Add feature 1
  Branch: feature-2 (gone from remote)
  Last commit: d4e5f6g Update feature 2

Proceed with branch cleanup? (y/N): y
✓ Deleted branch: feature-1
✓ Force deleted gone branch: feature-2
✓ Branch cleanup completed
```

### Error scenarios
```bash
# Not in a git repository
$ git-undo
✗ Error: Not a git repository

# Uncommitted changes present  
$ git-undo
✗ Error: Working directory is not clean. Please commit or stash your changes first.

# No commits to undo
$ git-undo
✗ Error: Repository has no commits
```

## Architecture & Design

### Safety-First Approach
All functions follow a consistent safety pattern:
1. **Validation** - Check git repository state and prerequisites
2. **Preview** - Show exactly what will happen
3. **Confirmation** - Interactive y/N prompt
4. **Execution** - Perform operation with clear feedback
5. **Success/Error reporting** - Visual indicators (✓/✗) for all outcomes

### Cross-Platform Compatibility  
- **POSIX-compliant shell syntax** - works on bash, zsh, and other POSIX shells
- **Portable commands** - avoids system-specific features
- **macOS, Linux, and Unix support** - tested across platforms

### Code Quality
- **Shared utility functions** - DRY principle with common validation logic
- **Comprehensive error handling** - graceful failure with helpful messages
- **Consistent user interface** - same patterns across all functions
- **Modular design** - each function is independent and focused

## Testing

Run the comprehensive test suite:
```bash
./test-git-toolkit.sh
```

**Test coverage includes:**
- All four functions (`git-undo`, `git-redo`, `git-stash`, `git-clean-branches`)
- Error conditions and edge cases
- User interaction scenarios (confirmation, cancellation)
- Cross-platform compatibility validation
- **42 total tests** with colored pass/fail output

### Test Output Example

```
[TEST] Starting git-toolkit.sh test suite...

==========================================
TESTING: Cross-platform compatibility
==========================================
[TEST] Cross-platform: Shell feature compatibility
[PASS] All cross-platform utility functions work correctly (6/6)
[TEST] Cross-platform: Shell syntax compatibility
[PASS] Script syntax is valid in bash

==========================================
TESTING: git-undo function
==========================================
[TEST] git-undo: Not in git repository
[PASS] Correctly detected not in git repository
[TEST] git-undo: Initial commit protection
[PASS] Correctly prevented undoing initial commit
[TEST] git-undo: Dirty working directory
[PASS] Correctly detected dirty working directory
[TEST] git-undo: Cancel undo operation
[PASS] Cancel operation works correctly
[TEST] git-undo: Normal undo operation
[PASS] Commit was successfully undone
[PASS] Stash was created with correct message
[PASS] Metadata was stored in stash with correct content
[TEST] git-undo: Special characters in commit
[PASS] Handled special characters in commit message
[TEST] git-undo: Multiple undos in sequence
[PASS] Multiple undos work correctly
[TEST] git-undo: Comprehensive metadata preservation
[PASS] Comprehensive metadata preservation works

==========================================
TESTING: git-stash function
==========================================
[TEST] git-stash: Not in git repository
[PASS] git-stash correctly detected not in git repository
[TEST] git-stash: Repository with no commits
[PASS] git-stash correctly detected repository with no commits
[TEST] git-stash: Clean working directory
[PASS] git-stash correctly detected clean working directory
[TEST] git-stash: Cancel stash operation
[PASS] git-stash cancel operation works correctly
[TEST] git-stash: Normal stash with modified files
[PASS] git-stash cleaned working directory
[PASS] git-stash created stash with correct message
[TEST] git-stash: Stash with untracked files
[PASS] git-stash handled both modified and untracked files
[PASS] git-stash included untracked files in stash
[TEST] git-stash: Stash with staged files
[PASS] git-stash handled staged files correctly
[TEST] git-stash: Complex scenario with all file types
[PASS] git-stash completely cleaned complex working directory
[PASS] git-stash preserved all file types correctly

==========================================
TESTING: git-clean-branches function
==========================================
[TEST] git-clean-branches: Not in git repository
[PASS] git-clean-branches correctly detected not in git repository
[TEST] git-clean-branches: Repository with no commits
[PASS] git-clean-branches correctly detected repository with no commits
[TEST] git-clean-branches: No branches to clean
[PASS] git-clean-branches correctly detected no branches to clean
[TEST] git-clean-branches: Cancel operation
[PASS] git-clean-branches cancel operation works correctly
[TEST] git-clean-branches: Clean merged branches
[PASS] git-clean-branches successfully cleaned merged branches
[PASS] git-clean-branches preserved main branch
[TEST] git-clean-branches: Protect current branch
[PASS] git-clean-branches protected current branch
[TEST] git-clean-branches: Handle unmerged branches
[PASS] git-clean-branches protected unmerged branch
[PASS] git-clean-branches deleted merged branch
[PASS] git-clean-branches properly handled unmerged branch

==========================================
TESTING: git-redo function
==========================================
[TEST] git-redo: Not in git repository
[PASS] git-redo correctly detected not in git repository
[TEST] git-redo: Repository with no commits
[PASS] git-redo correctly detected repository with no commits
[TEST] git-redo: No undo stashes available
[PASS] git-redo correctly detected no undo stashes
[TEST] git-redo: Dirty working directory
[PASS] git-redo correctly detected dirty working directory
[TEST] git-redo: Cancel redo operation
[PASS] git-redo cancel at selection works correctly
[PASS] git-redo cancel at confirmation works correctly
[TEST] git-redo: Successful redo operation
[PASS] File was removed after undo
[PASS] git-redo successfully restored changes
[PASS] git-redo left changes in working directory

===============================================
Test Results: 42 passed, 0 failed
===============================================
All tests passed!
```

## Requirements

- **Shell**: Bash 4.0+ or Zsh (POSIX-compliant)
- **Git**: 2.0 or higher
- **OS**: macOS, Linux, Unix, or WSL

## Advanced Features

### git-undo
- **Metadata preservation**: Full commit details stored in stash
- **Special character handling**: Supports complex commit messages
- **Initial commit protection**: Prevents undoing first commit
- **Timestamped stashes**: Easy identification and recovery

### git-redo
- **Smart stash detection**: Only shows undo-created stashes
- **Rich metadata display**: Shows original hash, timestamp, and commit message
- **Interactive selection**: Choose which specific undo to restore
- **Non-destructive**: Applies to working directory, preserves stash
- **Conflict handling**: Graceful handling of merge conflicts

### git-stash  
- **Complete coverage**: Modified, staged, and untracked files
- **Preview functionality**: See exactly what will be stashed
- **Clean state guarantee**: Working directory guaranteed clean after stashing

### git-clean-branches
- **Smart detection**: Identifies both merged and remote-gone branches
- **Branch protection**: Safeguards current, main, master, and develop branches
- **Detailed reporting**: Shows branch type and last commit info
- **Selective deletion**: Different handling for merged vs. unmerged branches

## Limitations

### git-undo
- One commit at a time (by design for safety)
- Cannot undo initial commit (git limitation)

### git-redo
- Only works with undo-created stashes (by design)
- Requires clean working directory (safety feature)
- Restores to working directory, not as commit (intentional)

### git-stash
- Requires commits to exist (cannot stash in empty repository)

### git-clean-branches
- Requires commits to exist for branch comparison
- Cannot delete current branch (safety feature)

## Contributing

Contributions are welcome! Please:
1. Follow the established code patterns
2. Add tests for new functionality  
3. Ensure cross-platform compatibility
4. Update documentation

## Project History

This project evolved from a simple git-undo bash function into a comprehensive Git safety toolkit. The current version prioritizes simplicity, safety, and cross-platform compatibility.

## License

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>