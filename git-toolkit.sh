#!/usr/bin/env bash

# Cross-platform compatibility
# Note: Removed 'set -e' to maintain compatibility with terminal environments like Warp
#set -e

# Shared utility functions
_git_validate_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "✗ Error: Not a git repository"
        return 1
    fi
    return 0
}

_git_validate_commits() {
    if ! git rev-parse --verify HEAD > /dev/null 2>&1; then
        echo "✗ Error: Repository has no commits"
        return 1
    fi
    return 0
}

_git_check_clean_working_dir() {
    if ! git diff-index --quiet HEAD 2>/dev/null || \
       ! git diff-index --quiet --cached HEAD 2>/dev/null || \
       test -n "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "✗ Error: Working directory is not clean. Please commit or stash your changes first."
        return 1
    fi
    return 0
}

_git_get_current_branch() {
    git branch --show-current 2>/dev/null || echo "main"
}

_git_confirm_action() {
    local prompt="$1"
    local response
    printf "%s (y/N): " "$prompt"
    read -r response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

_git_format_timestamp() {
    date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S'
}

git-undo() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1

    if [ "$(git rev-list --count HEAD 2>/dev/null)" -eq 1 ]; then
        echo "✗ Error: Cannot undo the initial commit"
        return 1
    fi
    
    _git_check_clean_working_dir || return 1

    local LAST_COMMIT_MSG LAST_COMMIT_SUBJECT COMMIT_HASH COMMIT_AUTHOR COMMIT_DATE
    LAST_COMMIT_MSG=$(git log -1 --pretty=format:"%B" 2>/dev/null)
    LAST_COMMIT_SUBJECT=$(git log -1 --pretty=format:"%s" 2>/dev/null)
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
    COMMIT_AUTHOR=$(git log -1 --pretty=format:"%an <%ae>" 2>/dev/null)
    COMMIT_DATE=$(git log -1 --pretty=format:"%ai" 2>/dev/null)
    
    echo "About to undo commit:"
    echo "  Hash: $COMMIT_HASH"
    echo "  Message: $LAST_COMMIT_SUBJECT"
    echo "  Author: $COMMIT_AUTHOR"
    echo "  Date: $COMMIT_DATE"
    echo

    if ! _git_confirm_action "Proceed with undo?"; then
        echo "✗ Undo cancelled."
        return 0
    fi

    local TIMESTAMP FULL_COMMIT_HASH
    TIMESTAMP=$(_git_format_timestamp)
    FULL_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
    
    local STASH_MSG="undo - $TIMESTAMP - $LAST_COMMIT_SUBJECT"

    git reset HEAD~1
    
    # Create temporary metadata file in working directory
    local temp_metadata="_undo_metadata_temp.txt"
    {
        echo "## Undo: $TIMESTAMP"
        echo ""
        echo "**Commit Hash:** $FULL_COMMIT_HASH"
        echo "**Stash:** undo - $TIMESTAMP - $LAST_COMMIT_SUBJECT"
        echo ""
        echo "### Original Commit Message:"
        echo '```'
        echo "$LAST_COMMIT_MSG"
        echo '```'
        echo ""
        echo "---"
    } > "$temp_metadata"
    
    # Stage the metadata file and create stash with all changes
    git add "$temp_metadata"
    git add -A
    
    # Create stash - this should now include the metadata file and all reset changes
    if ! git stash push -m "$STASH_MSG"; then
        echo "✗ Error: Failed to create stash with metadata"
        rm -f "$temp_metadata"
        return 1
    fi
    
    local STASH_NAME
    STASH_NAME=$(git stash list | grep -F "$STASH_MSG" | head -1 | cut -d: -f1)
    
    # Verify stash was created successfully
    if [ -z "$STASH_NAME" ]; then
        echo "✗ Error: Stash was not created successfully"
        rm -f "$temp_metadata"
        return 1
    fi
    
    # Verify metadata file is actually in the stash before cleanup
    if ! git stash show --name-only "$STASH_NAME" | grep -q "$temp_metadata"; then
        echo "✗ Error: Metadata file was not saved in stash"
        rm -f "$temp_metadata"
        return 1
    fi
    
    # Safe to remove temp file now that we've verified it's in the stash
    rm -f "$temp_metadata"
    echo "✓ Commit undone and changes stashed"
}

