# git-toolkit

[![Test Suite](https://github.com/babul/git-toolkit/actions/workflows/test.yml/badge.svg)](https://github.com/babul/git-toolkit/actions/workflows/test.yml)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-tested-brightgreen)](https://github.com/babul/git-toolkit/actions/workflows/test.yml)
[![macOS](https://img.shields.io/badge/macOS-tested-brightgreen)](https://github.com/babul/git-toolkit/actions/workflows/test.yml)
[![bash](https://img.shields.io/badge/bash-compatible-blue)](https://github.com/babul/git-toolkit/actions/workflows/test.yml)
[![POSIX sh](https://img.shields.io/badge/POSIX%20sh-compatible-blue)](https://github.com/babul/git-toolkit/actions/workflows/test.yml)
[![zsh](https://img.shields.io/badge/zsh-compatible-blue)](https://github.com/babul/git-toolkit/actions/workflows/test.yml)

An opinionated collection of cross-platform Git utilities that provide interactive ways to undo commits, stash changes, and clean up branches, etc. while preserving your work with a test suite to ensure safety.

The goal of these utilities is to make getting to a clean working state in any branch safe and easy, while still allowing you to be as creative and productive as you need to be.

---

USE AT YOUR OWN RISK! (I use them every day, but of course, YMMV). 

While these tools are tested daily, always back up your work and use caution when modifying git history.

---

Built with the assistance of Claude Code. [`CLAUDE.md`](CLAUDE.md) is included.

I am on a Mac Sequoia 15.5 (Silicon) using Warp terminal. I've tried to keep these functions as portable as possible. If you have an issue, run the test script in debug mode and post an Issue on GitHub in this repository.

PRs welcome!

## Overview

This toolkit provides eight essential Git utilities:

| Function | Purpose                                                                                    | Key Benefits |
|----------|--------------------------------------------------------------------------------------------|--------------|
| **`git-undo`** | Safely undo the last commit while preserving changes in a stash                            | Interactive preview, metadata preservation, safe rollback |
| **`git-redo`** | Restore previously undone commits from undo stashes                                        | Smart stash detection, interactive selection, conflict-safe |
| **`git-stash`** | Stash all changes (including untracked files) to get a clean working directory | Complete file coverage, enhanced file status display, guaranteed clean state |
| **`git-clean-branches`** | Clean up merged and orphaned branches with detailed previews                               | Branch protection, detailed reporting, selective cleanup |
| **`git-squash`** | Squash all commits in current branch into the oldest commit                                | Interactive commit message editing, preserves authorship, uses current date |
| **`git-status`** | Show count of commits and untracked files, what branch any feature branch forked from      | Smart base detection, enhanced file status display, develop preference |
| **`git-show-branches`** | Display all local branches with their remote tracking status and sync state                | Visual branch overview, ahead/behind status, remote tracking info |
| **`git-show-stashes`** | Display all stashes with name and smart age formatting                                     | Smart age display (minutes/hours/days), color-coded by age, verbose mode support |
| **`git-clean-stashes`** | Clean up old stashes from your repository with age-based filtering                    | Age-based filtering, preview before deletion, batch operations |

All functions follow the same safe pattern: show what will happen, ask for confirmation, then execute with clear feedback.

## Installation

All you need is the main script, `git-toolkit.sh`. Just add it to your shell and restart your terminal. The steps below cover the basics, but if you run into any issues or your setup is a bit different, a quick search for your operating system’s specifics should point you in the right direction.

## MacOS / zsh

Copy and paste instructions for any `zsh` shell. `zsh` has been the default shell on macOS since 2019 Catalina.

1. Download the script to your user folder
   ```bash
   curl -L -o ~/git-toolkit.sh https://raw.githubusercontent.com/babul/git-toolkit/main/git-toolkit.sh
   ```

2. Load the script into your shell:
   ```bash
   source ~/git-toolkit.sh
   ```

3. Add the script to your shell configuration file to load it automatically on startup
   ```bash
   echo 'source ~/git-toolkit.sh' >> ~/.zshrc
   ```
   
4. To update script just repeat steps 1 & 2

## Ubuntu / bash

Here is copy/paste instructions for any `bash` shell. macOS versions prior to Catalina use `bash` as the default shell, but you will need Bash 4.0+.

1. Download the script to your user folder
   ```bash
   curl -L -o ~/git-toolkit.sh https://raw.githubusercontent.com/babul/git-toolkit/main/git-toolkit.sh
   ```
   
2. Load the script into your shell:
   ```bash
   source ~/git-toolkit.sh
   ```
   
3. Add the script to your shell configuration file to load it automatically on startup
   ```bash
   echo 'source ~/git-toolkit.sh' >> ~/.bashrc
   ```

4. To update script just repeat steps 1 & 2

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

**Note:**
- This only works for commits that you have not pushed up!

### git-stash  
Stash all changes, including untracked files to get a clean branch.

```bash
git-stash [message]
```

**Options:**
- `message` Optional custom message to include in the stash name (space-separated words will be formatted)

**Features:**
- Handles modified, staged, and untracked files
- Shows preview of what will be stashed with enhanced file status display
- **Enhanced file status display**: Shows deleted, renamed, modified, and new files with color coding
- **Visual file states**: Modified/renamed files in green, deleted/untracked files in red
- Uses `--include-untracked` for complete cleanup (excludes ignored files)
- Branch-named and timestamped stash messages for easy identification
- Custom message support with automatic formatting

### git-redo
Restore previously undone commits by selecting from available undo stashes.

```bash
git-redo
```

**Features:**
- Lists all available previous git-undo operations with details
- Shows commit message, timestamp, and original hash
- Interactive selection of which undo to restore
- Applies changes to working directory (not as commit)
- Preserves stash for potential future use

### git-clean-branches
Clean up merged branches and branches closed or deleted from remote.

```bash
git-clean-branches
```

**Features:**
- Identifies merged and orphaned branches
- Shows branch details and last commit info
- Protects current branch and main/master/develop
- Force-deletes branches gone from remote
- Provides guidance for unmerged branches

### git-squash
Squash all commits in the current branch into the oldest commit.

```bash
git-squash
```

**Features:**
- Automatically finds base branch (main/master/develop)
- Shows detailed preview of commits to be squashed
- Opens editor to modify the commit message
- Preserves original author, uses current date/time
- Protects main/master/develop branches from being squashed
- Safe rollback if editor is canceled or fails

### git-status
Show what branch any feature branch forked from, or show pending commits for main/master/develop branches.

```bash
git-status [options] [branch-name]
```

**Options:**
- `-v` Show commits since fork (feature branches) or pending commits (main/master/develop)
- `-vv` Show full commits since fork (feature branches) or pending commits (main/master/develop)
- `--debug` Show detailed diagnostic information for troubleshooting

**Features:**
- **Feature branches**: Automatically detects fork point from main/master/develop
- **Main branches**: Shows pending commits since last push to remote
- **No remote**: Shows total commit count when no remote tracking branch exists
- Prefers develop over main when both are equidistant for feature branches
- Shows commit history with verbose options for both branch types
- **Enhanced file status display**: Shows deleted, renamed, modified, and new files with color coding
- **Visual file states**: Modified/renamed files in green, deleted/untracked files in red
- Suppresses debug output for clean results

### git-show-branches
Display all local branches with their remote tracking status and sync state.

```bash
git-show-branches [options]
```

**Options:**
- `-v` Show last commit message for each branch
- `-vv` Show full last commit details for each branch
- `--debug` Show debug information

**Features:**
- **Visual branch overview**: Shows all local branches in a formatted table
- **Remote tracking status**: Displays remote tracking branch for each local branch
- **Sync status**: Shows if branches are ahead/behind their remote counterparts
- **Color coding**: Yellow for branch names, cyan for remotes, green/yellow/red for status
- **Column alignment**: Auto-adjusts column widths for optimal readability
- **Commit info**: Shows last commit details with verbose options

### git-show-stashes
Display all stashes with their names and age in a clean, formatted table.

```bash
git-show-stashes [options]
```

**Options:**
- `-v` Show number of files changed in each stash
- `-vv` Show full diff stat for each stash
- `--debug` Show debug information

**Features:**
- **Stash visualization**: Shows all stashes with message and age (no date/time for cleaner output)
- **Smart age display**: 
  - Recent stashes: "< 1 minute", "5 minutes", "45 minutes"
  - Hours: "1 hour", "2 hours 30 min", "23 hours 59 min"
  - Days: "1 day", "30 days", "90 days"
- **Color coding by age**: Green (<30 days), yellow (30-60 days), red (>60 days)
- **Column alignment**: Auto-adjusts column widths for optimal readability
- **Verbose modes**: Shows files changed count or full diff statistics
- **Chronological order**: Most recent stashes appear first

### git-clean-stashes
Clean up old stashes from your repository based on age.

```bash
git-clean-stashes [options]
```

**Options:**
- `--age=days` Only show stashes older than X days (default: 60)
- `--debug` Show debug information including timestamps and stash counts

**Features:**
- **Age-based filtering**: Default 60 days, customizable with --age parameter
- **Safe deletion**: Shows preview of all stashes to be deleted before confirmation
- **Batch operations**: Deletes multiple stashes in correct order to avoid reference issues
- **Detailed preview**: Shows stash age, creation date, and message
- **Success reporting**: Reports number of stashes successfully deleted

## Enhanced File Status Display

Both `git-status` and `git-stash` now provide enhanced file status visualization with color coding:

### File Status Types
- **Modified files**: Show as `modified: filename.js` in green
- **Renamed files**: Show as `renamed: old-name.js -> new-name.js` in green  
- **Deleted files**: Show as `deleted: filename.js` in red
- **New files**: Show as `new file: filename.js` in green when staged
- **Untracked files**: Listed by filename in red

### Color Scheme
- **Green**: Positive changes (modified, renamed, new files)
- **Red**: Items needing attention (deleted, untracked files)

### Visual Organization
Files are grouped into sections matching Git's standard output:
- **Changes to be committed** (staged files)
- **Changes not staged for commit** (unstaged modifications/deletions)
- **Untracked files** (files not in Git)

This enhanced display makes it easier to understand exactly what changes are present in your working directory and what will be affected by Git operations.

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
  Changes to be committed:
    renamed:    old-config.js -> config.js
    new file:   utils.js

  Changes not staged for commit:
    modified:   main.js
    deleted:    legacy.js

  Untracked files:
    temp.txt

Proceed with stashing all changes? (y/N): y
✓ All changes stashed successfully!
Working directory is now clean.

Changes saved in stash: stash@{0} ("stash feature-branch")
To restore: git stash apply stash@{0}
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

### git-squash
```bash
$ git-squash
About to squash commits:
  Branch: feature-branch
  Base: main
  Commits to squash: 3
  Into commit: a1b2c3d (Add initial feature)
  Author: John Doe <john@example.com>
  Date: Current date/time

Commits being squashed:
     1. a1b2c3d Add initial feature
     2. e4f5g6h Update feature implementation
     3. h7i8j9k Fix feature bugs

Proceed with squash? (y/N): y
Opening editor to edit commit message...
✓ Successfully squashed 3 commits
✓ Commit message updated

Squashed commit:
k9l0m1n Add initial feature with updates and fixes
```

### git-status
```bash
# Feature branch - basic usage
$ git-status
The feature/sentry-posthog branch forked from develop at commit 8ac50fd2

# Feature branch - specific branch
$ git-status bugfix/login-issue
The bugfix/login-issue branch forked from main at commit 3f7a9e12

# Feature branch - show commits since fork (one line each)
$ git-status -v feature/analytics
The feature/analytics branch forked from develop at commit 8ac50fd2

Uncommitted changes:
  Changes to be committed:
    renamed:    old-config.js -> config.js
    new file:   analytics.js

  Changes not staged for commit:
    modified:   main.js
    deleted:    legacy.js

  Untracked files:
    temp.log

Commits since fork:
a1b2c3d Add event tracking
e4f5g6h Configure analytics dashboard
h7i8j9k Fix tracking bugs

# Main branch - show pending commits
$ git-status main
The main branch has 3 pending commit(s) since last push

# Main branch - show pending commits with details
$ git-status -v main
The main branch has 3 pending commit(s) since last push

Pending commits:
a1b2c3d Fix user authentication bug
e4f5g6h Update documentation
h7i8j9k Add new feature endpoint

# Main branch - no remote tracking branch
$ git-status main
The main branch has 15 total commit(s) (no remote tracking branch)

# Main branch - show all commits when no remote
$ git-status -v main
The main branch has 15 total commit(s) (no remote tracking branch)

All commits:
a1b2c3d Latest changes
e4f5g6h Previous commit
h7i8j9k Initial commit

# Feature branch - full verbose mode
$ git-status -vv feature/new-ui
The feature/new-ui branch forked from develop at commit 8ac50fd2

Commits since fork:
commit a1b2c3d4e5f6789...
Author: Jane Doe <jane@example.com>
Date: Tue Jan 16 09:30:00 2024 -0500

    Add new UI components
    
    - Implement modern button styles
    - Add responsive navigation
    - Update color scheme

commit e4f5g6h7i8j9012...
Author: Jane Doe <jane@example.com>
Date: Tue Jan 16 11:15:00 2024 -0500

    Refactor layout system
    
    - Use CSS Grid for main layout
    - Improve mobile responsiveness
```

### git-show-branches
```bash
# Basic usage - show all branches
$ git-show-branches
main                   origin/main                   Status: 5 ahead
feature/test-branch    origin/feature/test-branch    Status: up to date
hotfix/urgent-fix      (local only)                  Status: 3 local commit(s)
develop                origin/develop                Status: 2 ahead, 1 behind

# Verbose mode - show last commit
$ git-show-branches -v
main                   origin/main                   Status: 5 ahead
                       └─ abc123d Add new feature
feature/test-branch    origin/feature/test-branch    Status: up to date
                       └─ def456e Update tests
hotfix/urgent-fix      (local only)                  Status: 3 local commit(s)
                       └─ ghi789f Fix critical bug
develop                origin/develop                Status: 2 ahead, 1 behind
                       └─ jkl012g Merge pull request #42

# Full verbose mode - show full commit details
$ git-show-branches -vv
main                   origin/main                   Status: 5 ahead
                       └─ abc123d Add new feature
                          
                          Added support for new authentication method
                          - Implemented OAuth2 flow
                          - Updated user model
feature/test-branch    origin/feature/test-branch    Status: up to date
                       └─ def456e Update tests
                          
                          Improved test coverage for auth module
```

### git-show-stashes
```bash
# Basic usage - show all stashes
$ git-show-stashes
Stashes:

On main: WIP authentication fixes                5 minutes
On feature/ui: Save work before switching        2 hours 30 min
On develop: Temp save for meeting                18 days
On main: Experimental feature                    44 days
On hotfix/bug-123: Quick save                    84 days

# Verbose mode - show files changed
$ git-show-stashes -v
Stashes:

On main: WIP authentication fixes                5 minutes
└─ 3 file(s) changed
On feature/ui: Save work before switching        2 hours 30 min
└─ 7 file(s) changed
On develop: Temp save for meeting                18 days
└─ 1 file(s) changed

# Full verbose mode - show diff stat
$ git-show-stashes -vv
Stashes:

On main: WIP authentication fixes                5 minutes
└─ 3 files changed, 45 insertions(+), 12 deletions(-)
On feature/ui: Save work before switching        2 hours 30 min
└─ 7 files changed, 234 insertions(+), 89 deletions(-)
```

### git-clean-stashes
```bash
# Default usage - clean stashes older than 60 days
$ git-clean-stashes
Found 3 stash(es) older than 60 days:

  Stash: stash@{1}
  Age: 174 days (created: 2024-05-30 12:38:32)
  Message: On main: Fork autostash May 30, 2024 at 12:38 PM

  Stash: stash@{2}
  Age: 397 days (created: 2023-12-31 09:15:42)
  Message: WIP on develop: b8ba715 use prince.aliada.io instead of app.posthog.com

  Stash: stash@{3}
  Age: 418 days (created: 2023-12-10 14:22:15)
  Message: On main: Checkout autostash Dec 10, 2023 at 2:22 PM

Proceed with deleting these 3 old stash(es)? (y/N): y
✓ Deleted stash: stash@{3}
✓ Deleted stash: stash@{2}
✓ Deleted stash: stash@{1}

✓ Successfully deleted 3 stash(es)

# Custom age - clean stashes older than 30 days
$ git-clean-stashes --age=30
Found 5 stash(es) older than 30 days:
...

# Debug mode
$ git-clean-stashes --debug --age=90
=== DEBUG MODE ===
Age threshold: 90 days
Current timestamp: 1735689600
Cutoff timestamp: 1727913600
Total stashes: 12
==================
Found 2 stash(es) older than 90 days:
...
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

# git-status invalid option
$ git-status -x
✗ Error: Unknown option '-x'
Usage: git-status [-v|-vv] [branch-name]
  -v   Show commits since fork (feature branches) or pending commits (main/master/develop)
  -vv  Show full commits since fork (feature branches) or pending commits (main/master/develop)

# git-clean-stashes invalid age
$ git-clean-stashes --age=abc
✗ Error: Invalid age value 'abc'. Must be a positive integer.
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

Test with specific shells for maximum compatibility:
```bash
bash ./test-git-toolkit.sh    # Test under bash
sh ./test-git-toolkit.sh      # Test under POSIX sh
zsh ./test-git-toolkit.sh     # Test under zsh
```

Run tests in debug mode for troubleshooting:
```bash
./test-git-toolkit.sh --debug
```

**Test coverage includes:**
- All nine functions (`git-undo`, `git-redo`, `git-stash`, `git-clean-branches`, `git-squash`, `git-status`, `git-show-branches`, `git-show-stashes`, `git-clean-stashes`)
- Error conditions and edge cases
- User interaction scenarios (confirmation, cancellation)
- Cross-platform compatibility validation
- Special character handling in stash messages
- Verbose mode operations (-v, -vv)
- **89 total tests** with colored pass/fail output

**Test breakdown by category:**
- Cross-platform compatibility: 11 assertions
- git_undo function: 11 assertions
- git_stash function: 10 assertions  
- git_clean_branches function: 10 assertions
- git_redo function: 9 assertions
- git_squash function: 8 assertions
- git_status function: 14 assertions
- git_show_branches function: 6 assertions
- git_clean_stashes function: 8 assertions
- git_show_stashes function: 9 assertions

### Test Output

```
[TEST] Starting git-toolkit.sh test suite...

==========================================
TESTING: Cross-platform compatibility
==========================================
[TEST] Cross-platform: Shell feature compatibility
Test confirmation function (simulate 'n' response)Test prompt (y/N): 
Test confirmation function (simulate 'y' response)
Test prompt (y/N): 
[PASS] All cross-platform utility functions work correctly (6/6)
[TEST] _git_format_timestamp: Edge case testing
Testing normal timestamp generation...
Testing fallback when DATE_FORMAT would be empty...
Fallback logic works: ''2025-07-03 23:20:49''
Testing actual function consistency...
Function consistency works: '2025-07-03 23:20:49'
Testing timestamp consistency...
[PASS] _git_format_timestamp works correctly in all edge cases (4/4)
[TEST] Cross-platform: Shell syntax compatibility
[PASS] Script syntax is valid in bash

==========================================
TESTING: git_undo function
==========================================
[TEST] git_undo: Not in git repository
[PASS] Correctly detected not in git repository
[TEST] git_undo: Initial commit protection
[PASS] Correctly prevented undoing initial commit
[TEST] git_undo: Dirty working directory
[PASS] Correctly detected dirty working directory
[TEST] git_undo: Cancel undo operation
[PASS] Cancel operation works correctly
[TEST] git_undo: Normal undo operation
[PASS] Commit was successfully undone
[PASS] Stash was created with correct message
[PASS] Metadata was stored in stash with correct content
[TEST] git_undo: Special characters in commit
stash@{0}: On main: undo main [sc-123] fix: handle special chars (test) & more [brackets]
[PASS] Handled special characters in commit message
[TEST] git_undo: Multiple undos in sequence
[PASS] Multiple undos work correctly
[TEST] git_undo: Comprehensive metadata preservation
[PASS] Comprehensive metadata preservation works

==========================================
TESTING: git_stash function
==========================================
[TEST] git_stash: Not in git repository
[PASS] git_stash correctly detected not in git repository
[TEST] git_stash: Repository with no commits
[PASS] git_stash correctly detected repository with no commits
[TEST] git_stash: Clean working directory
[PASS] git_stash correctly detected clean working directory
[TEST] git_stash: Cancel stash operation
[PASS] git_stash cancel operation works correctly
[TEST] git_stash: Normal stash with modified files
[PASS] git_stash cleaned working directory
[PASS] git_stash created stash with correct message
[TEST] git_stash: Stash with untracked files
[PASS] git_stash handled both modified and untracked files
[PASS] git_stash included untracked files in stash
[TEST] git_stash: Stash with staged files
[PASS] git_stash handled staged files correctly
[TEST] git_stash: Complex scenario with all file types
[PASS] git_stash completely cleaned complex working directory
[PASS] git_stash preserved all file types correctly

==========================================
TESTING: git_clean_branches function
==========================================
[TEST] git_clean_branches: Not in git repository
[PASS] git_clean_branches correctly detected not in git repository
[TEST] git_clean_branches: Repository with no commits
[PASS] git_clean_branches correctly detected repository with no commits
[TEST] git_clean_branches: No branches to clean
[PASS] git_clean_branches correctly detected no branches to clean
[TEST] git_clean_branches: Cancel operation
[PASS] git_clean_branches cancel operation works correctly
[TEST] git_clean_branches: Clean merged branches
[PASS] git_clean_branches successfully cleaned merged branches
[PASS] git_clean_branches preserved main branch
[TEST] git_clean_branches: Protect current branch
[PASS] git_clean_branches protected current branch
[TEST] git_clean_branches: Handle unmerged branches
[PASS] git_clean_branches protected unmerged branch
[PASS] git_clean_branches deleted merged branch
[PASS] git_clean_branches properly handled unmerged branch

==========================================
TESTING: git_redo function
==========================================
[TEST] git_redo: Not in git repository
[PASS] git_redo correctly detected not in git repository
[TEST] git_redo: Repository with no commits
[PASS] git_redo correctly detected repository with no commits
[TEST] git_redo: No undo stashes available
[PASS] git_redo correctly detected no undo stashes
[TEST] git_redo: Dirty working directory
[PASS] git_redo correctly detected dirty working directory
[TEST] git_redo: Cancel redo operation
[PASS] git_redo cancel at selection works correctly
[PASS] git_redo cancel at confirmation works correctly
[TEST] git_redo: Successful redo operation
[PASS] File was removed after undo
[PASS] git_redo successfully restored changes
[PASS] git_redo left changes in working directory

==========================================
TESTING: git_squash function
==========================================
[TEST] git_squash: Not in git repository
[PASS] git_squash correctly detected not in git repository
[TEST] git_squash: Repository with no commits
[PASS] git_squash correctly detected repository with no commits
[TEST] git_squash: Dirty working directory
[PASS] git_squash correctly detected dirty working directory
[TEST] git_squash: On protected branch
[PASS] git_squash correctly prevented squashing on main branch
[TEST] git_squash: Only one commit on branch
[PASS] git_squash correctly detected only one commit
[TEST] git_squash: Cancel squash operation
[PASS] git_squash cancel operation works correctly
[TEST] git_squash: Successful squash operation
[PASS] git_squash function defined and preview works (interactive test skipped)
[TEST] git_squash: No base branch found
[PASS] git_squash correctly detected no base branch

==========================================
TESTING: git_status function
==========================================
[TEST] git_status: Not in git repository
[PASS] git_status correctly detected not in git repository
[TEST] git_status: Repository with no commits
[PASS] git_status correctly detected repository with no commits
[TEST] git_status: On default branch (show pending commits)
[PASS] git_status correctly showed commit count for main branch without remote
[TEST] git_status: Default branch verbose modes
[PASS] git_status -v correctly showed commits for main branch
[PASS] git_status -vv correctly showed full commits for main branch
[TEST] git_status: Nonexistent branch
[PASS] git_status correctly detected nonexistent branch
[TEST] git_status: Basic functionality
[PASS] git_status correctly identified branch fork point
[TEST] git_status: With specific branch parameter
[PASS] git_status correctly identified specific branch fork point
[TEST] git_status: Verbose mode (-v)
[PASS] git_status -v correctly showed commits since fork
[TEST] git_status: Full verbose mode (-vv)
[PASS] git_status -vv correctly showed full commit details
[TEST] git_status: Invalid option
[PASS] git_status correctly handled invalid option
[TEST] git_status: Develop branch preference
[PASS] git_status correctly preferred develop over main
[TEST] git_status: Show deleted files with -v
[PASS] git_status -v correctly showed deleted and modified files
[TEST] git_status: Show renamed files with -v
[PASS] git_status -v correctly showed renamed file
[TEST] git_stash: Show deleted and renamed files
[PASS] git_stash correctly showed deleted, renamed, and new files

==========================================
TESTING: git_show_branches function
==========================================
[TEST] git_show_branches: Not in git repository
[PASS] git_show_branches correctly detected not in git repository
[TEST] git_show_branches: Repository with no commits
[PASS] git_show_branches correctly detected repository with no commits
[TEST] git_show_branches: Single branch (local only)
[PASS] git_show_branches correctly showed single local branch
[TEST] git_show_branches: Multiple branches with different statuses
[PASS] git_show_branches correctly showed multiple branches
[TEST] git_show_branches: Verbose mode
[PASS] git_show_branches -v correctly showed commit information
[TEST] git_show_branches: Invalid option
[PASS] git_show_branches correctly handled invalid option

==========================================
TESTING: git_clean_stashes function
==========================================
[TEST] git_clean_stashes: Not in git repository
[PASS] git_clean_stashes correctly detected not in git repository
[TEST] git_clean_stashes: Repository with no commits
[PASS] git_clean_stashes correctly detects repository with no commits
[TEST] git_clean_stashes: No stashes available
[PASS] git_clean_stashes correctly reports no stashes
[TEST] git_clean_stashes: Invalid age parameter
[PASS] git_clean_stashes correctly rejects invalid age
[TEST] git_clean_stashes: Cancel cleanup operation
Saved working directory and index state On main: old test stash
[PASS] git_clean_stashes correctly handles user cancellation
[TEST] git_clean_stashes: No old stashes (all recent)
Saved working directory and index state On main: recent test stash
[PASS] git_clean_stashes correctly reports no old stashes
[TEST] git_clean_stashes: Successfully clean old stashes
Saved working directory and index state On main: test stash to clean
[PASS] git_clean_stashes successfully cleaned old stashes
[TEST] git_clean_stashes: Debug mode output
Saved working directory and index state On main: debug test stash
[PASS] git_clean_stashes debug mode works correctly

==========================================
TESTING: git_show_stashes function
==========================================
[TEST] git_show_stashes: Not in git repository
[PASS] git_show_stashes correctly detected not in git repository
[TEST] git_show_stashes: Repository with no commits
[PASS] git_show_stashes correctly detected repository with no commits
[TEST] git_show_stashes: Empty stash list
[PASS] git_show_stashes correctly handles empty stash list
[TEST] git_show_stashes: Basic stash display
Saved working directory and index state On main: First stash
Saved working directory and index state On main: Second stash
[PASS] git_show_stashes displays basic stash list correctly
[TEST] git_show_stashes: Verbose mode (-v)
Saved working directory and index state On main: Test stash with multiple files
[PASS] git_show_stashes -v shows file count
[TEST] git_show_stashes: Full verbose mode (-vv)
Saved working directory and index state On main: Test stash for full verbose
[PASS] git_show_stashes -vv shows full diff stats
[TEST] git_show_stashes: Invalid options
[PASS] git_show_stashes correctly rejects invalid options
[TEST] git_show_stashes: Stashes with special characters
Saved working directory and index state On main: [special] chars & (test) #1
Saved working directory and index state On main: Test with 'quotes' and "double quotes"
[PASS] git_show_stashes handles special characters correctly
[TEST] git_show_stashes: Debug mode
Saved working directory and index state On main: Debug test stash
[PASS] git_show_stashes debug mode works correctly

===============================================
Test Results: 89 passed, 0 failed
===============================================
All tests passed!
```

### Test Coverage Breakdown

The test suite provides comprehensive coverage across **89 tests** organized into **9 categories**:

| **Category** | **Tests** | **Coverage** |
|---|---|---|
| **Cross-platform compatibility** | 3 | Shell feature validation, timestamp edge cases, syntax compatibility |
| **git_undo function** | 9 | Error conditions, user interactions, metadata preservation |
| **git_stash function** | 11 | File type handling, clean state verification, branch naming, deleted/renamed files |
| **git_clean_branches function** | 11 | Branch detection, protection logic, deletion safety |
| **git_redo function** | 9 | Stash restoration, user selection, working directory checks |
| **git_squash function** | 8 | Commit consolidation, editor integration, branch protection |
| **git_status function** | 15 | Fork detection, verbose modes, main branch pending commits, branch validation, deleted/renamed files |
| **git_show_branches function** | 6 | Branch listing, remote tracking status, verbose modes, error handling |
| **git_clean_stashes function** | 8 | Age filtering, batch deletion, user cancellation, debug mode |

**Test Types:**
- **Error condition tests** (24 tests): Repository validation, commit existence, permission checks
- **Safety mechanism tests** (18 tests): Working directory protection, branch safeguards, user confirmation
- **Core functionality tests** (28 tests): Primary operations, data integrity, expected behaviors, timestamp edge cases, main branch pending commits, deleted/renamed file detection
- **User interaction tests** (10 tests): Cancellation handling, input validation, confirmation prompts

**Key Test Scenarios:**
- **Repository state validation**: Tests all functions in non-git directories and empty repositories
- **User cancellation**: Verifies all functions handle user cancellation gracefully
- **Special cases**: Complex commit messages, multiple file types, edge conditions
- **Timestamp edge cases**: Empty DATE_FORMAT handling, fallback behavior validation
- **Cross-platform compatibility**: POSIX compliance and portable shell features

## Requirements

- **Shell**: Bash 4.0+ or Zsh (POSIX-compliant)
- **Git**: 2.0 or higher
- **OS**: macOS, Linux, Unix, or WSL

## Advanced Features

### Debug Mode
All git-toolkit functions support a `--debug` flag for troubleshooting:
```bash
git-undo --debug
git-redo --debug
git-stash --debug
git-clean-branches --debug
git-squash --debug
git-status --debug
git-clean-stashes --debug
```

Debug mode provides detailed diagnostic information including:
- Branch detection and pattern matching
- Variable values and code path selection
- Detailed execution flow for troubleshooting

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

### git-squash
- **Automatic base detection**: Finds main/master/develop branch automatically
- **Interactive commit editing**: Opens editor for customizing squashed commit message
- **Authorship preservation**: Maintains original author, uses current date/time
- **Smart commit preview**: Shows detailed list of commits being squashed
- **Safe operation**: Protects against squashing main branches, provides rollback on failure
- **Cross-platform editor support**: Works with any configured git editor

### git-status
- **Dual functionality**: Works on both feature branches and main/master/develop branches
- **Feature branches**: Smart base detection, automatically finds fork point from main/master/develop
- **Main branches**: Shows pending commits since last push, or total commits if no remote
- **Develop preference**: Choose develop over main when distances are equal for feature branches
- **Verbose modes**: Optional one-line (-v) or full commit (-vv) history for both branch types
- **Clean output**: Suppresses debug output for professional results
- **Flexible usage**: Works with current branch or specified branch name
- **Debug mode**: Detailed diagnostic information available with `--debug` flag

### git-clean-stashes
- **Age-based filtering**: Customizable age threshold for stash cleanup (default 60 days)
- **Batch operations**: Efficiently deletes multiple stashes in correct order
- **Reference management**: Handles stash reference shifting during deletion
- **Preview functionality**: Shows detailed information before deletion
- **Progress reporting**: Real-time feedback during deletion process
- **Debug information**: Timestamps, counts, and processing details

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

### git-squash
- Only works on feature branches (protects main/master/develop)
- Requires at least two (2) commits on branch to squash
- Needs base branch (main/master/develop) to exist for comparison
- Editor cancellation or empty message cancels the operation

### git-status
- **Feature branches**: Requires base branches (main/master/develop) to exist for comparison
- **Feature branches**: May not detect correct base if branch history is complex or rebased  
- **Main branches**: Pending commit detection requires remote tracking branch for accurate count
- Verbose modes (-v/-vv) require commits to exist since fork point or in branch history

### git-clean-stashes
- Requires commits to exist (cannot work in empty repository)
- Cannot recover stashes after deletion (permanent operation)
- Age calculation based on stash creation timestamp
- No filtering by stash content or branch name (age-based only)

## Contributing

Contributions are welcome! Please:
1. Follow the established code patterns
2. Add tests for new functionality  
3. Ensure cross-platform compatibility
4. Update documentation

## Project History

A while ago, I created a simple `git-undo` bash function to solve one of my recurring pain points. Thanks to Claude Code, I was able to expand that into a full set of “missing” Git commands I’d always wanted. 

With the productivity boost from working with Claude Code, these utilities have become even more valuable to me. I hope you find them useful too!

If you do, feel free to reach out on X at @tmgbabul.

Wishing you safety, security, and good health! ☺️

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