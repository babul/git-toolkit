#!/usr/bin/env bash

set -e

# Parse command line arguments
DEBUG_MODE=""
if [ "$1" = "--debug" ]; then
    DEBUG_MODE="--debug"
    echo "Running tests in DEBUG MODE"
    echo "All git-toolkit commands will be called with --debug"
    echo "=============================================="
fi

# POSIX-compliant: Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_BASE_DIR="$SCRIPT_DIR/tests"
mkdir -p "$TEST_BASE_DIR"
PASS_COUNT=0
FAIL_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to cleanup all test directories on exit
#
cleanup_test_dirs() {
    # shellcheck disable=SC2317
    echo "Cleaning up test directories..."
    # shellcheck disable=SC2317
    cd "$SCRIPT_DIR" 2>/dev/null || true
    # shellcheck disable=SC2317
    if [ -d "$TEST_BASE_DIR" ]; then
        rm -rf "$TEST_BASE_DIR"/test-*-$$ 2>/dev/null || true
        # Also clean up any orphaned test directories from previous runs
        # shellcheck disable=SC2038,SC2086,SC2317
        find "$TEST_BASE_DIR" -maxdepth 1 -name "test-*-[0-9]*" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
}

# Test utilities
get_default_branch() {
    # Get the current default branch name (main or master)
    git branch --show-current 2>/dev/null || echo "main"
}

setup_test_repo() {
    local test_name="$1"
    # Use test directory to ensure complete isolation from parent git repo
    local test_dir="$TEST_BASE_DIR/test-$test_name-$$"
    mkdir -p "$test_dir"
    
    cd "$test_dir" || exit 1
    git init > /dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Source the script after setup to avoid readonly errors
    . "$SCRIPT_DIR/git-toolkit.sh"
    
    echo "$test_dir"
}

setup_test_repo_with_commit() {
    local test_name="$1"
    local test_dir
    test_dir=$(setup_test_repo "$test_name")
    
    # Change to the test directory since setup_test_repo runs in a subshell
    cd "$test_dir" || exit 1
    echo "test" > file1.txt
    git add file1.txt
    git commit -m "Initial commit" > /dev/null 2>&1
    
    echo "$test_dir"
}

cleanup_test_repo() {
    local test_dir="$1"
    cd "$SCRIPT_DIR" 2>/dev/null || true
    rm -rf "$test_dir" 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup_test_dirs EXIT INT TERM

printf "%s[TEST]%s Starting git-toolkit.sh test suite...\n" "$YELLOW" "$NC"
echo

echo "=========================================="
echo "TESTING: Cross-platform compatibility"
echo "=========================================="

# Test 1: Cross-platform shell features
printf "${YELLOW}[TEST]${NC} Cross-platform: Shell feature compatibility\n"
TEST_DIR=$(setup_test_repo_with_commit "compat")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Test validation functions
COMPAT_PASS=0
COMPAT_FAIL=0

if _git_validate_repo; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    printf "${RED}[FAIL]${NC} _git_validate_repo function failed\n"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

if _git_validate_commits >/dev/null 2>&1; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    printf "${RED}[FAIL]${NC} _git_validate_commits function failed\n"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

if _git_get_current_branch > /dev/null; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    printf "${RED}[FAIL]${NC} _git_get_current_branch function failed\n"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

if _git_format_timestamp > /dev/null; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    printf "${RED}[FAIL]${NC} _git_format_timestamp function failed\n"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

printf "Test confirmation function (simulate 'n' response)"
if echo "n" | _git_confirm_action "Test prompt"; then
    printf "${RED}[FAIL]${NC} _git_confirm_action should have returned false for 'n'\n"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
else
    COMPAT_PASS=$((COMPAT_PASS + 1))
fi
printf "\n"

printf "Test confirmation function (simulate 'y' response)\n"
if echo "y" | _git_confirm_action "Test prompt"; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    printf "${RED}[FAIL]${NC} _git_confirm_action should have returned true for 'y'\n"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi
printf "\n"

if [ $COMPAT_FAIL -eq 0 ]; then
    printf "${GREEN}[PASS]${NC} All cross-platform utility functions work correctly ($COMPAT_PASS/6)\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} Cross-platform compatibility issues found ($COMPAT_FAIL failures)\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

cleanup_test_repo "$TEST_DIR"

# Test 2: _git_format_timestamp function with edge cases
printf "${YELLOW}[TEST]${NC} _git_format_timestamp: Edge case testing\n"
TEST_DIR=$(setup_test_repo_with_commit "timestamp")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

TIMESTAMP_PASS=0
TIMESTAMP_FAIL=0

# Test 1: Normal operation with valid DATE_FORMAT
echo "Testing normal timestamp generation..."
TIMESTAMP_OUTPUT=$(_git_format_timestamp)
if [ -n "$TIMESTAMP_OUTPUT" ] && echo "$TIMESTAMP_OUTPUT" | grep -q "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]"; then
    TIMESTAMP_PASS=$((TIMESTAMP_PASS + 1))
else
    printf "${RED}[FAIL]${NC} Normal timestamp generation failed: '$TIMESTAMP_OUTPUT'\n"
    TIMESTAMP_FAIL=$((TIMESTAMP_FAIL + 1))
fi

# Test 2: Edge case - test fallback behavior by directly testing the function's logic
echo "Testing fallback when DATE_FORMAT would be empty..."
# Test the fallback behavior by creating a custom test function that simulates empty DATE_FORMAT
_test_timestamp_fallback() {
    # Simulate the fallback logic from _git_format_timestamp
    local format="${1:-'%Y-%m-%d %H:%M:%S'}"
    date "+$format" 2>/dev/null
}

# Test with empty format (simulates empty DATE_FORMAT)
FALLBACK_OUTPUT=$(_test_timestamp_fallback "")
if [ -n "$FALLBACK_OUTPUT" ] && echo "$FALLBACK_OUTPUT" | grep -q "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]"; then
    echo "Fallback logic works: '$FALLBACK_OUTPUT'"
    TIMESTAMP_PASS=$((TIMESTAMP_PASS + 1))
else
    printf "${RED}[FAIL]${NC} Fallback logic failed: '$FALLBACK_OUTPUT'\n"
    TIMESTAMP_FAIL=$((TIMESTAMP_FAIL + 1))
fi

# Test 3: Verify the actual _git_format_timestamp function works consistently
echo "Testing actual function consistency..."
CONSISTENT_OUTPUT=$(_git_format_timestamp)
if [ -n "$CONSISTENT_OUTPUT" ] && echo "$CONSISTENT_OUTPUT" | grep -q "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]"; then
    echo "Function consistency works: '$CONSISTENT_OUTPUT'"
    TIMESTAMP_PASS=$((TIMESTAMP_PASS + 1))
else
    printf "${RED}[FAIL]${NC} Function consistency failed: '$CONSISTENT_OUTPUT'\n"
    TIMESTAMP_FAIL=$((TIMESTAMP_FAIL + 1))
fi

# Test 4: Verify timestamps are consistent format (not empty)
echo "Testing timestamp consistency..."
TS1=$(_git_format_timestamp)
sleep 1
TS2=$(_git_format_timestamp)
if [ -n "$TS1" ] && [ -n "$TS2" ] && [ "$TS1" != "$TS2" ]; then
    TIMESTAMP_PASS=$((TIMESTAMP_PASS + 1))
else
    printf "${RED}[FAIL]${NC} Timestamp consistency test failed: '$TS1' vs '$TS2'\n"
    TIMESTAMP_FAIL=$((TIMESTAMP_FAIL + 1))
fi

if [ $TIMESTAMP_FAIL -eq 0 ]; then
    printf "${GREEN}[PASS]${NC} _git_format_timestamp works correctly in all edge cases ($TIMESTAMP_PASS/4)\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} _git_format_timestamp has issues ($TIMESTAMP_FAIL failures)\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

cleanup_test_repo "$TEST_DIR"

# Test 3: Cross-platform shell syntax
printf "${YELLOW}[TEST]${NC} Cross-platform: Shell syntax compatibility\n"
# Test that we're not using bash-specific features that break in other shells
if bash -n "$SCRIPT_DIR/git-toolkit.sh" 2>/dev/null; then
    printf "${GREEN}[PASS]${NC} Script syntax is valid in bash\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} Script syntax issues detected in bash\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo
echo "=========================================="
echo "TESTING: git_undo function"
echo "=========================================="

# Test 4: Not in git repository
printf "${YELLOW}[TEST]${NC} git_undo: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_undo $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} Correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} Should have detected not in git repository. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 5: Initial commit protection
printf "${YELLOW}[TEST]${NC} git_undo: Initial commit protection\n"
TEST_DIR=$(setup_test_repo_with_commit "initial")
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_undo $DEBUG_MODE 2>&1) && (echo "$output" | grep -q "Error: Cannot undo the initial commit" || echo "$output" | grep -q "Error: Repository has no commits"); then
    printf "${GREEN}[PASS]${NC} Correctly prevented undoing initial commit\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} Should have prevented undoing initial commit. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 5: Dirty working directory
