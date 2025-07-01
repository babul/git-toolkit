#!/usr/bin/env bash

# Cross-platform compatibility
# Note: Removed 'set -e' to maintain compatibility with terminal environments like Warp
#set -e

# Shared constants
# Ensure pattern is properly set, work around readonly issues
# Debug: check the actual content and length
if [ ${#PROTECTED_BRANCHES_PATTERN} -eq 0 ]; then
    # Pattern is empty or unset, try to set it or use override
    if ! readonly PROTECTED_BRANCHES_PATTERN="^(main|master|develop)$" 2>/dev/null; then
        # Setting failed (probably readonly), use override
        PROTECTED_BRANCHES_PATTERN_OVERRIDE="^(main|master|develop)$"
    fi
else
    # Pattern has content, check if it's valid
    if [ "$PROTECTED_BRANCHES_PATTERN" = "" ] || [ "$PROTECTED_BRANCHES_PATTERN" = " " ]; then
        PROTECTED_BRANCHES_PATTERN_OVERRIDE="^(main|master|develop)$"
    fi
fi
if [ -z "$DATE_FORMAT" ] || [ "$DATE_FORMAT" = "" ]; then
    readonly DATE_FORMAT='%Y-%m-%d %H:%M:%S'
fi

# Shared utility functions
_git_get_protected_pattern() {
    if [ -n "$PROTECTED_BRANCHES_PATTERN_OVERRIDE" ]; then
        echo "$PROTECTED_BRANCHES_PATTERN_OVERRIDE"
    elif [ -n "$PROTECTED_BRANCHES_PATTERN" ] && [ ${#PROTECTED_BRANCHES_PATTERN} -gt 0 ]; then
        echo "$PROTECTED_BRANCHES_PATTERN"
    else
        # Fallback to default pattern if everything else fails
        echo "^(main|master|develop)$"
    fi
}

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
    local format="${DATE_FORMAT:-'%Y-%m-%d %H:%M:%S'}"
    date "+$format" 2>/dev/null
}

_git_validate_all() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1
    return 0
}

_git_get_uncommitted_status() {
    local show_details="$1"
    local modified_count=0
    local staged_count=0
    local untracked_count=0
    local total_count=0
    
    # Get staged files
    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null)
    if [ -n "$staged_files" ]; then
        staged_count=$(echo "$staged_files" | wc -l)
        total_count=$((total_count + staged_count))
    fi
    
    # Get modified files
    local modified_files
    modified_files=$(git diff --name-only 2>/dev/null)
    if [ -n "$modified_files" ]; then
        modified_count=$(echo "$modified_files" | wc -l)
        total_count=$((total_count + modified_count))
    fi
    
    # Get untracked files
    local untracked_files
    untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null)
    if [ -n "$untracked_files" ]; then
        untracked_count=$(echo "$untracked_files" | wc -l)
        total_count=$((total_count + untracked_count))
    fi
    
    if [ "$total_count" -eq 0 ]; then
        echo "Git branch is clean"
        return 0
    fi
    
    if [ "$show_details" = "true" ]; then
        echo "Uncommitted changes:"
        local sections_shown=0
        
        if [ "$staged_count" -gt 0 ]; then
            [ "$sections_shown" -gt 0 ] && echo
            printf "  \033[32mChanges to be committed:\033[0m\n"
            echo "$staged_files" | sed 's/^/    /' | while read -r file; do
                printf "    \033[32mmodified:   \033[32m%s\033[0m\n" "$file"
            done
            sections_shown=$((sections_shown + 1))
        fi
        if [ "$modified_count" -gt 0 ]; then
            [ "$sections_shown" -gt 0 ] && echo
            printf "  \033[31mChanges not staged for commit:\033[0m\n"
            echo "$modified_files" | sed 's/^/    /' | while read -r file; do
                printf "    \033[31mmodified:   \033[31m%s\033[0m\n" "$file"
            done
            sections_shown=$((sections_shown + 1))
        fi
        if [ "$untracked_count" -gt 0 ]; then
            [ "$sections_shown" -gt 0 ] && echo
            printf "  \033[31mUntracked files:\033[0m\n"
            echo "$untracked_files" | sed 's/^/    /' | while read -r file; do
                printf "    \033[31m%s\033[0m\n" "$file"
            done
            sections_shown=$((sections_shown + 1))
        fi
    else
        echo "$total_count uncommitted files"
    fi
}

