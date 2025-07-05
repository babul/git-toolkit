# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a bash-based Git toolkit that provides seven core safety-first utilities for Git operations:
- `git-undo`: Safely undo commits while preserving changes in stashes
- `git-redo`: Restore previously undone commits from undo stashes  
- `git-stash`: Stash all changes including untracked and ignored files
- `git-clean-branches`: Clean up merged and orphaned branches
- `git-squash`: Squash all commits in a branch into the oldest commit
- `git-status`: Show branch fork points and pending commits
- `git-clean-stashes`: Clean up old stashes with age-based filtering

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
# Run full test suite (80 tests across 9 categories)
./test-git-toolkit.sh

# ALWAYS test under bash, POSIX sh, and zsh for maximum compatibility
bash ./test-git-toolkit.sh    # Test under bash
sh ./test-git-toolkit.sh      # Test under POSIX sh
zsh ./test-git-toolkit.sh     # Test under zsh

# Debug mode available for all shells
bash ./test-git-toolkit.sh --debug
sh ./test-git-toolkit.sh --debug
zsh ./test-git-toolkit.sh --debug

# Test specific function (modify test script to run individual test blocks)
# Tests are organized by function in the script with clear section headers

**Always** run test and debugs within a folder under tests/ from repo root. This folder is in .gitignore so it will not be interferred with.
```

### Installation & Usage
```bash
# Source the toolkit in current shell
source git-toolkit.sh