git-stash() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1

    # Check if there's anything to stash
    if git diff-index --quiet HEAD 2>/dev/null && \
       git diff-index --quiet --cached HEAD 2>/dev/null && \
       test -z "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "✓ No changes to stash (working directory is clean)"
        return 0
    fi

    local TIMESTAMP STASH_MSG
    TIMESTAMP=$(_git_format_timestamp)
    STASH_MSG="clean branch - $TIMESTAMP"

    echo "Stashing all changes (including untracked files)..."
    
    # Show what will be stashed
    echo
    echo "Files to be stashed:"
    if ! git diff-index --quiet HEAD 2>/dev/null; then
        echo "  Modified files:"
        git diff --name-only 2>/dev/null
    fi
    if ! git diff-index --quiet --cached HEAD 2>/dev/null; then
        echo "  Staged files:"
        git diff --cached --name-only 2>/dev/null
    fi
    if test -n "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "  Untracked files:"
        git ls-files --others --exclude-standard 2>/dev/null
    fi
    echo

    if ! _git_confirm_action "Proceed with stashing all changes?"; then
        echo "✗ Stash cancelled."
        return 0
    fi

    # Stash everything including untracked files
    if ! git stash push --include-untracked -m "$STASH_MSG" 2>/dev/null; then
        echo "✗ Error: Failed to create stash"
        return 1
    fi

    local STASH_NAME
    STASH_NAME=$(git stash list 2>/dev/null | grep -F "$STASH_MSG" | head -1 | cut -d: -f1)
    
    if test -z "$STASH_NAME"; then
        echo "✗ Error: Stash was not created successfully"
        return 1
    fi

    echo "✓ All changes stashed successfully!"
    echo "Working directory is now clean."
    echo
    echo "Changes saved in stash: $STASH_NAME (\"$STASH_MSG\")"
    echo "To restore: git stash apply $STASH_NAME"
}

git-clean-branches() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1

    # Get current branch name
    local CURRENT_BRANCH
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    # Collect branches to delete
    local MERGED_BRANCHES=""
    local GONE_BRANCHES=""
    
    # Get merged branches (safe to run since we already verified HEAD exists)
    # POSIX-compliant: Using sed instead of ${var//pattern/replace} for cross-platform compatibility
    MERGED_BRANCHES=$(git branch --merged 2>/dev/null | grep -vE "^\*|main|master|develop|${CURRENT_BRANCH}" | sed 's/^[ ]*//g' || true)
    
    # Get branches that are gone from remote
    GONE_BRANCHES=$(git branch -vv 2>/dev/null | grep ": gone]" | awk '{print $1}' | grep -vE "main|master|develop|${CURRENT_BRANCH}" || true)
    
    # Combine and deduplicate
    local ALL_BRANCHES
    ALL_BRANCHES=$(echo -e "$MERGED_BRANCHES\n$GONE_BRANCHES" | sort -u | grep -v '^$')
    
    if test -z "$ALL_BRANCHES"; then
        echo "✓ No branches to clean up"
        return 0
    fi
    
    echo "About to delete branches:"
    echo "$ALL_BRANCHES" | while read -r branch; do
        if test -n "$branch"; then
            local BRANCH_INFO
            BRANCH_INFO=$(git log --oneline -1 "$branch" 2>/dev/null || echo "No commits")
            local BRANCH_TYPE=""
            if echo "$MERGED_BRANCHES" | grep -q "^$branch$"; then
                BRANCH_TYPE="merged"
            fi
            if echo "$GONE_BRANCHES" | grep -q "^$branch$"; then
                if test -n "$BRANCH_TYPE"; then
                    BRANCH_TYPE="$BRANCH_TYPE, gone from remote"
                else
                    BRANCH_TYPE="gone from remote"
                fi
            fi
            echo "  Branch: $branch ($BRANCH_TYPE)"
            echo "  Last commit: $BRANCH_INFO"
        fi
    done
    echo
    
    if ! _git_confirm_action "Proceed with branch cleanup?"; then
        echo "✗ Branch cleanup cancelled."
        return 0
    fi
    
    local DELETE_COUNT=0
    local FAILED_COUNT=0
    
    echo "$ALL_BRANCHES" | while read -r branch; do
        if test -n "$branch"; then
            if git branch -d "$branch" > /dev/null 2>&1; then
                echo "✓ Deleted branch: $branch"
                DELETE_COUNT=$((DELETE_COUNT + 1))
            else
                # Try force delete for unmerged branches that are gone from remote
                if echo "$GONE_BRANCHES" | grep -q "^$branch$"; then
                    if git branch -D "$branch" > /dev/null 2>&1; then
                        echo "✓ Force deleted gone branch: $branch"
                        DELETE_COUNT=$((DELETE_COUNT + 1))
                    else
                        echo "✗ Failed to delete branch: $branch"
                        FAILED_COUNT=$((FAILED_COUNT + 1))
                    fi
                else
                    echo "✗ Failed to delete unmerged branch: $branch (use -D to force)"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                fi
            fi
        fi
    done
    
    echo
    echo "✓ Branch cleanup completed"
}

git-redo() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1

    # Check if working directory is clean
    if ! git diff-index --quiet HEAD 2>/dev/null || \
       ! git diff-index --quiet --cached HEAD 2>/dev/null || \
       test -n "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "✗ Error: Working directory is not clean. Please commit or stash your changes first."
        return 1
    fi

    # Get list of undo stashes (those created by git-undo)
    local UNDO_STASHES
    UNDO_STASHES=$(git stash list 2>/dev/null | grep "undo -" | head -10)
    
    if test -z "$UNDO_STASHES"; then
        echo "✓ No undo stashes found to redo"
        return 0
    fi

    echo "Available undo operations to redo:"
    echo
    
    local stash_number=1
    echo "$UNDO_STASHES" | while read -r stash_line; do
        if test -n "$stash_line"; then
            local stash_ref
            stash_ref=$(echo "$stash_line" | cut -d: -f1)
            local stash_msg
            # POSIX-compliant: Using sed instead of ${var#${var%%[![:space:]]*}} for cross-platform compatibility
            stash_msg=$(echo "$stash_line" | cut -d: -f3- | sed 's/^ *//')
            
            # Extract timestamp and commit message from stash message
            local timestamp commit_msg
            # POSIX-compliant: Using sed for regex extraction instead of bash parameter expansion
            # shellcheck disable=SC2001
            timestamp=$(echo "$stash_msg" | sed 's/undo - \([0-9-]* [0-9:]*\) - .*/\1/')
            # shellcheck disable=SC2001
            commit_msg=$(echo "$stash_msg" | sed 's/undo - [0-9-]* [0-9:]* - //')
            
            # Try to get metadata from the stash
            local metadata
            metadata=$(git stash show -p "$stash_ref" 2>/dev/null | grep -A 20 "## Undo:" | head -10 || echo "")
            
            printf "  %d. %s\n" "$stash_number" "$commit_msg"
            printf "     Undone: %s\n" "$timestamp"
            if test -n "$metadata"; then
                local original_hash
                # POSIX-compliant: Using sed for pattern extraction
                original_hash=$(echo "$metadata" | grep "Commit Hash:" | sed 's/.*Commit Hash:\*\* *//' | head -1)
                if test -n "$original_hash"; then
                    printf "     Original hash: %s\n" "$original_hash"
                fi
            fi
            printf "     Stash: %s\n" "$stash_ref"
            echo
            stash_number=$((stash_number + 1))
        fi
    done

    # Get user choice
    printf "Enter the number of the undo to redo (or 'q' to quit): "
    read -r choice
    
    if test "$choice" = "q" || test "$choice" = "Q"; then
        echo "✗ Redo cancelled."
        return 0
    fi

    # Validate choice is a number
    if ! echo "$choice" | grep -q "^[0-9]\+$"; then
        echo "✗ Error: Invalid selection. Please enter a number."
        return 1
    fi

    # Get the selected stash
    local selected_stash_line
    # POSIX-compliant: Using sed for line selection
    selected_stash_line=$(echo "$UNDO_STASHES" | sed -n "${choice}p")
    
    if test -z "$selected_stash_line"; then
        echo "✗ Error: Invalid selection. Please choose a valid number."
        return 1
    fi

    local selected_stash_ref
    selected_stash_ref=$(echo "$selected_stash_line" | cut -d: -f1)
    local selected_stash_msg
    # POSIX-compliant: Using sed instead of ${var#${var%%[![:space:]]*}} for cross-platform compatibility
    selected_stash_msg=$(echo "$selected_stash_line" | cut -d: -f3- | sed 's/^ *//')
    
    # Extract commit message for confirmation
    local selected_commit_msg
    # POSIX-compliant: Using sed for regex extraction instead of bash parameter expansion
    # shellcheck disable=SC2001
    selected_commit_msg=$(echo "$selected_stash_msg" | sed 's/undo - [0-9-]* [0-9:]* - //')

    echo "About to redo (restore) commit:"
    echo "  Commit: $selected_commit_msg"
    echo "  Stash: $selected_stash_ref"
    echo

    if ! _git_confirm_action "Proceed with redo?"; then
        echo "✗ Redo cancelled."
        return 0
    fi

    # Apply the stash
    if git stash apply "$selected_stash_ref" 2>/dev/null; then
        echo "✓ Redo completed successfully!"
        echo
        echo "The changes have been restored to your working directory."
        echo "You can now:"
        echo "  - Review the changes with: git diff"
        echo "  - Commit them again with: git commit"
        echo "  - Drop the stash with: git stash drop $selected_stash_ref"
        echo
        echo "Note: The stash has been preserved. Use 'git stash drop $selected_stash_ref' to remove it."
    else
        echo "✗ Error: Failed to apply stash. There may be conflicts."
        echo "You can manually resolve conflicts and try: git stash apply $selected_stash_ref"
        return 1
    fi
}