git_undo() {
    local DEBUG_MODE=""
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git_undo [--debug]"
                echo "  --debug Show debug information"
                return 1
                ;;
            *)
                echo "✗ Error: Unexpected argument '$1'"
                echo "Usage: git_undo [--debug]"
                return 1
                ;;
        esac
    done
    
    _git_validate_all || return 1

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
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Current HEAD: $(git rev-parse HEAD 2>/dev/null)"
        echo "Working directory clean: $(git diff-index --quiet HEAD 2>/dev/null && echo "true" || echo "false")"
        echo "Commit count: $(git rev-list --count HEAD 2>/dev/null)"
        echo "=================="
    fi
    
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

    local TIMESTAMP FULL_COMMIT_HASH CURRENT_BRANCH
    TIMESTAMP=$(_git_format_timestamp)
    FULL_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    local STASH_MSG="undo $CURRENT_BRANCH - $TIMESTAMP - $LAST_COMMIT_SUBJECT"

    git reset HEAD~1
    
    # Create temporary metadata file in working directory
    local temp_metadata="_undo_metadata_temp.txt"
    {
        echo "## Undo: $TIMESTAMP"
        echo ""
        echo "**Commit Hash:** $FULL_COMMIT_HASH"
        echo "**Stash:** undo $CURRENT_BRANCH - $TIMESTAMP - $LAST_COMMIT_SUBJECT"
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
    echo ""
    echo "✓ Commit undone and changes stashed to $STASH_NAME"
}

git_stash() {
    local DEBUG_MODE=""
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git_stash [--debug]"
                echo "  --debug Show debug information"
                return 1
                ;;
            *)
                echo "✗ Error: Unexpected argument '$1'"
                echo "Usage: git_stash [--debug]"
                return 1
                ;;
        esac
    done
    
    _git_validate_all || return 1

    # Check if there's anything to stash (including untracked files)
    if git diff-index --quiet HEAD 2>/dev/null && \
       git diff-index --quiet --cached HEAD 2>/dev/null && \
       test -z "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "✓ No changes to stash (working directory is clean)"
        return 0
    fi

    local TIMESTAMP STASH_MSG CURRENT_BRANCH
    TIMESTAMP=$(_git_format_timestamp)
    CURRENT_BRANCH=$(_git_get_current_branch)
    STASH_MSG="stash $CURRENT_BRANCH - $TIMESTAMP"
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Current branch: $CURRENT_BRANCH"
        echo "Modified files: $(git diff --name-only 2>/dev/null | wc -l)"
        echo "Staged files: $(git diff --cached --name-only 2>/dev/null | wc -l)"
        echo "Untracked files: $(git ls-files --others --exclude-standard 2>/dev/null | wc -l)"
        echo "Stash message: $STASH_MSG"
        echo "=================="
    fi

    echo "Stashing all changes (including untracked files)..."
    
    # Show what will be stashed
    echo
    echo "Files to be stashed:"
    local sections_shown=0
    
    # Show staged files (green)
    local staged_files
    staged_files=$(git diff --cached --name-only 2>/dev/null)
    if [ -n "$staged_files" ]; then
        [ "$sections_shown" -gt 0 ] && echo
        printf "  \033[32mChanges to be committed:\033[0m\n"
        echo "$staged_files" | while read -r file; do
            printf "    \033[32mmodified:   \033[32m%s\033[0m\n" "$file"
        done
        sections_shown=$((sections_shown + 1))
    fi
    
    # Show modified files (red)
    local modified_files
    modified_files=$(git diff --name-only 2>/dev/null)
    if [ -n "$modified_files" ]; then
        [ "$sections_shown" -gt 0 ] && echo
        printf "  \033[31mChanges not staged for commit:\033[0m\n"
        echo "$modified_files" | while read -r file; do
            printf "    \033[31mmodified:   \033[31m%s\033[0m\n" "$file"
        done
        sections_shown=$((sections_shown + 1))
    fi
    
    # Show untracked files (red)
    local untracked_files
    untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null)
    if [ -n "$untracked_files" ]; then
        [ "$sections_shown" -gt 0 ] && echo
        printf "  \033[31mUntracked files:\033[0m\n"
        echo "$untracked_files" | while read -r file; do
            printf "    \033[31m%s\033[0m\n" "$file"
        done
        sections_shown=$((sections_shown + 1))
    fi
    echo

    if ! _git_confirm_action "Proceed with stashing all changes?"; then
        echo "✗ Stash cancelled."
        return 0
    fi

    # Stash everything including untracked files (but not ignored files)
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

git_clean_branches() {
    local DEBUG_MODE=""
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git_clean_branches [--debug]"
                echo "  --debug Show debug information"
                return 1
                ;;
            *)
                echo "✗ Error: Unexpected argument '$1'"
                echo "Usage: git_clean_branches [--debug]"
                return 1
                ;;
        esac
    done
    
    _git_validate_all || return 1

    # Get current branch name
    local CURRENT_BRANCH
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Current branch: $CURRENT_BRANCH"
        echo "Total local branches: $(git branch | wc -l)"
        echo "Total remote branches: $(git branch -r | wc -l)"
        echo "Protected pattern: $(_git_get_protected_pattern)"
        echo "=================="
    fi
    
    # Get all branches with merged/gone status in a single pass
    # Process branch list once to avoid repeated greps
    local ALL_BRANCHES_INFO
    ALL_BRANCHES_INFO=$(git for-each-ref refs/heads --format='%(refname:short) %(upstream:track)' 2>/dev/null | 
        while read -r branch track; do
            # Skip protected branches
            if echo "$branch" | grep -qE "$(_git_get_protected_pattern)" || test "$branch" = "$CURRENT_BRANCH"; then
                continue
            fi
            
            # Check if merged
            local branch_status=""
            if git merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
                branch_status="merged"
            fi
            
            # Check if gone from remote
            if test "$track" = "[gone]"; then
                if test -n "$branch_status"; then
                    branch_status="$branch_status, gone from remote"
                else
                    branch_status="gone from remote"
                fi
            fi
            
            # Only output branches that are either merged or gone
            if test -n "$branch_status"; then
                echo "$branch|$branch_status"
            fi
        done
    )
    
    if test -z "$ALL_BRANCHES_INFO"; then
        echo "✓ No branches to clean up"
        return 0
    fi
    
    echo "About to delete branches:"
    echo "$ALL_BRANCHES_INFO" | while IFS='|' read -r branch branch_status; do
        if test -n "$branch"; then
            local BRANCH_INFO
            BRANCH_INFO=$(git log --oneline -1 "$branch" 2>/dev/null || echo "No commits")
            echo "  Branch: $branch ($branch_status)"
            echo "  Last commit: $BRANCH_INFO"
        fi
    done
    echo
    
    if ! _git_confirm_action "Proceed with branch cleanup?"; then
        echo "✗ Branch cleanup cancelled."
        return 0
    fi
    
    echo "$ALL_BRANCHES_INFO" | while IFS='|' read -r branch branch_status; do
        if test -n "$branch"; then
            if git branch -d "$branch" > /dev/null 2>&1; then
                echo "✓ Deleted branch: $branch"
            else
                # Try force delete for unmerged branches that are gone from remote
                if echo "$branch_status" | grep -q "gone from remote"; then
                    if git branch -D "$branch" > /dev/null 2>&1; then
                        echo "✓ Force deleted gone branch: $branch"
                    else
                        echo "✗ Failed to delete branch: $branch"
                    fi
                else
                    echo "✗ Failed to delete unmerged branch: $branch (use -D to force)"
                fi
            fi
        fi
    done
    
    echo
    echo "✓ Branch cleanup completed"
}

