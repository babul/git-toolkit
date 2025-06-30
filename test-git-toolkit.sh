#!/usr/bin/env bash

set -e

# POSIX-compliant: Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
    rm -rf test-*-$$ 2>/dev/null || true
    # Also clean up any orphaned test directories from previous runs
    # shellcheck disable=SC2038,SC2086,SC2317
    find . -maxdepth 1 -name "test-*-[0-9]*" -type d -exec rm -rf {} + 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup_test_dirs EXIT INT TERM

echo -e "${YELLOW}[TEST]${NC} Starting git-toolkit.sh test suite..."
echo

echo "=========================================="
echo "TESTING: Cross-platform compatibility"
echo "=========================================="

# Test 1: Cross-platform shell features
echo -e "${YELLOW}[TEST]${NC} Cross-platform: Shell feature compatibility"
TEST_DIR="$SCRIPT_DIR/test-compat-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

# Test that our utility functions work
echo "test" > file1.txt
git add file1.txt
git commit -m "Test commit" > /dev/null 2>&1

# Test validation functions
COMPAT_PASS=0
COMPAT_FAIL=0

if _git_validate_repo; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    echo -e "${RED}[FAIL]${NC} _git_validate_repo function failed"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

if _git_validate_commits; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    echo -e "${RED}[FAIL]${NC} _git_validate_commits function failed"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

if _git_get_current_branch > /dev/null; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    echo -e "${RED}[FAIL]${NC} _git_get_current_branch function failed"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

if _git_format_timestamp > /dev/null; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    echo -e "${RED}[FAIL]${NC} _git_format_timestamp function failed"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi

echo -e "Test confirmation function (simulate 'n' response)"
if echo "n" | _git_confirm_action "Test prompt"; then
    echo -e "${RED}[FAIL]${NC} _git_confirm_action should have returned false for 'n'"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
else
    COMPAT_PASS=$((COMPAT_PASS + 1))
fi
echo -e

echo -e "Test confirmation function (simulate 'y' response)"
if echo "y" | _git_confirm_action "Test prompt"; then
    COMPAT_PASS=$((COMPAT_PASS + 1))
else
    echo -e "${RED}[FAIL]${NC} _git_confirm_action should have returned true for 'y'"
    COMPAT_FAIL=$((COMPAT_FAIL + 1))
fi
echo -e

if [ $COMPAT_FAIL -eq 0 ]; then
    echo -e "${GREEN}[PASS]${NC} All cross-platform utility functions work correctly ($COMPAT_PASS/6)"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Cross-platform compatibility issues found ($COMPAT_FAIL failures)"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 2: Cross-platform shell syntax
echo -e "${YELLOW}[TEST]${NC} Cross-platform: Shell syntax compatibility"
# Test that we're not using bash-specific features that break in other shells
if bash -n "$SCRIPT_DIR/git-toolkit.sh" 2>/dev/null; then
    echo -e "${GREEN}[PASS]${NC} Script syntax is valid in bash"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Script syntax issues detected in bash"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo
echo "=========================================="
echo "TESTING: git-undo function"
echo "=========================================="

# Test 3: Not in git repository
echo -e "${YELLOW}[TEST]${NC} git-undo: Not in git repository"
TEST_DIR="$SCRIPT_DIR/test-nogit-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-undo 2>&1) && echo "$output" | grep -qE "Error: Not a git repository|Error: Repository has no commits"; then
    echo -e "${GREEN}[PASS]${NC} Correctly detected not in git repository"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Should have detected not in git repository. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 4: Initial commit protection
echo -e "${YELLOW}[TEST]${NC} git-undo: Initial commit protection"
TEST_DIR="$SCRIPT_DIR/test-initial-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if ! output=$(git-undo 2>&1) && echo "$output" | grep -q "Error: Cannot undo the initial commit"; then
    echo -e "${GREEN}[PASS]${NC} Correctly prevented undoing initial commit"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Should have prevented undoing initial commit. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 5: Dirty working directory