# Add to shell profile for permanent installation
echo "source $(pwd)/git-toolkit.sh" >> ~/.bashrc
```

## Key Implementation Details

**Stash Management**: `git-undo` creates specially formatted stashes with metadata files that `git-redo` can identify and restore. Uses `"undo BRANCH COMMIT_MSG"` naming pattern.

**Branch Protection**: All functions protect main/master/develop branches using `PROTECTED_BRANCHES_PATTERN` regex.

**Metadata Preservation**: `git-undo` stores commit hash, message, author, and timestamp in temporary files that get stashed for complete recovery information.

**Base Branch Detection**: `git-squash` and `git-status` automatically detect merge bases with main/master/develop, preferring develop over main when distances are equal.

**Error Handling**: Comprehensive validation at function start, graceful failure modes, and helpful error messages with cleanup.

## Testing Architecture

**Isolated Test Environment**: Each test creates temporary directories under `tests/test-*-$$` to avoid interfering with the parent git repository.

**Test Categories**: 80 tests organized into 9 categories covering error conditions, user interactions, safety mechanisms, and core functionality.

**Cross-Platform Testing**: Validates POSIX compliance, shell syntax compatibility, and timestamp edge cases.

**Development Testing**: All testing and debug sessions must be stored in `tests/` directory. This directory is gitignored to prevent interference with git operations and maintain a clean repository state.

**Test Requirements**: When writing or updating code, always write adequate tests and add them to `test-git-toolkit.sh`. If any tests are updated or added, always replace the README.md test output section from the actual test script output (not derived), and replace the test breakdown with accurate counts and categories.

**Triple Shell Testing**: ALWAYS run tests under `bash`, `sh`, and `zsh` to ensure maximum compatibility. All three shells must pass all tests. Any code changes must be validated against all three environments before considering the work complete.

**Branch Agnostic Testing**: Tests must work in any Git environment regardless of default branch naming conventions. Never assume "main" or "master" - always detect the actual branch name dynamically.

## Shell Compatibility

Functions use POSIX-compliant syntax with specific considerations:
- Uses `sed` instead of bash parameter expansion for regex operations
- Avoids bash arrays and associative arrays
- Uses `read -r` for safe input handling
- Temporary files for complex operations to avoid subshell variable issues

**POSIX Shell Compatibility Issues**:
- **Function Naming**: POSIX sh doesn't allow hyphens in function names. All functions use underscores (e.g., `git_undo` not `git-undo`)
- **Source Command**: POSIX sh uses `.` instead of `source`. Always use `. script.sh` for compatibility
- **Echo Command**: `echo -e` is not portable. Use `printf` for escape sequences (e.g., `printf "1\ny\n"` instead of `echo -e "1\ny"`)
- **Reserved Variables**: Avoid using `status` as a variable name - it's read-only in some shells. Use descriptive names like `branch_status`
- **Default Branch Names**: Never hardcode "main" or "master" in tests. Use `$(git branch --show-current)` to detect the actual default branch name

**Test Accuracy and Branch Naming**:
- **Dynamic Branch Detection**: Always capture the actual default branch with `DEFAULT_BRANCH=$(get_default_branch)` in each test
- **User-Facing Messages**: All test output should use `$DEFAULT_BRANCH` instead of hardcoded "main" for accuracy
- **Generic Test Titles**: Use "default branch" or "protected branch" in test descriptions instead of "main branch"
- **Test Directory Names**: Use generic names like `test-squash-protected-$$` instead of `test-squash-main-$$`
- **Environment Independence**: Tests must work whether default branch is "main", "master", or any other name

**Backward Compatibility**: For users expecting hyphenated function names, conditional aliases are created only in interactive bash/zsh shells to avoid parse errors in POSIX sh

**Testing Protocol**: All changes must pass under `bash ./test-git-toolkit.sh`, `sh ./test-git-toolkit.sh`, and `zsh ./test-git-toolkit.sh` commands

## Debug Mode and Variable Robustness

**Debug Mode**: `git-status --debug` provides detailed diagnostic information including branch detection, pattern matching, and code path selection. Essential for troubleshooting branch classification issues.

**Readonly Variable Handling**: The `PROTECTED_BRANCHES_PATTERN` variable can become corrupted (set to empty string) due to multiple script sourcing or environment issues. Robust handling includes:
- Length-based checking: `${#PROTECTED_BRANCHES_PATTERN} -eq 0`
- Fallback pattern in utility function to ensure valid regex even if main variable fails
- Override mechanism for readonly variable conflicts
- Never rely solely on `-z` test for pattern validation

**Pattern Matching Safety**: Empty regex patterns match everything, causing feature branches to be misclassified as protected branches. Always validate pattern content before use.

**Critical Pattern Usage**: Always use `$(_git_get_protected_pattern)` helper function instead of `$PROTECTED_BRANCHES_PATTERN` directly. The helper provides fallback logic when the pattern variable is corrupted or empty, preventing misclassification of all branches as protected.

**Branch Name Detection Best Practices**:
- Use `get_default_branch()` helper function to detect the actual default branch name
- Capture branch name early in each test: `DEFAULT_BRANCH=$(get_default_branch)`
- Never hardcode branch names in assertions, error messages, or user output
- Use generic terminology in test descriptions to avoid environment assumptions

## Cross-Platform Date Handling

**Date Command Portability**: Different Unix-like systems have different date command syntax for timestamp conversion:
- **GNU/Linux**: `date -d "@timestamp"` to convert Unix timestamps
- **BSD/macOS**: `date -r timestamp` to convert Unix timestamps  
- **Portable Solution**: Use fallback chain: `date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "fallback"`

**Git Stash Timestamps**: When working with `git stash list --format="%ct"`, timestamps are in Unix epoch format and require conversion for user display.

**Debug Output Prevention**: Some date commands may produce debug output in certain shell environments. Always redirect stderr with `2>/dev/null` and provide fallbacks.

## Stash Reference Management

**Stash Index Shifting**: When deleting multiple stashes, git re-indexes remaining stashes, causing reference conflicts:
- **Problem**: Deleting `stash@{1}` makes `stash@{2}` become `stash@{1}`, breaking subsequent deletions
- **Solution**: Always delete from highest index to lowest (`stash@{3}` → `stash@{2}` → `stash@{1}` → `stash@{0}`)
- **Implementation**: Use `sort -t'{' -k2 -nr` to sort stash references in descending order

**Stash Deletion Best Practices**:
- Collect all stash references first, then sort by index
- Delete in reverse order to avoid reference shifting
- Use temporary files to avoid subshell variable scope issues
- Provide clear progress feedback during batch operations

**Safe Stash Processing**: 
- Always validate stash references exist before deletion attempts
- Handle partial failures gracefully (some stashes deleted, others failed)
- Report accurate counts of successful vs failed deletions

## Temp File Management

**Working Directory vs System Temp**:
- **Working Directory**: Use only when files must be added to git (e.g., `git_undo` metadata)
- **System Temp (`/tmp/`)**: Use for processing files that don't need to be in git
- **Process ID Suffix**: Always use `$$` suffix for uniqueness: `/tmp/git-toolkit-operation-$$`
- **Cleanup**: Always clean up temp files in all code paths (success, failure, cancellation)

**NEVER** create temp files in repository root - always use isolated test directories or system temp.

**Safe Temp File Cleanup**: Some systems have `rm` aliased to `trash` utilities that produce error messages when files don't exist. Always check file existence before cleanup:
```bash
# AVOID: May produce "trash: path does not exist" errors
rm -f "$temp_file"

# PREFER: Only remove if file exists
[ -f "$temp_file" ] && rm -f "$temp_file"
```

**When This Matters**: Particularly important in conditional cleanup scenarios where temp files may not have been created due to early returns or failed operations.

**MANDATORY for All File Deletions**: This pattern MUST be used for ALL file deletion operations in the codebase, not just temp files. Any use of `rm -f` without a preceding file existence check is considered a bug and must be fixed. This ensures if `rm` is aliased (ex. `trash`) the user does not see a `path does not exist` error shown.

## Shell Debug Output Suppression

**Debug Mode Isolation**: When shell debug mode (`set -x`) is active in the environment, variable assignments and function calls produce unwanted debug output. To suppress this for specific operations:

**Subshell Isolation Technique**: Use subshells `()` to completely isolate operations from parent shell's debug mode:
```bash
# AVOID: This will show debug output when set -x is active
_function_with_debug_issues() {
    local result
    result=$(some_command)
    echo "$result"
}

# PREFER: Subshell isolation completely prevents debug output
_function_quiet() {
    local param="$1"
    (
        some_command_that_might_be_traced
    ) 2>/dev/null
}
```

**Key Benefits**: 
- Subshells run in separate process context, inheriting no debug state
- Complete isolation from parent shell's `set -x` mode  
- No complex debug enable/disable logic needed
- Works reliably across all shell environments

## Git File Status Detection

**File Status Commands**: When showing uncommitted changes, use `git diff --name-status` instead of `git diff --name-only` to get file status information:
- **Status Codes**: `M` (modified), `D` (deleted), `A` (added), `R` (renamed)
- **Renamed File Format**: For renames, Git outputs `R<percentage>\told-name\tnew-name` (tab-delimited)
- **Parsing**: Use `IFS=$'\t'` with `read -r` to properly parse tab-delimited output

**Reserved Variable Conflicts**: 
- **Problem**: The variable name `status` is read-only in some shells (like zsh)
- **Solution**: Use descriptive names like `file_status` instead of generic `status`
- **Detection**: Error message "read-only variable: status" indicates this issue

**Display Formatting Best Practices**:
- Show file status type before filename: `deleted:    filename.txt`
- Use consistent spacing for alignment across different status types
- Match Git's standard color scheme: green for staged, red for unstaged
- Handle renamed files specially: `renamed:    old-name -> new-name`

**Implementation Pattern**:
```bash
# Get files with status information
local staged_files_with_status
staged_files_with_status=$(git diff --cached --name-status 2>/dev/null)

# Parse with proper tab handling
echo "$staged_files_with_status" | while IFS=$'\t' read -r file_status file rest; do
    case "$file_status" in
        M*) printf "    modified:   %s\n" "$file" ;;
        D*) printf "    deleted:    %s\n" "$file" ;;
        R*) printf "    renamed:    %s -> %s\n" "$file" "$rest" ;;
        # ... other cases
    esac
done
```

**Testing Considerations**:
- Always test with actual deleted files (`rm file.txt`) not just staged deletions
- Test renamed files with `git mv old-name new-name`
- Verify both staged and unstaged changes are displayed correctly
- Check that mixed states (e.g., staged rename + unstaged modification) work properly

## Unwanted Variable Output in Shell Functions

**Problem**: The `git_show_branches` and `git_show_stashes` functions were outputting variable assignments directly to the terminal in certain shell environments (particularly zsh), showing lines like:
```
# From git_show_branches:
remote_ref=origin
branch_display='develop  '
commit_count=2

# From git_show_stashes:
date_display='2025-05-17 13:24:07  '
name_display='On develop: Fork autostash May 17, 2025 at 1:24 PM'
age_display='48 days old  '
```

**Root Cause**: When shell debug mode (`set -x`) is active in the parent shell environment, or when certain shell options are set, variable assignments within functions can be output to stderr, which then appears in the terminal output.

**Solution**: Create a wrapper function that filters out these debug outputs using `grep -v`:

```bash
# Wrapper function that filters debug output for git_show_branches
git_show_branches() {
    # Call the actual implementation and filter out debug output
    _git_show_branches_impl "$@" 2>&1 | grep -v "^remote_ref=" | grep -v "^remote_branch=" | grep -v "^branch_display=" | grep -v "^commit_count=" | grep -v "^local_only_display=" | grep -v "^remote_display=" | grep -v "^ahead=" | grep -v "^behind="
}

# Wrapper function that filters debug output for git_show_stashes
git_show_stashes() {
    # Call the actual implementation and filter out debug output
    _git_show_stashes_impl "$@" 2>&1 | grep -v "^date_display=" | grep -v "^name_display=" | grep -v "^age_display=" | grep -v "^formatted_date=" | grep -v "^stash_msg=" | grep -v "^age_days=" | grep -v "^stash_ref="
}

# Actual implementation functions
_git_show_branches_impl() {
    # Original git_show_branches code here...
}

_git_show_stashes_impl() {
    # Original git_show_stashes code here...
}
```

**Key Points**:
- The wrapper captures both stdout and stderr with `2>&1`
- Multiple `grep -v` commands filter out specific variable assignment patterns
- The actual implementation is moved to a separate `_impl` function
- This preserves the original function's behavior while cleaning the output

**When to Use This Pattern**:
- When a function produces unwanted debug output that can't be suppressed at the source
- When the debug output follows a predictable pattern that can be filtered
- As a last resort when other debug suppression methods don't work

**Alternative Approaches Tried**:
- Adding `set +x` at function start (didn't work for all cases)
- Using subshells to isolate debug state (didn't prevent all output)
- Searching for bare variable names in the code (none found)

This wrapper pattern ensures clean output across all shell environments while maintaining full functionality.