git_redo() {
    local DEBUG_MODE=""
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git_redo [--debug]"
                echo "  --debug Show debug information"
                return 1
                ;;
            *)
                echo "✗ Error: Unexpected argument '$1'"
                echo "Usage: git_redo [--debug]"
                return 1
                ;;
        esac
    done
    
    _git_validate_all || return 1

    # Check if working directory is clean
    if ! git diff-index --quiet HEAD 2>/dev/null || \
       ! git diff-index --quiet --cached HEAD 2>/dev/null || \
       test -n "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "✗ Error: Working directory is not clean. Please commit or stash your changes first."
        return 1
    fi

    # Get list of undo stashes (those created by git-undo)
    local UNDO_STASHES
    UNDO_STASHES=$(git stash list 2>/dev/null | grep "undo " | head -10)
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Working directory clean: $(git diff-index --quiet HEAD 2>/dev/null && echo "true" || echo "false")"
        echo "Total stashes: $(git stash list 2>/dev/null | wc -l)"
        echo "Undo stashes found: $(echo "$UNDO_STASHES" | grep -c "undo " 2>/dev/null || echo "0")"
        echo "=================="
    fi
    
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
            
            # Extract branch, timestamp and commit message from stash message
            local branch_name timestamp commit_msg
            # POSIX-compliant: Using sed for regex extraction instead of bash parameter expansion
            # Format: "undo BRANCH - TIMESTAMP - COMMIT_MSG"
            # shellcheck disable=SC2001
            branch_name=$(echo "$stash_msg" | sed 's/undo \([^ ]*\) - .*/\1/')
            # shellcheck disable=SC2001
            timestamp=$(echo "$stash_msg" | sed 's/undo [^ ]* - \([0-9-]* [0-9:]*\) - .*/\1/')
            # shellcheck disable=SC2001
            commit_msg=$(echo "$stash_msg" | sed 's/undo [^ ]* - [0-9-]* [0-9:]* - //')
            
            # Try to get metadata from the stash
            local metadata
            metadata=$(git stash show -p "$stash_ref" 2>/dev/null | grep -A 20 "## Undo:" | head -10 || echo "")
            
            printf "  %d. %s\n" "$stash_number" "$commit_msg"
            printf "     Branch: %s\n" "$branch_name"
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
    
    # Extract branch and commit message for confirmation
    local selected_branch_name selected_commit_msg
    # POSIX-compliant: Using sed for regex extraction instead of bash parameter expansion
    # Format: "undo BRANCH - TIMESTAMP - COMMIT_MSG"
    # shellcheck disable=SC2001
    selected_branch_name=$(echo "$selected_stash_msg" | sed 's/undo \([^ ]*\) - .*/\1/')
    # shellcheck disable=SC2001
    selected_commit_msg=$(echo "$selected_stash_msg" | sed 's/undo [^ ]* - [0-9-]* [0-9:]* - //')

    echo "About to redo (restore) commit:"
    echo "  Commit: $selected_commit_msg"
    echo "  Branch: $selected_branch_name"
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

git_squash() {
    local DEBUG_MODE=""
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git_squash [--debug]"
                echo "  --debug Show debug information"
                return 1
                ;;
            *)
                echo "✗ Error: Unexpected argument '$1'"
                echo "Usage: git_squash [--debug]"
                return 1
                ;;
        esac
    done
    
    _git_validate_all || return 1
    _git_check_clean_working_dir || return 1

    # Get current branch
    local CURRENT_BRANCH
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Current branch: $CURRENT_BRANCH"
        echo "Working directory clean: $(git diff-index --quiet HEAD 2>/dev/null && echo "true" || echo "false")"
        echo "Total commits: $(git rev-list --count HEAD 2>/dev/null)"
        echo "Protected pattern: $(_git_get_protected_pattern)"
        echo "Is protected branch: $(echo "$CURRENT_BRANCH" | grep -qE "$(_git_get_protected_pattern)" && echo "true" || echo "false")"
        echo "=================="
    fi
    
    # Check if we're on main/master/develop (can't squash these)
    if echo "$CURRENT_BRANCH" | grep -qE "$(_git_get_protected_pattern)"; then
        echo "✗ Error: Cannot squash commits on main/master/develop branch"
        return 1
    fi
    
    # Find the merge base with main/master/develop
    local BASE_BRANCH=""
    for branch in main master develop; do
        if git rev-parse --verify "origin/$branch" > /dev/null 2>&1 || git rev-parse --verify "$branch" > /dev/null 2>&1; then
            BASE_BRANCH="$branch"
            break
        fi
    done
    
    if [ -z "$BASE_BRANCH" ]; then
        echo "✗ Error: Could not find base branch (main/master/develop) to squash against"
        return 1
    fi
    
    # Find merge base commit
    local MERGE_BASE
    if ! MERGE_BASE=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null); then
        echo "✗ Error: Could not find merge base with $BASE_BRANCH"
        return 1
    fi
    
    # Count commits to squash
    local COMMIT_COUNT
    COMMIT_COUNT=$(git rev-list --count "$MERGE_BASE..HEAD" 2>/dev/null)
    
    if [ "$COMMIT_COUNT" -eq 0 ]; then
        echo "✗ Error: No commits to squash (branch is up to date with $BASE_BRANCH)"
        return 1
    fi
    
    if [ "$COMMIT_COUNT" -eq 1 ]; then
        echo "✗ Error: Only one commit on branch, nothing to squash"
        return 1
    fi
    
    # Get the first (oldest) commit after merge base
    local FIRST_COMMIT_HASH FIRST_COMMIT_MSG FIRST_COMMIT_AUTHOR
    FIRST_COMMIT_HASH=$(git rev-list "$MERGE_BASE..HEAD" | tail -1)
    FIRST_COMMIT_MSG=$(git log -1 --pretty=format:"%B" "$FIRST_COMMIT_HASH" 2>/dev/null)
    FIRST_COMMIT_AUTHOR=$(git log -1 --pretty=format:"%an <%ae>" "$FIRST_COMMIT_HASH" 2>/dev/null)

    # Show what will be squashed
    echo "About to squash commits:"
    echo "  Branch: $CURRENT_BRANCH"
    echo "  Base: $BASE_BRANCH"
    echo "  Commits to squash: $COMMIT_COUNT"
    echo "  Into commit: $(git rev-parse --short "$FIRST_COMMIT_HASH") ($(git log -1 --pretty=format:"%s" "$FIRST_COMMIT_HASH"))"
    echo "  Author: $FIRST_COMMIT_AUTHOR"
    echo "  Date: Current date/time"
    echo
    echo "Commits being squashed:"
    git log --oneline "$MERGE_BASE..HEAD" | nl -s". " | tac
    echo

    if ! _git_confirm_action "Proceed with squash?"; then
        echo "✗ Squash cancelled."
        return 0
    fi

    # Create a temporary file for the commit message
    local temp_commit_msg="/tmp/git-squash-msg-$$"
    
    # Prepare initial commit message (first commit + summary of others)
    {
        echo "$FIRST_COMMIT_MSG"
        echo ""
        echo "# Squashed commits:"
        git log --pretty=format:"# - %h %s" "$MERGE_BASE..HEAD" | tac | tail -n +2
        echo ""
        echo "# Please edit the commit message above."
        echo "# Lines starting with '#' will be ignored."
    } > "$temp_commit_msg"
    
    # Reset to merge base (soft reset to keep changes)
    if ! git reset --soft "$MERGE_BASE" 2>/dev/null; then
        echo "✗ Error: Failed to reset to merge base"
        rm -f "$temp_commit_msg"
        return 1
    fi
    
    # Open editor for commit message
    local EDITOR_CMD
    EDITOR_CMD="${EDITOR:-${VISUAL:-vi}}"
    
    echo "Opening editor to edit commit message..."
    if ! "$EDITOR_CMD" "$temp_commit_msg"; then
        echo "✗ Error: Editor exited with error"
        # Try to restore the branch
        git reset --hard HEAD@{1} > /dev/null 2>&1
        rm -f "$temp_commit_msg"
        return 1
    fi
    
    # Check if user cancelled (empty message after removing comments)
    local FINAL_MSG
    FINAL_MSG=$(grep -v '^#' "$temp_commit_msg" | sed '/^$/d')
    
    if [ -z "$FINAL_MSG" ]; then
        echo "✗ Squash cancelled (empty commit message)."
        # Restore the branch
        git reset --hard HEAD@{1} > /dev/null 2>&1
        rm -f "$temp_commit_msg"
        return 0
    fi
    
    # Create the squashed commit with original author and current date
    if git commit --author="$FIRST_COMMIT_AUTHOR" --file="$temp_commit_msg" > /dev/null 2>&1; then
        echo "✓ Successfully squashed $COMMIT_COUNT commits"
        echo "✓ Commit message updated"
        
        # Show the result
        echo
        echo "Squashed commit:"
        git log -1 --oneline
    else
        echo "✗ Error: Failed to create squashed commit"
        # Try to restore the branch
        git reset --hard HEAD@{1} > /dev/null 2>&1
        rm -f "$temp_commit_msg"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_commit_msg"
}