echo -e "${YELLOW}[TEST]${NC} git-undo: Dirty working directory"
TEST_DIR="$SCRIPT_DIR/test-dirty-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

echo "dirty" > file3.txt  # Uncommitted change

if ! output=$(git-undo 2>&1) && echo "$output" | grep -q "Error: Working directory is not clean"; then
    echo -e "${GREEN}[PASS]${NC} Correctly detected dirty working directory"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} Should have detected dirty working directory. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 6: Cancel undo operation
echo -e "${YELLOW}[TEST]${NC} git-undo: Cancel undo operation"
TEST_DIR="$SCRIPT_DIR/test-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

if echo "n" | git-undo 2>&1 | grep -q "Undo cancelled"; then
    if [ "$(git rev-list --count HEAD)" -eq 2 ]; then
        echo -e "${GREEN}[PASS]${NC} Cancel operation works correctly"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Commit was undone despite cancellation"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} Cancel operation failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 7: Normal undo operation
echo -e "${YELLOW}[TEST]${NC} git-undo: Normal undo operation"
TEST_DIR="$SCRIPT_DIR/test-normal-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit to undo" > /dev/null 2>&1

commit_hash=$(git rev-parse HEAD)

# Run undo and capture output for debugging
output=$(echo "y" | git-undo 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Check if commit was undone
    if [ "$(git rev-list --count HEAD)" -eq 1 ]; then
        echo -e "${GREEN}[PASS]${NC} Commit was successfully undone"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Commit was not undone"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if stash was created
    if git stash list | grep -q "Second commit to undo"; then
        echo -e "${GREEN}[PASS]${NC} Stash was created with correct message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Stash was not created or has wrong message"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if metadata was stored in stash
    if git stash list -n 1 | grep -q "Second commit to undo"; then
        stash_metadata=$(git show "stash@{0}":_undo_metadata_temp.txt 2>/dev/null || echo "")
        if [ -n "$stash_metadata" ] && echo "$stash_metadata" | grep -q "$commit_hash" && echo "$stash_metadata" | grep -q "Second commit to undo"; then
            echo -e "${GREEN}[PASS]${NC} Metadata was stored in stash with correct content"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo -e "${RED}[FAIL]${NC} Metadata was not found in stash or missing expected content"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo -e "${RED}[FAIL]${NC} Stash does not contain expected commit message"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} Undo operation failed with exit code $exit_code"
    echo -e "${YELLOW}[DEBUG]${NC} Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 8: Special characters in commit
echo -e "${YELLOW}[TEST]${NC} git-undo: Special characters in commit"
TEST_DIR="$SCRIPT_DIR/test-special-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "First commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "[sc-123] fix: handle special chars (test) & more [brackets]" > /dev/null 2>&1

if echo "y" | git-undo > /dev/null 2>&1; then
    if git stash list | grep -F "[sc-123] fix: handle special chars (test) & more [brackets]"; then
        echo -e "${GREEN}[PASS]${NC} Handled special characters in commit message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Failed to handle special characters in commit message"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} Undo with special characters failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 9: Multiple undos in sequence
echo -e "${YELLOW}[TEST]${NC} git-undo: Multiple undos in sequence"
TEST_DIR="$SCRIPT_DIR/test-multiple-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

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
if echo "y" | git-undo > /dev/null 2>&1; then
    # Second undo
    if echo "y" | git-undo > /dev/null 2>&1; then
        if [ "$(git rev-list --count HEAD)" -eq 1 ] && [ "$(git stash list | wc -l)" -eq 2 ]; then
            echo -e "${GREEN}[PASS]${NC} Multiple undos work correctly"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo -e "${RED}[FAIL]${NC} Multiple undos failed - wrong commit count or stash count"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo -e "${RED}[FAIL]${NC} Second undo failed"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} First undo failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 10: Comprehensive metadata preservation
echo -e "${YELLOW}[TEST]${NC} git-undo: Comprehensive metadata preservation"
TEST_DIR="$SCRIPT_DIR/test-metadata-comprehensive-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

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