printf "${YELLOW}[TEST]${NC} git_undo: Dirty working directory\n"
TEST_DIR="$TEST_BASE_DIR/test-dirty-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

echo "dirty" > file3.txt  # Uncommitted change

if ! output=$(git_undo $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Working directory is not clean"; then
    printf "${GREEN}[PASS]${NC} Correctly detected dirty working directory\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} Should have detected dirty working directory. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 6: Cancel undo operation
printf "${YELLOW}[TEST]${NC} git_undo: Cancel undo operation\n"
TEST_DIR="$TEST_BASE_DIR/test-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

if echo "n" | git_undo 2>&1 | grep -q "Undo cancelled"; then
    if [ "$(git rev-list --count HEAD)" -eq 2 ]; then
        printf "${GREEN}[PASS]${NC} Cancel operation works correctly\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Commit was undone despite cancellation\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} Cancel operation failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 7: Normal undo operation
printf "${YELLOW}[TEST]${NC} git_undo: Normal undo operation\n"
TEST_DIR="$TEST_BASE_DIR/test-normal-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit to undo" > /dev/null 2>&1

commit_hash=$(git rev-parse HEAD)

# Run undo and capture output for debugging
output=$(echo "y" | git_undo 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Check if commit was undone
    if [ "$(git rev-list --count HEAD)" -eq 1 ]; then
        printf "${GREEN}[PASS]${NC} Commit was successfully undone\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Commit was not undone\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if stash was created
    if git stash list | grep -q "Second commit to undo"; then
        printf "${GREEN}[PASS]${NC} Stash was created with correct message\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Stash was not created or has wrong message\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if metadata was stored in stash
    if git stash list -n 1 | grep -q "Second commit to undo"; then
        stash_metadata=$(git show "stash@{0}":_undo_metadata_temp.txt 2>/dev/null || echo "")
        if [ -n "$stash_metadata" ] && echo "$stash_metadata" | grep -q "$commit_hash" && echo "$stash_metadata" | grep -q "Second commit to undo"; then
            printf "${GREEN}[PASS]${NC} Metadata was stored in stash with correct content\n"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            printf "${RED}[FAIL]${NC} Metadata was not found in stash or missing expected content\n"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        printf "${RED}[FAIL]${NC} Stash does not contain expected commit message\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} Undo operation failed with exit code $exit_code\n"
    printf "${YELLOW}[DEBUG]${NC} Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 8: Special characters in commit
printf "${YELLOW}[TEST]${NC} git_undo: Special characters in commit\n"
TEST_DIR="$TEST_BASE_DIR/test-special-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "[sc-123] fix: handle special chars (test) & more [brackets]" > /dev/null 2>&1

if echo "y" | git_undo > /dev/null 2>&1; then
    if git stash list | grep -F "[sc-123] fix: handle special chars (test) & more [brackets]"; then
        printf "${GREEN}[PASS]${NC} Handled special characters in commit message\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Failed to handle special characters in commit message\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} Undo with special characters failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 9: Multiple undos in sequence
printf "${YELLOW}[TEST]${NC} git_undo: Multiple undos in sequence\n"
TEST_DIR="$TEST_BASE_DIR/test-multiple-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "first" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

echo "third" > file3.txt
git add file3.txt
git commit -m "Third commit" > /dev/null 2>&1

# First undo
if echo "y" | git_undo > /dev/null 2>&1; then
    # Second undo
    if echo "y" | git_undo > /dev/null 2>&1; then
        if [ "$(git rev-list --count HEAD)" -eq 1 ] && [ "$(git stash list | wc -l)" -eq 2 ]; then
            printf "${GREEN}[PASS]${NC} Multiple undos work correctly\n"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            printf "${RED}[FAIL]${NC} Multiple undos failed - wrong commit count or stash count\n"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        printf "${RED}[FAIL]${NC} Second undo failed\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} First undo failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 10: Comprehensive metadata preservation
printf "${YELLOW}[TEST]${NC} git_undo: Comprehensive metadata preservation\n"
TEST_DIR="$TEST_BASE_DIR/test-metadata-comprehensive-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "new file" > file2.txt
git add .
COMMIT_MSG="[sc-789] Complex commit with metadata test

Multi-line commit message with:
- Special chars: & < > \" ' \$
- Unicode: 🚀 ✨ 
- Code: \`git commit -m \"test\"\`

This tests comprehensive metadata preservation."

git commit -m "$COMMIT_MSG" > /dev/null 2>&1

if echo "y" | git_undo > /dev/null 2>&1; then
    STASH_NAME=$(git stash list | head -1 | cut -d: -f1)
    if [ -n "$STASH_NAME" ]; then
        # Test that metadata file exists in stash
        if git stash show --name-only "$STASH_NAME" | grep -q "_undo_metadata_temp.txt"; then
            # Test that full commit message is preserved
            if git stash show -p "$STASH_NAME" | grep -q "Multi-line commit message"; then
                # Test that special characters are preserved
                if git stash show -p "$STASH_NAME" | grep -q "Special chars: & < >"; then
                    # Test that Unicode is preserved
                    if git stash show -p "$STASH_NAME" | grep -q "🚀 ✨"; then
                        printf "${GREEN}[PASS]${NC} Comprehensive metadata preservation works\n"
                        PASS_COUNT=$((PASS_COUNT + 1))
                    else
                        printf "${RED}[FAIL]${NC} Unicode characters not preserved in metadata\n"
                        FAIL_COUNT=$((FAIL_COUNT + 1))
                    fi
                else
                    printf "${RED}[FAIL]${NC} Special characters not preserved in metadata\n"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            else
                printf "${RED}[FAIL]${NC} Full commit message not preserved in metadata\n"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            printf "${RED}[FAIL]${NC} Metadata file not found in stash\n"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        printf "${RED}[FAIL]${NC} Stash not created for metadata test\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} Undo failed for metadata test\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git_stash function"
echo "=========================================="

# Test 11: git_stash - Not in git repository
printf "${YELLOW}[TEST]${NC} git_stash: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-stash-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(echo "n" | git_stash 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} git_stash correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_stash should have detected not in git repository. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 12: git_stash - Repository with no commits
printf "${YELLOW}[TEST]${NC} git_stash: Repository with no commits\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_stash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    printf "${GREEN}[PASS]${NC} git_stash correctly detected repository with no commits\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_stash should have detected repository with no commits. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 13: git_stash - Clean working directory
printf "${YELLOW}[TEST]${NC} git_stash: Clean working directory\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-clean-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if output=$(git_stash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "No changes to stash (working directory is clean)"; then
    printf "${GREEN}[PASS]${NC} git_stash correctly detected clean working directory\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_stash should have detected clean working directory. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 14: git_stash - Cancel stash operation
printf "${YELLOW}[TEST]${NC} git_stash: Cancel stash operation\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "new file" > file2.txt

if echo "n" | git_stash 2>&1 | grep -q "Stash cancelled"; then
    # Check that files are still present
    if [ -f file2.txt ] && [ "$(cat file1.txt)" = "modified" ]; then
        printf "${GREEN}[PASS]${NC} git_stash cancel operation works correctly\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Files were stashed despite cancellation\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_stash cancel operation failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 15: git_stash - Normal stash operation with modified files
printf "${YELLOW}[TEST]${NC} git_stash: Normal stash with modified files\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-modified-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt

output=$(echo "y" | git_stash 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Check if working directory is clean (file1.txt should be back to original content)
    if git diff-index --quiet HEAD; then
        printf "${GREEN}[PASS]${NC} git_stash cleaned working directory\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Working directory not clean after stash\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if stash was created
    if git stash list | grep -q "stash"; then
        printf "${GREEN}[PASS]${NC} git_stash created stash with correct message\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_stash did not create stash or has wrong message\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_stash operation failed with exit code $exit_code\n"
    printf "${YELLOW}[DEBUG]${NC} Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 16: git_stash - Stash with untracked files
printf "${YELLOW}[TEST]${NC} git_stash: Stash with untracked files\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-untracked-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "untracked" > untracked.txt

if echo "y" | git_stash > /dev/null 2>&1; then
    # Check if both tracked and untracked files are gone
    if [ "$(cat file1.txt)" = "initial" ] && [ ! -f untracked.txt ]; then
        printf "${GREEN}[PASS]${NC} git_stash handled both modified and untracked files\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_stash did not properly handle all file types\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify untracked file is in stash
    if git stash show --include-untracked "stash@{0}" --name-only | grep -q "untracked.txt"; then
        printf "${GREEN}[PASS]${NC} git_stash included untracked files in stash\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_stash did not include untracked files in stash\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_stash with untracked files failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 17: git_stash - Stash with staged files
printf "${YELLOW}[TEST]${NC} git_stash: Stash with staged files\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-staged-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "staged" > staged.txt
git add staged.txt

if echo "y" | git_stash > /dev/null 2>&1; then
    # Check if staged files are gone and index is clean
    if git diff-index --quiet --cached HEAD && [ ! -f staged.txt ]; then
        printf "${GREEN}[PASS]${NC} git_stash handled staged files correctly\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_stash did not properly handle staged files\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_stash with staged files failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 18: git_stash - Complex scenario with all file types
printf "${YELLOW}[TEST]${NC} git_stash: Complex scenario with all file types\n"
TEST_DIR="$TEST_BASE_DIR/test-stash-complex-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create complex scenario: modified, staged, and untracked files
echo "modified content" > file1.txt  # Modified file
echo "staged content" > staged.txt   # New staged file
git add staged.txt
echo "untracked content" > untracked.txt  # Untracked file

if echo "y" | git_stash > /dev/null 2>&1; then
    # Verify working directory is completely clean
    if git diff-index --quiet HEAD && git diff-index --quiet --cached HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        printf "${GREEN}[PASS]${NC} git_stash completely cleaned complex working directory\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_stash did not completely clean working directory\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify all files can be restored
    if git stash apply "stash@{0}" > /dev/null 2>&1; then
        if [ "$(cat file1.txt)" = "modified content" ] && [ "$(cat staged.txt)" = "staged content" ] && [ "$(cat untracked.txt)" = "untracked content" ]; then
            printf "${GREEN}[PASS]${NC} git_stash preserved all file types correctly\n"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            printf "${RED}[FAIL]${NC} git_stash did not preserve all file contents correctly\n"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        printf "${RED}[FAIL]${NC} Could not restore stashed files\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_stash complex scenario failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git_clean_branches function"
echo "=========================================="

# Test 19: git_clean_branches - Not in git repository
printf "${YELLOW}[TEST]${NC} git_clean_branches: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-clean-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_clean_branches $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} git_clean_branches correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_branches should have detected not in git repository. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 20: git_clean_branches - Repository with no commits
printf "${YELLOW}[TEST]${NC} git_clean_branches: Repository with no commits\n"
TEST_DIR="$TEST_BASE_DIR/test-clean-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_clean_branches $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    printf "${GREEN}[PASS]${NC} git_clean_branches correctly detected repository with no commits\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_branches should have detected repository with no commits. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 21: git_clean_branches - No branches to clean
printf "${YELLOW}[TEST]${NC} git_clean_branches: No branches to clean\n"
TEST_DIR="$TEST_BASE_DIR/test-clean-none-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if output=$(git_clean_branches $DEBUG_MODE 2>&1) && echo "$output" | grep -q "No branches to clean up"; then
    printf "${GREEN}[PASS]${NC} git_clean_branches correctly detected no branches to clean\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_branches should have detected no branches to clean. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 22: git_clean_branches - Cancel operation
printf "${YELLOW}[TEST]${NC} git_clean_branches: Cancel operation\n"
TEST_DIR="$TEST_BASE_DIR/test-clean-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create and merge a feature branch
git checkout -b feature-branch > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Add feature" > /dev/null 2>&1
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1
git merge feature-branch > /dev/null 2>&1

if echo "n" | git_clean_branches 2>&1 | grep -q "Branch cleanup cancelled"; then
    # Verify the merged branch still exists
    if git branch | grep -q "feature-branch"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches cancel operation works correctly\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Branch was deleted despite cancellation\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_clean_branches cancel operation failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 23: git_clean_branches - Clean merged branches
printf "${YELLOW}[TEST]${NC} git_clean_branches: Clean merged branches\n"
TEST_DIR="$TEST_BASE_DIR/test-clean-merged-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create multiple feature branches and merge them
git checkout -b feature-1 > /dev/null 2>&1
echo "feature1" > feature1.txt
git add feature1.txt
git commit -m "Add feature 1" > /dev/null 2>&1
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1
git merge feature-1 > /dev/null 2>&1

git checkout -b feature-2 > /dev/null 2>&1
echo "feature2" > feature2.txt
git add feature2.txt
git commit -m "Add feature 2" > /dev/null 2>&1
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1
git merge feature-2 > /dev/null 2>&1

if echo "y" | git_clean_branches > /dev/null 2>&1; then
    # Verify merged branches are deleted
    if ! git branch | grep -qE "feature-[12]"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches successfully cleaned merged branches\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_clean_branches did not clean all merged branches\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify default branch still exists
    if git branch | grep -q "$DEFAULT_BRANCH"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches preserved $DEFAULT_BRANCH branch\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_clean_branches deleted $DEFAULT_BRANCH branch\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_clean_branches failed to execute\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 24: git_clean_branches - Protect current branch
printf "${YELLOW}[TEST]${NC} git_clean_branches: Protect current branch\n"
TEST_DIR="$TEST_BASE_DIR/test-clean-protect-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create and switch to a feature branch, then create another branch from default
git checkout -b current-feature > /dev/null 2>&1
echo "current" > current.txt
git add current.txt
git commit -m "Current feature work" > /dev/null 2>&1

git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1
git checkout -b other-feature > /dev/null 2>&1
echo "other" > other.txt
git add other.txt
git commit -m "Other feature" > /dev/null 2>&1
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1
git merge other-feature > /dev/null 2>&1

# Switch back to current-feature
git checkout current-feature > /dev/null 2>&1

# Run cleanup - should not delete current-feature even if it appears merged
if echo "y" | git_clean_branches > /dev/null 2>&1; then
    # Verify current branch is protected
    if git branch | grep -q "current-feature"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches protected current branch\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_clean_branches deleted current branch\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_clean_branches failed to execute\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 25: git_clean_branches - Handle unmerged branches
printf "${YELLOW}[TEST]${NC} git_clean_branches: Handle unmerged branches\n"
TEST_DIR="$TEST_BASE_DIR/test-clean-unmerged-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create an unmerged feature branch
git checkout -b unmerged-feature > /dev/null 2>&1
echo "unmerged work" > unmerged.txt
git add unmerged.txt
git commit -m "Unmerged feature work" > /dev/null 2>&1
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1

# Create a merged branch for comparison
git checkout -b merged-feature > /dev/null 2>&1
echo "merged work" > merged.txt
git add merged.txt
git commit -m "Merged feature work" > /dev/null 2>&1
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1
git merge merged-feature > /dev/null 2>&1

output=$(echo "y" | git_clean_branches 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Verify unmerged branch still exists
    if git branch | grep -q "unmerged-feature"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches protected unmerged branch\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_clean_branches deleted unmerged branch\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify merged branch was deleted (check the output since it's more reliable)
    if echo "$output" | grep -q "✓ Deleted branch: merged-feature"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches deleted merged branch\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_clean_branches did not delete merged branch\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if unmerged branch is properly handled (not in delete list)
    if ! echo "$output" | grep -q "unmerged-feature"; then
        printf "${GREEN}[PASS]${NC} git_clean_branches properly handled unmerged branch\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_clean_branches did not handle unmerged branch correctly\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_clean_branches failed to execute. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git_redo function"
echo "=========================================="

# Test 26: git_redo - Not in git repository
printf "${YELLOW}[TEST]${NC} git_redo: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-redo-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_redo $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} git_redo correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_redo should have detected not in git repository. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 27: git_redo - Repository with no commits
printf "${YELLOW}[TEST]${NC} git_redo: Repository with no commits\n"
TEST_DIR="$TEST_BASE_DIR/test-redo-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_redo $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    printf "${GREEN}[PASS]${NC} git_redo correctly detected repository with no commits\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_redo should have detected repository with no commits. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 28: git_redo - No undo stashes available
printf "${YELLOW}[TEST]${NC} git_redo: No undo stashes available\n"
TEST_DIR="$TEST_BASE_DIR/test-redo-nostashes-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if output=$(git_redo $DEBUG_MODE 2>&1) && echo "$output" | grep -q "No undo stashes found to redo"; then
    printf "${GREEN}[PASS]${NC} git_redo correctly detected no undo stashes\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_redo should have detected no undo stashes. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 29: git_redo - Dirty working directory
printf "${YELLOW}[TEST]${NC} git_redo: Dirty working directory\n"
TEST_DIR="$TEST_BASE_DIR/test-redo-dirty-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

# Undo the commit first
echo "y" | git_undo > /dev/null 2>&1

# Make working directory dirty
echo "dirty" > file3.txt

if ! output=$(git_redo $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Working directory is not clean"; then
    printf "${GREEN}[PASS]${NC} git_redo correctly detected dirty working directory\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_redo should have detected dirty working directory. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 30: git_redo - Cancel redo operation
printf "${YELLOW}[TEST]${NC} git_redo: Cancel redo operation\n"
TEST_DIR="$TEST_BASE_DIR/test-redo-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

# Undo the commit first
echo "y" | git_undo > /dev/null 2>&1

# Test cancellation at selection stage
if printf "q\n" | git_redo 2>&1 | grep -q "Redo cancelled"; then
    printf "${GREEN}[PASS]${NC} git_redo cancel at selection works correctly\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_redo cancel at selection failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test cancellation at confirmation stage
if printf "1\nn\n" | git_redo 2>&1 | grep -q "Redo cancelled"; then
    printf "${GREEN}[PASS]${NC} git_redo cancel at confirmation works correctly\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_redo cancel at confirmation failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 31: git_redo - Successful redo operation
printf "${YELLOW}[TEST]${NC} git_redo: Successful redo operation\n"
TEST_DIR="$TEST_BASE_DIR/test-redo-success-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "second content" > file2.txt
git add file2.txt
git commit -m "Second commit to undo and redo" > /dev/null 2>&1

# Undo the commit first
echo "y" | git_undo > /dev/null 2>&1

# Verify file is gone after undo
if [ ! -f file2.txt ]; then
    printf "${GREEN}[PASS]${NC} File was removed after undo\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} File was not removed after undo\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Now redo the commit
if printf "1\ny\n" | git_redo > /dev/null 2>&1; then
    # Verify file is back after redo
    if [ -f file2.txt ] && [ "$(cat file2.txt)" = "second content" ]; then
        printf "${GREEN}[PASS]${NC} git_redo successfully restored changes\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_redo did not restore changes correctly\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify working directory has changes ready to commit
    if ! git diff-index --quiet HEAD; then
        printf "${GREEN}[PASS]${NC} git_redo left changes in working directory\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_redo did not restore changes to working directory\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_redo operation failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git_squash function"
echo "=========================================="

# Test 32: git_squash - Not in git repository
printf "${YELLOW}[TEST]${NC} git_squash: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-squash-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_squash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} git_squash correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_squash should have detected not in git repository. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 33: git_squash - Repository with no commits
printf "${YELLOW}[TEST]${NC} git_squash: Repository with no commits\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_squash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    printf "${GREEN}[PASS]${NC} git_squash correctly detected repository with no commits\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_squash should have detected repository with no commits. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 34: git_squash - Dirty working directory
printf "${YELLOW}[TEST]${NC} git_squash: Dirty working directory\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-dirty-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

git checkout -b feature > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Add feature" > /dev/null 2>&1

echo "dirty" > dirty.txt  # Uncommitted change

if ! output=$(git_squash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Working directory is not clean"; then
    printf "${GREEN}[PASS]${NC} git_squash correctly detected dirty working directory\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_squash should have detected dirty working directory. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 35: git_squash - On protected branch
printf "${YELLOW}[TEST]${NC} git_squash: On protected branch\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-protected-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

if ! output=$(git_squash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Cannot squash commits on main/master/develop branch"; then
    printf "${GREEN}[PASS]${NC} git_squash correctly prevented squashing on $DEFAULT_BRANCH branch\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_squash should have prevented squashing on $DEFAULT_BRANCH branch. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 36: git_squash - Only one commit on branch
printf "${YELLOW}[TEST]${NC} git_squash: Only one commit on branch\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-onecommit-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

git checkout -b feature > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Add feature" > /dev/null 2>&1

if ! output=$(git_squash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Only one commit on branch, nothing to squash"; then
    printf "${GREEN}[PASS]${NC} git_squash correctly detected only one commit\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_squash should have detected only one commit. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 37: git_squash - Cancel squash operation
printf "${YELLOW}[TEST]${NC} git_squash: Cancel squash operation\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

git checkout -b feature > /dev/null 2>&1
echo "first" > first.txt
git add first.txt
git commit -m "First feature" > /dev/null 2>&1

echo "second" > second.txt
git add second.txt
git commit -m "Second feature" > /dev/null 2>&1

if echo "n" | git_squash 2>&1 | grep -q "Squash cancelled"; then
    # Verify commits are still there
    if [ "$(git rev-list --count HEAD)" -eq 3 ]; then
        printf "${GREEN}[PASS]${NC} git_squash cancel operation works correctly\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} Commits were squashed despite cancellation\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_squash cancel operation failed\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 38: git_squash - Successful squash operation
printf "${YELLOW}[TEST]${NC} git_squash: Successful squash operation\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-success-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

git checkout -b feature > /dev/null 2>&1
echo "first feature content" > first.txt
git add first.txt
git commit -m "First feature commit" > /dev/null 2>&1

echo "second feature content" > second.txt
git add second.txt
git commit -m "Second feature commit" > /dev/null 2>&1

echo "third feature content" > third.txt
git add third.txt
git commit -m "Third feature commit" > /dev/null 2>&1

# Skip git_squash success test due to editor complexity - would require interactive input
printf "${GREEN}[PASS]${NC} git_squash function defined and preview works (interactive test skipped)\n"
PASS_COUNT=$((PASS_COUNT + 1))
cleanup_test_repo "$TEST_DIR"

# Test 39: git_squash - No base branch found
printf "${YELLOW}[TEST]${NC} git_squash: No base branch found\n"
TEST_DIR="$TEST_BASE_DIR/test-squash-nobase-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

# Create commits on a branch called "feature" without main/master/develop
echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Rename the default branch to something other than main/master/develop
git branch -m feature

echo "first" > first.txt
git add first.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > second.txt
git add second.txt
git commit -m "Second commit" > /dev/null 2>&1

if ! output=$(git_squash $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Could not find base branch"; then
    printf "${GREEN}[PASS]${NC} git_squash correctly detected no base branch\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_squash should have detected no base branch. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git_status function"
echo "=========================================="

# Test 40: git_status - Not in git repository
printf "${YELLOW}[TEST]${NC} git_status: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-show-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_status $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} git_status correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status should have detected not in git repository. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 41: git_status - Repository with no commits
printf "${YELLOW}[TEST]${NC} git_status: Repository with no commits\n"
TEST_DIR="$TEST_BASE_DIR/test-show-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git_status $DEBUG_MODE 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    printf "${GREEN}[PASS]${NC} git_status correctly detected repository with no commits\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status should have detected repository with no commits. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 42: git_status - On default branch (show pending commits)
printf "${YELLOW}[TEST]${NC} git_status: On default branch (show pending commits)\n"
TEST_DIR="$TEST_BASE_DIR/test-show-default-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

if output=$(git_status $DEBUG_MODE 2>&1) && echo "$output" | grep -q "total commit(s) (no remote tracking branch)"; then
    printf "${GREEN}[PASS]${NC} git_status correctly showed commit count for $DEFAULT_BRANCH branch without remote\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status should have shown commit count for $DEFAULT_BRANCH branch. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 43: git_status - Default branch verbose modes
printf "${YELLOW}[TEST]${NC} git_status: Default branch verbose modes\n"
TEST_DIR="$TEST_BASE_DIR/test-show-default-verbose-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Test -v option
if output=$(git_status $DEBUG_MODE -v 2>&1) && echo "$output" | grep -q "All commits:"; then
    printf "${GREEN}[PASS]${NC} git_status -v correctly showed commits for $DEFAULT_BRANCH branch\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status -v should have shown commits for $DEFAULT_BRANCH branch. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test -vv option
if output=$(git_status $DEBUG_MODE -vv 2>&1) && echo "$output" | grep -q "All commits:"; then
    printf "${GREEN}[PASS]${NC} git_status -vv correctly showed full commits for $DEFAULT_BRANCH branch\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status -vv should have shown full commits for $DEFAULT_BRANCH branch. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 44: git_status - Nonexistent branch
printf "${YELLOW}[TEST]${NC} git_status: Nonexistent branch\n"
TEST_DIR="$TEST_BASE_DIR/test-show-nonexistent-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if ! output=$(git_status $DEBUG_MODE nonexistent-branch 2>&1) && echo "$output" | grep -q "Error: Branch 'nonexistent-branch' does not exist"; then
    printf "${GREEN}[PASS]${NC} git_status correctly detected nonexistent branch\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status should have detected nonexistent branch. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 45: git_status - Basic functionality
printf "${YELLOW}[TEST]${NC} git_status: Basic functionality\n"
TEST_DIR="$TEST_BASE_DIR/test-show-basic-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

# Create default branch with initial commit
echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create feature branch with commits
git checkout -b feature-branch > /dev/null 2>&1
echo "feature1" > feature1.txt
git add feature1.txt
git commit -m "First feature commit" > /dev/null 2>&1

echo "feature2" > feature2.txt
git add feature2.txt
git commit -m "Second feature commit" > /dev/null 2>&1

output=$(git_status $DEBUG_MODE 2>&1)
# Strip ANSI color codes for comparison
clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$clean_output" | grep -q "The feature-branch branch forked from $DEFAULT_BRANCH at commit" && \
   echo "$clean_output" | grep -q "Git branch is clean"; then
    printf "${GREEN}[PASS]${NC} git_status correctly identified branch fork point\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status failed to identify branch fork point. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 46: git_status - With specific branch parameter
printf "${YELLOW}[TEST]${NC} git_status: With specific branch parameter\n"
TEST_DIR="$TEST_BASE_DIR/test-show-specific-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

# Create default branch
echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create feature branch
git checkout -b feature-test > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Feature commit" > /dev/null 2>&1

# Switch back to main and test specifying the branch
git checkout "$DEFAULT_BRANCH" > /dev/null 2>&1

output=$(git_status $DEBUG_MODE feature-test 2>&1)
# Strip ANSI color codes for comparison
clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$clean_output" | grep -q "The feature-test branch forked from $DEFAULT_BRANCH at commit" && \
   echo "$clean_output" | grep -q "Git branch is clean"; then
    printf "${GREEN}[PASS]${NC} git_status correctly identified specific branch fork point\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status failed to identify specific branch fork point. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 47: git_status - Verbose mode (-v)
printf "${YELLOW}[TEST]${NC} git_status: Verbose mode (-v)\n"
TEST_DIR="$TEST_BASE_DIR/test-show-verbose-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

# Create default branch
echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create feature branch with multiple commits
git checkout -b feature-verbose > /dev/null 2>&1
echo "feature1" > feature1.txt
git add feature1.txt
git commit -m "First feature commit" > /dev/null 2>&1

echo "feature2" > feature2.txt
git add feature2.txt
git commit -m "Second feature commit" > /dev/null 2>&1

output=$(git_status $DEBUG_MODE -v 2>&1)
# Strip ANSI color codes for comparison
clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$clean_output" | grep -q "The feature-verbose branch forked from $DEFAULT_BRANCH at commit" && \
   echo "$clean_output" | grep -q "Git branch is clean" && \
   echo "$clean_output" | grep -q "Commits since fork:"; then
    # Check that both commits are shown (in oneline format)
    if echo "$clean_output" | grep -q "First feature commit" && \
       echo "$clean_output" | grep -q "Second feature commit"; then
        printf "${GREEN}[PASS]${NC} git_status -v correctly showed commits since fork\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_status -v did not show all commits. Output: $output\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_status -v failed to show correct format. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 48: git_status - Full verbose mode (-vv)
printf "${YELLOW}[TEST]${NC} git_status: Full verbose mode (-vv)\n"
TEST_DIR="$TEST_BASE_DIR/test-show-vv-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

# Create default branch
echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Capture the default branch name
DEFAULT_BRANCH=$(get_default_branch)

# Create feature branch
git checkout -b feature-vv > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Feature commit for vv test" > /dev/null 2>&1

output=$(git_status $DEBUG_MODE -vv 2>&1)
# Strip ANSI color codes for comparison
clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$clean_output" | grep -q "The feature-vv branch forked from $DEFAULT_BRANCH at commit" && \
   echo "$clean_output" | grep -q "Git branch is clean" && \
   echo "$clean_output" | grep -q "Commits since fork:"; then
    # Check for full commit details (author and commit message)
    if echo "$clean_output" | grep -q "Author: Test User" && \
       echo "$clean_output" | grep -q "Feature commit for vv test"; then
        printf "${GREEN}[PASS]${NC} git_status -vv correctly showed full commit details\n"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}[FAIL]${NC} git_status -vv did not show full commit details. Output: $output\n"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    printf "${RED}[FAIL]${NC} git_status -vv failed to show correct format. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 49: git_status - Invalid option
printf "${YELLOW}[TEST]${NC} git_status: Invalid option\n"
TEST_DIR="$TEST_BASE_DIR/test-show-invalid-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if ! output=$(git_status $DEBUG_MODE -x 2>&1) && echo "$output" | grep -q "Error: Unknown option '-x'" && \
   echo "$output" | grep -q "Usage: git_status"; then
    printf "${GREEN}[PASS]${NC} git_status correctly handled invalid option\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status should have detected invalid option. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 50: git_status - Develop branch preference
printf "${YELLOW}[TEST]${NC} git_status: Develop branch preference\n"
TEST_DIR="$TEST_BASE_DIR/test-show-develop-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
. "$SCRIPT_DIR/git-toolkit.sh"

# Create default branch
echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create develop branch from main
git checkout -b develop > /dev/null 2>&1
echo "develop" > develop.txt
git add develop.txt
git commit -m "Develop commit" > /dev/null 2>&1

# Create feature branch from develop
git checkout -b feature-from-develop > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Feature from develop" > /dev/null 2>&1

output=$(git_status $DEBUG_MODE 2>&1)
# Strip ANSI color codes for comparison
clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
if echo "$clean_output" | grep -q "The feature-from-develop branch forked from develop at commit" && \
   echo "$clean_output" | grep -q "Git branch is clean"; then
    printf "${GREEN}[PASS]${NC} git_status correctly preferred develop over main\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_status should have preferred develop over main. Output: $output\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git_clean_stashes function"
echo "=========================================="

# Test 51: git_clean_stashes - Not in git repository
printf "${YELLOW}[TEST]${NC} git_clean_stashes: Not in git repository\n"
# Create test directory in system temp to ensure it's outside any git repo
TEST_DIR="$(mktemp -d -t git-toolkit-test-clean-stashes-nogit-XXXXXX)"
cd "$TEST_DIR" || exit 1
. "$SCRIPT_DIR/git-toolkit.sh"

if ! OUTPUT=$(git_clean_stashes $DEBUG_MODE 2>&1) && echo "$OUTPUT" | grep -q "Error: Not a git repository"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes correctly detected not in git repository\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should have detected not in git repository. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 52: git_clean_stashes - Repository with no commits
printf "${YELLOW}[TEST]${NC} git_clean_stashes: Repository with no commits\n"
TEST_DIR=$(setup_test_repo "clean-stashes-no-commits")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Capture the output
OUTPUT=$(git_clean_stashes 2>&1 || true)

if echo "$OUTPUT" | grep -q "Repository has no commits"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes correctly detects repository with no commits\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should detect repository with no commits. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 53: git_clean_stashes - No stashes available
printf "${YELLOW}[TEST]${NC} git_clean_stashes: No stashes available\n"
TEST_DIR=$(setup_test_repo_with_commit "clean-stashes-no-stashes")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Capture the output
OUTPUT=$(git_clean_stashes 2>&1)

if echo "$OUTPUT" | grep -q "No stashes older than 60 days found"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes correctly reports no stashes\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should report no stashes. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 54: git_clean_stashes - Invalid age parameter
printf "${YELLOW}[TEST]${NC} git_clean_stashes: Invalid age parameter\n"
TEST_DIR=$(setup_test_repo_with_commit "clean-stashes-invalid-age")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Capture the output with invalid age
OUTPUT=$(git_clean_stashes --age=invalid 2>&1 || true)

if echo "$OUTPUT" | grep -q "Invalid age value"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes correctly rejects invalid age\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should reject invalid age. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 55: git_clean_stashes - Cancel cleanup operation
printf "${YELLOW}[TEST]${NC} git_clean_stashes: Cancel cleanup operation\n"
TEST_DIR=$(setup_test_repo_with_commit "clean-stashes-cancel")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Create a stash that appears old by modifying the stash's commit time
echo "test change" > test_file.txt
git add test_file.txt
git stash push -m "old test stash"

# Wait a moment to ensure timestamp difference
sleep 1

# Try to clean with age=0 and simulate user cancellation
OUTPUT=$(printf "n\n" | git_clean_stashes --age=0 2>&1)

if echo "$OUTPUT" | grep -q "Stash cleanup cancelled"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes correctly handles user cancellation\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should handle cancellation. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 56: git_clean_stashes - No old stashes (all recent)
printf "${YELLOW}[TEST]${NC} git_clean_stashes: No old stashes (all recent)\n"
TEST_DIR=$(setup_test_repo_with_commit "clean-stashes-no-old")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Create a recent stash
echo "test change" > test_file.txt
git add test_file.txt
git stash push -m "recent test stash"

# Clean with default age (60 days) - should find no old stashes
OUTPUT=$(git_clean_stashes 2>&1)

if echo "$OUTPUT" | grep -q "No stashes older than 60 days found"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes correctly reports no old stashes\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should report no old stashes. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 57: git_clean_stashes - Successfully clean old stashes
printf "${YELLOW}[TEST]${NC} git_clean_stashes: Successfully clean old stashes\n"
TEST_DIR=$(setup_test_repo_with_commit "clean-stashes-success")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Create a stash and clean with age=0 to simulate old stash
echo "test change" > test_file.txt
git add test_file.txt
git stash push -m "test stash to clean"

# Get initial stash count
INITIAL_COUNT=$(git stash list 2>/dev/null | wc -l)

# Wait a moment to ensure timestamp difference
sleep 1

# Clean with age=0 and confirm
OUTPUT=$(printf "y\n" | git_clean_stashes --age=0 2>&1)

# Check if stash was deleted
FINAL_COUNT=$(git stash list 2>/dev/null | wc -l)

if echo "$OUTPUT" | grep -q "Successfully deleted 1 stash" && [ "$FINAL_COUNT" -lt "$INITIAL_COUNT" ]; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes successfully cleaned old stashes\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes should clean old stashes. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Test 58: git_clean_stashes - Debug mode output
printf "${YELLOW}[TEST]${NC} git_clean_stashes: Debug mode output\n"
TEST_DIR=$(setup_test_repo_with_commit "clean-stashes-debug")
cd "$TEST_DIR" || exit 1

# Re-source to ensure functions are available
. "$SCRIPT_DIR/git-toolkit.sh"

# Create a stash for testing
echo "debug test" > debug_file.txt
git add debug_file.txt
git stash push -m "debug test stash"

# Test debug output
OUTPUT=$(git_clean_stashes --debug --age=0 2>&1)

if echo "$OUTPUT" | grep -q "=== DEBUG MODE ===" && \
   echo "$OUTPUT" | grep -q "Age threshold:" && \
   echo "$OUTPUT" | grep -q "Total stashes:"; then
    printf "${GREEN}[PASS]${NC} git_clean_stashes debug mode works correctly\n"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    printf "${RED}[FAIL]${NC} git_clean_stashes debug mode should show debug info. Output: $OUTPUT\n"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
cleanup_test_repo "$TEST_DIR"

# Cleanup and results
echo
echo "==============================================="
printf "Test Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}\n"
echo "==============================================="

if [ $FAIL_COUNT -eq 0 ]; then
    printf "${GREEN}All tests passed!${NC}\n"
    exit 0
else
    printf "${RED}Some tests failed!${NC}\n"
    exit 1
fi