git_status() {
    # Temporarily disable debug output
    local old_x_setting=""
    if [[ $- == *x* ]]; then
        old_x_setting="x"
        set +x
    fi
    
    _git_validate_all || return 1

    local VERBOSE_MODE=""
    local TARGET_BRANCH=""
    local CURRENT_BRANCH
    local DEBUG_MODE=""
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -v)
                VERBOSE_MODE="oneline"
                shift
                ;;
            -vv)
                VERBOSE_MODE="full"
                shift
                ;;
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git_status [-v|-vv] [--debug] [branch-name]"
                echo "  -v      Show commits since fork (feature branches) or pending commits (main/master/develop)"
                echo "  -vv     Show full commits since fork (feature branches) or pending commits (main/master/develop)"
                echo "  --debug Show debug information about branch detection and logic flow"
                return 1
                ;;
            *)
                TARGET_BRANCH="$1"
                shift
                ;;
        esac
    done
    
    # If no branch specified, use current branch
    if [ -z "$TARGET_BRANCH" ]; then
        CURRENT_BRANCH=$(_git_get_current_branch)
        TARGET_BRANCH="$CURRENT_BRANCH"
    fi
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        local effective_pattern
        effective_pattern=$(_git_get_protected_pattern)
        echo "=== DEBUG MODE ==="
        echo "TARGET_BRANCH: '$TARGET_BRANCH'"
        echo "CURRENT_BRANCH: '$CURRENT_BRANCH'"
        echo "PROTECTED_BRANCHES_PATTERN: '$PROTECTED_BRANCHES_PATTERN'"
        echo "Pattern length: ${#PROTECTED_BRANCHES_PATTERN}"
        echo "Pattern hex dump: $(echo -n "$PROTECTED_BRANCHES_PATTERN" | od -t x1 -A n)"
        echo "PROTECTED_BRANCHES_PATTERN_OVERRIDE: '$PROTECTED_BRANCHES_PATTERN_OVERRIDE'"
        echo "Effective pattern: '$effective_pattern'"
        echo "Pattern match test: $(echo "$TARGET_BRANCH" | grep -qE "$effective_pattern" && echo "MATCHES" || echo "NO MATCH")"
        echo "=================="
    fi
    
    # Validate that the target branch exists
    if ! git rev-parse --verify "$TARGET_BRANCH" > /dev/null 2>&1; then
        echo "✗ Error: Branch '$TARGET_BRANCH' does not exist"
        return 1
    fi
    
    # Check if target branch is main/master/develop - show pending commits
    if echo "$TARGET_BRANCH" | grep -qE "$(_git_get_protected_pattern)"; then
        [ "$DEBUG_MODE" = "true" ] && echo "DEBUG: Taking PROTECTED BRANCH path"
        # For main/master/develop branches, show commits since last push
        local REMOTE_BRANCH="origin/$TARGET_BRANCH"
        local PENDING_COMMITS=""
        
        # Check if remote tracking branch exists
        if git rev-parse --verify "$REMOTE_BRANCH" > /dev/null 2>&1; then
            # Get commits ahead of remote
            PENDING_COMMITS=$(git rev-list --count "$REMOTE_BRANCH..$TARGET_BRANCH" 2>/dev/null)
            
            if [ "$PENDING_COMMITS" -gt 0 ]; then
                printf "The \033[33m%s\033[0m branch has \033[33m%s\033[0m pending commit(s) since last push\n" "$TARGET_BRANCH" "$PENDING_COMMITS"
                echo
                
                # Show uncommitted files status
                if [ -n "$VERBOSE_MODE" ]; then
                    _git_get_uncommitted_status "true"
                else
                    _git_get_uncommitted_status "false"
                fi
                
                # Show pending commits if verbose mode is enabled
                if [ -n "$VERBOSE_MODE" ]; then
                    echo
                    if [ "$VERBOSE_MODE" = "oneline" ]; then
                        echo "Pending commits:"
                        git log --oneline "$REMOTE_BRANCH..$TARGET_BRANCH" 2>/dev/null
                    elif [ "$VERBOSE_MODE" = "full" ]; then
                        echo "Pending commits:"
                        git log "$REMOTE_BRANCH..$TARGET_BRANCH" 2>/dev/null
                    fi
                fi
            else
                printf "The \033[33m%s\033[0m branch is up to date with remote (no pending commits)\n" "$TARGET_BRANCH"
                echo
                
                # Show uncommitted files status
                if [ -n "$VERBOSE_MODE" ]; then
                    _git_get_uncommitted_status "true"
                else
                    _git_get_uncommitted_status "false"
                fi
            fi
        else
            # No remote tracking branch
            local TOTAL_COMMITS
            TOTAL_COMMITS=$(git rev-list --count "$TARGET_BRANCH" 2>/dev/null)
            printf "The \033[33m%s\033[0m branch has \033[33m%s\033[0m total commit(s) (no remote tracking branch)\n" "$TARGET_BRANCH" "$TOTAL_COMMITS"
            echo
            
            # Show uncommitted files status
            if [ -n "$VERBOSE_MODE" ]; then
                _git_get_uncommitted_status "true"
            else
                _git_get_uncommitted_status "false"
            fi
            
            # Show all commits if verbose mode is enabled
            if [ -n "$VERBOSE_MODE" ]; then
                echo
                if [ "$VERBOSE_MODE" = "oneline" ]; then
                    echo "All commits:"
                    git log --oneline "$TARGET_BRANCH" 2>/dev/null
                elif [ "$VERBOSE_MODE" = "full" ]; then
                    echo "All commits:"
                    git log "$TARGET_BRANCH" 2>/dev/null
                fi
            fi
        fi
        
        # Restore debug setting if it was enabled
        if [ "$old_x_setting" = "x" ]; then
            set -x
        fi
        return 0
    fi
    
    [ "$DEBUG_MODE" = "true" ] && echo "DEBUG: Taking FEATURE BRANCH path"
    # Find potential base branches to check against
    local BASE_CANDIDATES=""
    local BASE_BRANCH=""
    local MERGE_BASE=""
    local BASE_COMMIT=""
    
    # Get list of all branches except the target branch
    BASE_CANDIDATES=$(git branch -a | sed 's/^\*//' | sed 's/^[[:space:]]*//' | grep -v "^$TARGET_BRANCH$" | grep -vE "HEAD|remotes/origin/HEAD" | head -20)
    
    # Try to find the most likely base branch
    local BEST_BASE=""
    local BEST_DISTANCE=999999
    
    # Check common base branches first - prioritize develop over main for feature branches
    for candidate in develop main master origin/develop origin/main origin/master; do
        if git rev-parse --verify "$candidate" >/dev/null 2>&1; then
            merge_base=$(git merge-base "$TARGET_BRANCH" "$candidate" 2>/dev/null)
            if [ -n "$merge_base" ]; then
                # Calculate distance from merge base to target branch  
                distance=$(git rev-list --count "$merge_base..$TARGET_BRANCH" 2>/dev/null)
                distance=${distance:-999999}
                
                # Skip if this is the same branch or no commits ahead
                if [ "$distance" -gt 0 ] && [ "$distance" -le "$BEST_DISTANCE" ]; then
                    # Prefer develop over main/master when distances are equal
                    if [ "$distance" -lt "$BEST_DISTANCE" ] || \
                       [ "$distance" -eq "$BEST_DISTANCE" ] && echo "$candidate" | grep -q "develop"; then
                        BEST_BASE="$candidate"
                        BEST_DISTANCE="$distance"
                        MERGE_BASE="$merge_base"
                    fi
                fi
            fi
        fi
    done
    
    # If no good candidate found from common branches, check other branches
    if [ -z "$BEST_BASE" ] && [ -n "$BASE_CANDIDATES" ]; then
        # Use a temporary file to avoid subshell variable issues
        local temp_file="/tmp/git-status-$$"
        echo "$BASE_CANDIDATES" > "$temp_file"
        
        while read -r candidate; do
            if [ -n "$candidate" ] && git rev-parse --verify "$candidate" >/dev/null 2>&1; then
                merge_base=$(git merge-base "$TARGET_BRANCH" "$candidate" 2>/dev/null)
                if [ -n "$merge_base" ]; then
                    distance=$(git rev-list --count "$merge_base..$TARGET_BRANCH" 2>/dev/null)
                    distance=${distance:-999999}
                    
                    if [ "$distance" -gt 0 ] && [ "$distance" -lt "$BEST_DISTANCE" ]; then
                        BEST_BASE="$candidate"
                        BEST_DISTANCE="$distance"
                        MERGE_BASE="$merge_base"
                    fi
                fi
            fi
        done < "$temp_file"
        
        rm -f "$temp_file"
    fi
    
    # Use the best base found
    BASE_BRANCH="$BEST_BASE"
    
    if [ -z "$BASE_BRANCH" ] || [ -z "$MERGE_BASE" ]; then
        echo "✗ Error: Could not determine base branch for '$TARGET_BRANCH'"
        return 1
    fi
    
    # Get short commit hash
    BASE_COMMIT=$(git rev-parse --short "$MERGE_BASE" 2>/dev/null)
    
    # Clean up branch name (remove origin/ prefix if present)
    local CLEAN_BASE_NAME
    CLEAN_BASE_NAME=$(echo "$BASE_BRANCH" | sed 's/^origin\///')
    
    # Output the result
    printf "The \033[33m%s\033[0m branch forked from \033[33m%s\033[0m at commit \033[33m%s\033[0m\n" "$TARGET_BRANCH" "$CLEAN_BASE_NAME" "$BASE_COMMIT"
    echo
    
    # Show uncommitted files status
    if [ -n "$VERBOSE_MODE" ]; then
        _git_get_uncommitted_status "true"
    else
        _git_get_uncommitted_status "false"
    fi
    
    # Show commits since fork if verbose mode is enabled
    if [ -n "$VERBOSE_MODE" ]; then
        echo
        if [ "$VERBOSE_MODE" = "oneline" ]; then
            echo "Commits since fork:"
            git log --oneline "$MERGE_BASE..$TARGET_BRANCH" 2>/dev/null
        elif [ "$VERBOSE_MODE" = "full" ]; then
            echo "Commits since fork:"
            git log "$MERGE_BASE..$TARGET_BRANCH" 2>/dev/null
        fi
    fi
    
    # Restore debug setting if it was enabled
    if [ "$old_x_setting" = "x" ]; then
        set -x
    fi
}

# Backward compatibility aliases (for shells that support hyphenated function names)
# These will only work in bash and similar shells, not in strict POSIX sh
# Create aliases only if we can safely evaluate them
if [ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ]; then
    # Use a function to safely create aliases without parse errors
    _create_git_aliases() {
        alias git-undo='git_undo'
        alias git-stash='git_stash'
        alias git-clean-branches='git_clean_branches'
        alias git-redo='git_redo'
        alias git-squash='git_squash'
        alias git-status='git_status'
    }
    
    # Only run if we're in an interactive shell or aliases are enabled
    case $- in
        *i*) _create_git_aliases ;;
    esac
fi