if echo "y" | git-undo > /dev/null 2>&1; then
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
                        echo -e "${GREEN}[PASS]${NC} Comprehensive metadata preservation works"
                        PASS_COUNT=$((PASS_COUNT + 1))
                    else
                        echo -e "${RED}[FAIL]${NC} Unicode characters not preserved in metadata"
                        FAIL_COUNT=$((FAIL_COUNT + 1))
                    fi
                else
                    echo -e "${RED}[FAIL]${NC} Special characters not preserved in metadata"
                    FAIL_COUNT=$((FAIL_COUNT + 1))
                fi
            else
                echo -e "${RED}[FAIL]${NC} Full commit message not preserved in metadata"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        else
            echo -e "${RED}[FAIL]${NC} Metadata file not found in stash"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo -e "${RED}[FAIL]${NC} Stash not created for metadata test"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} Undo failed for metadata test"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git-stash function"
echo "=========================================="

# Test 11: git-stash - Not in git repository
echo -e "${YELLOW}[TEST]${NC} git-stash: Not in git repository"
TEST_DIR="$SCRIPT_DIR/test-stash-nogit-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-stash 2>&1) && echo "$output" | grep -qE "Error: Not a git repository|Error: Repository has no commits"; then
    echo -e "${GREEN}[PASS]${NC} git-stash correctly detected not in git repository"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-stash should have detected not in git repository. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 12: git-stash - Repository with no commits
echo -e "${YELLOW}[TEST]${NC} git-stash: Repository with no commits"
TEST_DIR="$SCRIPT_DIR/test-stash-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-stash 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    echo -e "${GREEN}[PASS]${NC} git-stash correctly detected repository with no commits"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-stash should have detected repository with no commits. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 13: git-stash - Clean working directory
echo -e "${YELLOW}[TEST]${NC} git-stash: Clean working directory"
TEST_DIR="$SCRIPT_DIR/test-stash-clean-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if output=$(git-stash 2>&1) && echo "$output" | grep -q "No changes to stash (working directory is clean)"; then
    echo -e "${GREEN}[PASS]${NC} git-stash correctly detected clean working directory"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-stash should have detected clean working directory. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 14: git-stash - Cancel stash operation
echo -e "${YELLOW}[TEST]${NC} git-stash: Cancel stash operation"
TEST_DIR="$SCRIPT_DIR/test-stash-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "test" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "new file" > file2.txt

if echo "n" | git-stash 2>&1 | grep -q "Stash cancelled"; then
    # Check that files are still present
    if [ -f file2.txt ] && [ "$(cat file1.txt)" = "modified" ]; then
        echo -e "${GREEN}[PASS]${NC} git-stash cancel operation works correctly"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Files were stashed despite cancellation"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-stash cancel operation failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 15: git-stash - Normal stash operation with modified files
echo -e "${YELLOW}[TEST]${NC} git-stash: Normal stash with modified files"
TEST_DIR="$SCRIPT_DIR/test-stash-modified-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt

output=$(echo "y" | git-stash 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Check if working directory is clean (file1.txt should be back to original content)
    if git diff-index --quiet HEAD; then
        echo -e "${GREEN}[PASS]${NC} git-stash cleaned working directory"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Working directory not clean after stash"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if stash was created
    if git stash list | grep -q "clean branch"; then
        echo -e "${GREEN}[PASS]${NC} git-stash created stash with correct message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-stash did not create stash or has wrong message"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-stash operation failed with exit code $exit_code"
    echo -e "${YELLOW}[DEBUG]${NC} Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 16: git-stash - Stash with untracked files
echo -e "${YELLOW}[TEST]${NC} git-stash: Stash with untracked files"
TEST_DIR="$SCRIPT_DIR/test-stash-untracked-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "untracked" > untracked.txt

if echo "y" | git-stash > /dev/null 2>&1; then
    # Check if both tracked and untracked files are gone
    if [ "$(cat file1.txt)" = "initial" ] && [ ! -f untracked.txt ]; then
        echo -e "${GREEN}[PASS]${NC} git-stash handled both modified and untracked files"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-stash did not properly handle all file types"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify untracked file is in stash
    if git stash show --include-untracked "stash@{0}" --name-only | grep -q "untracked.txt"; then
        echo -e "${GREEN}[PASS]${NC} git-stash included untracked files in stash"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-stash did not include untracked files in stash"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-stash with untracked files failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 17: git-stash - Stash with staged files
echo -e "${YELLOW}[TEST]${NC} git-stash: Stash with staged files"
TEST_DIR="$SCRIPT_DIR/test-stash-staged-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "modified" > file1.txt
echo "staged" > staged.txt
git add staged.txt

if echo "y" | git-stash > /dev/null 2>&1; then
    # Check if staged files are gone and index is clean
    if git diff-index --quiet --cached HEAD && [ ! -f staged.txt ]; then
        echo -e "${GREEN}[PASS]${NC} git-stash handled staged files correctly"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-stash did not properly handle staged files"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-stash with staged files failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 18: git-stash - Complex scenario with all file types
echo -e "${YELLOW}[TEST]${NC} git-stash: Complex scenario with all file types"
TEST_DIR="$SCRIPT_DIR/test-stash-complex-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create complex scenario: modified, staged, and untracked files
echo "modified content" > file1.txt  # Modified file
echo "staged content" > staged.txt   # New staged file
git add staged.txt
echo "untracked content" > untracked.txt  # Untracked file

if echo "y" | git-stash > /dev/null 2>&1; then
    # Verify working directory is completely clean
    if git diff-index --quiet HEAD && git diff-index --quiet --cached HEAD && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${GREEN}[PASS]${NC} git-stash completely cleaned complex working directory"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-stash did not completely clean working directory"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify all files can be restored
    if git stash apply "stash@{0}" > /dev/null 2>&1; then
        if [ "$(cat file1.txt)" = "modified content" ] && [ "$(cat staged.txt)" = "staged content" ] && [ "$(cat untracked.txt)" = "untracked content" ]; then
            echo -e "${GREEN}[PASS]${NC} git-stash preserved all file types correctly"
            PASS_COUNT=$((PASS_COUNT + 1))
        else
            echo -e "${RED}[FAIL]${NC} git-stash did not preserve all file contents correctly"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo -e "${RED}[FAIL]${NC} Could not restore stashed files"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-stash complex scenario failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git-clean-branches function"
echo "=========================================="

# Test 19: git-clean-branches - Not in git repository
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: Not in git repository"
TEST_DIR="/tmp/test-clean-nogit-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-clean-branches 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    echo -e "${GREEN}[PASS]${NC} git-clean-branches correctly detected not in git repository"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches should have detected not in git repository. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 20: git-clean-branches - Repository with no commits
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: Repository with no commits"
TEST_DIR="$SCRIPT_DIR/test-clean-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-clean-branches 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    echo -e "${GREEN}[PASS]${NC} git-clean-branches correctly detected repository with no commits"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches should have detected repository with no commits. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 21: git-clean-branches - No branches to clean
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: No branches to clean"
TEST_DIR="$SCRIPT_DIR/test-clean-none-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if output=$(git-clean-branches 2>&1) && echo "$output" | grep -q "No branches to clean up"; then
    echo -e "${GREEN}[PASS]${NC} git-clean-branches correctly detected no branches to clean"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches should have detected no branches to clean. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 22: git-clean-branches - Cancel operation
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: Cancel operation"
TEST_DIR="$SCRIPT_DIR/test-clean-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create and merge a feature branch
git checkout -b feature-branch > /dev/null 2>&1
echo "feature" > feature.txt
git add feature.txt
git commit -m "Add feature" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge feature-branch > /dev/null 2>&1

if echo "n" | git-clean-branches 2>&1 | grep -q "Branch cleanup cancelled"; then
    # Verify the merged branch still exists
    if git branch | grep -q "feature-branch"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches cancel operation works correctly"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} Branch was deleted despite cancellation"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches cancel operation failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 23: git-clean-branches - Clean merged branches
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: Clean merged branches"
TEST_DIR="$SCRIPT_DIR/test-clean-merged-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create multiple feature branches and merge them
git checkout -b feature-1 > /dev/null 2>&1
echo "feature1" > feature1.txt
git add feature1.txt
git commit -m "Add feature 1" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge feature-1 > /dev/null 2>&1

git checkout -b feature-2 > /dev/null 2>&1
echo "feature2" > feature2.txt
git add feature2.txt
git commit -m "Add feature 2" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge feature-2 > /dev/null 2>&1

if echo "y" | git-clean-branches > /dev/null 2>&1; then
    # Verify merged branches are deleted
    if ! git branch | grep -qE "feature-[12]"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches successfully cleaned merged branches"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-clean-branches did not clean all merged branches"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify main branch still exists
    if git branch | grep -q "main"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches preserved main branch"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-clean-branches deleted main branch"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches failed to execute"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 24: git-clean-branches - Protect current branch
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: Protect current branch"
TEST_DIR="$SCRIPT_DIR/test-clean-protect-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create and switch to a feature branch, then create another branch from main
git checkout -b current-feature > /dev/null 2>&1
echo "current" > current.txt
git add current.txt
git commit -m "Current feature work" > /dev/null 2>&1

git checkout main > /dev/null 2>&1
git checkout -b other-feature > /dev/null 2>&1
echo "other" > other.txt
git add other.txt
git commit -m "Other feature" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge other-feature > /dev/null 2>&1

# Switch back to current-feature
git checkout current-feature > /dev/null 2>&1

# Run cleanup - should not delete current-feature even if it appears merged
if echo "y" | git-clean-branches > /dev/null 2>&1; then
    # Verify current branch is protected
    if git branch | grep -q "current-feature"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches protected current branch"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-clean-branches deleted current branch"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches failed to execute"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 25: git-clean-branches - Handle unmerged branches
echo -e "${YELLOW}[TEST]${NC} git-clean-branches: Handle unmerged branches"
TEST_DIR="$SCRIPT_DIR/test-clean-unmerged-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

# Create an unmerged feature branch
git checkout -b unmerged-feature > /dev/null 2>&1
echo "unmerged work" > unmerged.txt
git add unmerged.txt
git commit -m "Unmerged feature work" > /dev/null 2>&1
git checkout main > /dev/null 2>&1

# Create a merged branch for comparison
git checkout -b merged-feature > /dev/null 2>&1
echo "merged work" > merged.txt
git add merged.txt
git commit -m "Merged feature work" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge merged-feature > /dev/null 2>&1

output=$(echo "y" | git-clean-branches 2>&1)
exit_code=$?

if [ $exit_code -eq 0 ]; then
    # Verify unmerged branch still exists
    if git branch | grep -q "unmerged-feature"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches protected unmerged branch"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-clean-branches deleted unmerged branch"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify merged branch was deleted (check the output since it's more reliable)
    if echo "$output" | grep -q "✓ Deleted branch: merged-feature"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches deleted merged branch"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-clean-branches did not delete merged branch"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Check if unmerged branch is properly handled (not in delete list)
    if ! echo "$output" | grep -q "unmerged-feature"; then
        echo -e "${GREEN}[PASS]${NC} git-clean-branches properly handled unmerged branch"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-clean-branches did not handle unmerged branch correctly"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-clean-branches failed to execute. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

echo
echo "=========================================="
echo "TESTING: git-redo function"
echo "=========================================="

# Test 26: git-redo - Not in git repository
echo -e "${YELLOW}[TEST]${NC} git-redo: Not in git repository"
TEST_DIR="/tmp/test-redo-nogit-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-redo 2>&1) && echo "$output" | grep -q "Error: Not a git repository"; then
    echo -e "${GREEN}[PASS]${NC} git-redo correctly detected not in git repository"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-redo should have detected not in git repository. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 27: git-redo - Repository with no commits
echo -e "${YELLOW}[TEST]${NC} git-redo: Repository with no commits"
TEST_DIR="$SCRIPT_DIR/test-redo-nocommits-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

if ! output=$(git-redo 2>&1) && echo "$output" | grep -q "Error: Repository has no commits"; then
    echo -e "${GREEN}[PASS]${NC} git-redo correctly detected repository with no commits"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-redo should have detected repository with no commits. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 28: git-redo - No undo stashes available
echo -e "${YELLOW}[TEST]${NC} git-redo: No undo stashes available"
TEST_DIR="$SCRIPT_DIR/test-redo-nostashes-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

if output=$(git-redo 2>&1) && echo "$output" | grep -q "No undo stashes found to redo"; then
    echo -e "${GREEN}[PASS]${NC} git-redo correctly detected no undo stashes"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-redo should have detected no undo stashes. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 29: git-redo - Dirty working directory
echo -e "${YELLOW}[TEST]${NC} git-redo: Dirty working directory"
TEST_DIR="$SCRIPT_DIR/test-redo-dirty-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

# Undo the commit first
echo "y" | git-undo > /dev/null 2>&1

# Make working directory dirty
echo "dirty" > file3.txt

if ! output=$(git-redo 2>&1) && echo "$output" | grep -q "Error: Working directory is not clean"; then
    echo -e "${GREEN}[PASS]${NC} git-redo correctly detected dirty working directory"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-redo should have detected dirty working directory. Output: $output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 30: git-redo - Cancel redo operation
echo -e "${YELLOW}[TEST]${NC} git-redo: Cancel redo operation"
TEST_DIR="$SCRIPT_DIR/test-redo-cancel-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "second" > file2.txt
git add file2.txt
git commit -m "Second commit" > /dev/null 2>&1

# Undo the commit first
echo "y" | git-undo > /dev/null 2>&1

# Test cancellation at selection stage
if echo -e "q" | git-redo 2>&1 | grep -q "Redo cancelled"; then
    echo -e "${GREEN}[PASS]${NC} git-redo cancel at selection works correctly"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-redo cancel at selection failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Test cancellation at confirmation stage
if echo -e "1\nn" | git-redo 2>&1 | grep -q "Redo cancelled"; then
    echo -e "${GREEN}[PASS]${NC} git-redo cancel at confirmation works correctly"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} git-redo cancel at confirmation failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Test 31: git-redo - Successful redo operation
echo -e "${YELLOW}[TEST]${NC} git-redo: Successful redo operation"
TEST_DIR="$SCRIPT_DIR/test-redo-success-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR" || exit 1
git init > /dev/null 2>&1
git config user.name "Test User"
git config user.email "test@example.com"
source "$SCRIPT_DIR/git-toolkit.sh"

echo "initial" > file1.txt
git add file1.txt
git commit -m "Initial commit" > /dev/null 2>&1

echo "second content" > file2.txt
git add file2.txt
git commit -m "Second commit to undo and redo" > /dev/null 2>&1

# Undo the commit first
echo "y" | git-undo > /dev/null 2>&1

# Verify file is gone after undo
if [ ! -f file2.txt ]; then
    echo -e "${GREEN}[PASS]${NC} File was removed after undo"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo -e "${RED}[FAIL]${NC} File was not removed after undo"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# Now redo the commit
if echo -e "1\ny" | git-redo > /dev/null 2>&1; then
    # Verify file is back after redo
    if [ -f file2.txt ] && [ "$(cat file2.txt)" = "second content" ]; then
        echo -e "${GREEN}[PASS]${NC} git-redo successfully restored changes"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-redo did not restore changes correctly"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    # Verify working directory has changes ready to commit
    if ! git diff-index --quiet HEAD; then
        echo -e "${GREEN}[PASS]${NC} git-redo left changes in working directory"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}[FAIL]${NC} git-redo did not restore changes to working directory"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo -e "${RED}[FAIL]${NC} git-redo operation failed"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi
# shellcheck disable=SC2164
cd "$SCRIPT_DIR"
rm -rf "$TEST_DIR"

# Cleanup and results
echo
echo "==============================================="
echo -e "Test Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}"
echo "==============================================="

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi