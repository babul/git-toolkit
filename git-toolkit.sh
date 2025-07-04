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

# Utility function to format timestamps without debug output
_git_format_date_quiet() {
    local timestamp="$1"
    # Completely redirect all output from this function to avoid debug traces
    (
        date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown date"
    ) 2>/dev/null
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

# Display file status information with color coding
# $1: file status data (output of git diff --name-status)
# $2: color context ("staged" for green, "unstaged" for red/mixed)
_git_display_file_status() {
    local file_status_data="$1"
    local color_context="$2"
    
    echo "$file_status_data" | while IFS=$'\t' read -r file_status file rest; do
        case "$file_status" in
            M*) 
                printf "    \033[32mmodified:   \033[32m%s\033[0m\n" "$file" ;;
            A*) 
                printf "    \033[32mnew file:   \033[32m%s\033[0m\n" "$file" ;;
            D*) 
                if [ "$color_context" = "staged" ]; then
                    printf "    \033[32mdeleted:    \033[32m%s\033[0m\n" "$file"
                else
                    printf "    \033[31mdeleted:    \033[31m%s\033[0m\n" "$file"
                fi
                ;;
            R*) 
                # For renames, 'file' contains old name and 'rest' contains new name
                if [ -n "$rest" ]; then
                    printf "    \033[32mrenamed:    \033[32m%s -> %s\033[0m\n" "$file" "$rest"
                else
                    printf "    \033[32mrenamed:    \033[32m%s\033[0m\n" "$file"
                fi
                ;;
            *) 
                if [ "$color_context" = "staged" ]; then
                    printf "    \033[32m%s:   \033[32m%s\033[0m\n" "$file_status" "$file"
                else
                    printf "    \033[31m%s:   \033[31m%s\033[0m\n" "$file_status" "$file"
                fi
                ;;
        esac
    done
}

# Shared argument parsing utility
# Usage: _git_parse_args function_name "$@"
# Sets variables: DEBUG_MODE, VERBOSE_MODE, TARGET_BRANCH, CUSTOM_MESSAGE, AGE_DAYS
_git_parse_args() {
    local function_name="$1"
    shift
    
    # Initialize common variables
    DEBUG_MODE=""
    
    # Function-specific variable initialization
    case "$function_name" in
        git_status)
            VERBOSE_MODE=""
            TARGET_BRANCH=""
            ;;
        git_show_branches)
            VERBOSE_MODE=""
            ;;
        git_show_stashes)
            VERBOSE_MODE=""
            ;;
        git_stash)
            CUSTOM_MESSAGE=""
            ;;
        git_clean_stashes)
            AGE_DAYS="60"  # default value
            ;;
    esac
    
    while [ $# -gt 0 ]; do
        # Skip empty arguments (can happen when variables expand to empty strings)
        if [ -z "$1" ]; then
            shift
            continue
        fi
        
        case "$1" in
            --debug)
                DEBUG_MODE="true"
                shift
                ;;
            -v)
                if [ "$function_name" = "git_status" ] || [ "$function_name" = "git_show_branches" ] || [ "$function_name" = "git_show_stashes" ]; then
                    VERBOSE_MODE="oneline"
                    shift
                else
                    echo "✗ Error: Unknown option '$1'"
                    _git_show_usage "$function_name"
                    return 1
                fi
                ;;
            -vv)
                if [ "$function_name" = "git_status" ] || [ "$function_name" = "git_show_branches" ] || [ "$function_name" = "git_show_stashes" ]; then
                    VERBOSE_MODE="full"
                    shift
                else
                    echo "✗ Error: Unknown option '$1'"
                    _git_show_usage "$function_name"
                    return 1
                fi
                ;;
            --age=*)
                if [ "$function_name" = "git_clean_stashes" ]; then
                    AGE_DAYS=$(echo "$1" | sed 's/--age=//')
                    if ! echo "$AGE_DAYS" | grep -q "^[0-9]\+$"; then
                        echo "✗ Error: Invalid age value '$AGE_DAYS'. Must be a positive integer."
                        return 1
                    fi
                    shift
                else
                    echo "✗ Error: Unknown option '$1'"
                    _git_show_usage "$function_name"
                    return 1
                fi
                ;;
            -*)
                echo "✗ Error: Unknown option '$1'"
                _git_show_usage "$function_name"
                return 1
                ;;
            *)
                # Handle positional arguments based on function
                case "$function_name" in
                    git_stash)
                        # Collect all remaining arguments as the custom message
                        if [ -z "$CUSTOM_MESSAGE" ]; then
                            CUSTOM_MESSAGE="$1"
                        else
                            CUSTOM_MESSAGE="$CUSTOM_MESSAGE $1"
                        fi
                        shift
                        ;;
                    git_status)
                        # Accept single branch name
                        TARGET_BRANCH="$1"
                        shift
                        ;;
                    *)
                        # Functions that don't accept positional arguments
                        echo "✗ Error: Unexpected argument '$1'"
                        _git_show_usage "$function_name"
                        return 1
                        ;;
                esac
                ;;
        esac
    done
}

# Generate usage message for each function
_git_show_usage() {
    local function_name="$1"
    case "$function_name" in
        git_undo)
            echo "Usage: git_undo [--debug]"
            echo "  --debug Show debug information"
            ;;
        git_stash)
            echo "Usage: git_stash [--debug] [message]"
            echo "  --debug Show debug information"
            echo "  message Custom stash message"
            ;;
        git_clean_branches)
            echo "Usage: git_clean_branches [--debug]"
            echo "  --debug Show debug information"
            ;;
        git_redo)
            echo "Usage: git_redo [--debug]"
            echo "  --debug Show debug information"
            ;;
        git_squash)
            echo "Usage: git_squash [--debug]"
            echo "  --debug Show debug information"
            ;;
        git_status)
            echo "Usage: git_status [-v|-vv] [--debug] [branch-name]"
            echo "  -v       Show oneline commits since fork"
            echo "  -vv      Show full commits since fork"
            echo "  --debug  Show debug information"
            echo "  branch-name  Target branch to check against"
            ;;
        git_show_branches)
            echo "Usage: git_show_branches [-v|-vv] [--debug]"
            echo "  -v       Show last commit for each branch"
            echo "  -vv      Show full last commit details for each branch"
            echo "  --debug  Show debug information"
            ;;
        git_show_stashes)
            echo "Usage: git_show_stashes [-v|-vv] [--debug]"
            echo "  -v       Show number of files changed in each stash"
            echo "  -vv      Show full diff stat for each stash"
            echo "  --debug  Show debug information"
            ;;
        git_clean_stashes)
            echo "Usage: git_clean_stashes [--debug] [--age=days]"
            echo "  --debug    Show debug information"
            echo "  --age=N    Clean stashes older than N days (default: 60)"
            ;;
    esac
}

_git_validate_all() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1
    return 0
}

_git_get_uncommitted_status() {
    local show_details="$1"
    local modified_count=0
    local deleted_count=0
    local staged_count=0
    local untracked_count=0
    local total_count=0
    
    # Get staged files with their status
    local staged_files_with_status
    staged_files_with_status=$(git diff --cached --name-status 2>/dev/null)
    if [ -n "$staged_files_with_status" ]; then
        staged_count=$(echo "$staged_files_with_status" | wc -l)
        total_count=$((total_count + staged_count))
    fi
    
    # Get modified and deleted files with their status
    local modified_files_with_status
    modified_files_with_status=$(git diff --name-status 2>/dev/null)
    if [ -n "$modified_files_with_status" ]; then
        # Count all file types in single pass
        local counts
        counts=$(echo "$modified_files_with_status" | awk '
            /^M/ { modified++ }
            /^D/ { deleted++ }
            END { print (modified+0), (deleted+0), NR }
        ')
        modified_count=$(echo "$counts" | cut -d' ' -f1)
        deleted_count=$(echo "$counts" | cut -d' ' -f2)
        local working_tree_count=$(echo "$counts" | cut -d' ' -f3)
        total_count=$((total_count + working_tree_count))
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
            _git_display_file_status "$staged_files_with_status" "staged"
            sections_shown=$((sections_shown + 1))
        fi
        if [ "$modified_count" -gt 0 ] || [ "$deleted_count" -gt 0 ]; then
            [ "$sections_shown" -gt 0 ] && echo
            printf "  \033[31mChanges not staged for commit:\033[0m\n"
            _git_display_file_status "$modified_files_with_status" "unstaged"
            sections_shown=$((sections_shown + 1))
        fi
        if [ "$untracked_count" -gt 0 ]; then
            [ "$sections_shown" -gt 0 ] && echo
            printf "  \033[31mUntracked files:\033[0m\n"
            echo "$untracked_files" | while read -r file; do
                printf "    \033[31m%s\033[0m\n" "$file"
            done
            sections_shown=$((sections_shown + 1))
        fi
    else
        echo "$total_count uncommitted files"
    fi
}

git_undo() {
    # Parse command line arguments using shared utility
    _git_parse_args "git_undo" "$@" || return 1
    
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

    local FULL_COMMIT_HASH CURRENT_BRANCH
    FULL_COMMIT_HASH=$(git rev-parse HEAD 2>/dev/null)
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    local STASH_MSG="undo $CURRENT_BRANCH $LAST_COMMIT_SUBJECT"

    git reset HEAD~1
    
    # Create temporary metadata file in working directory
    local temp_metadata="__metadata.txt"
    {
        echo "## Undo: $(_git_format_timestamp)"
        echo ""
        echo "**Commit Hash:** $FULL_COMMIT_HASH"
        echo "**Stash:** undo $CURRENT_BRANCH $LAST_COMMIT_SUBJECT"
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
        [ -f "$temp_metadata" ] && rm -f "$temp_metadata"
        return 1
    fi
    
    local STASH_NAME
    STASH_NAME=$(git stash list | grep -F "$STASH_MSG" | head -1 | cut -d: -f1)
    
    # Verify stash was created successfully
    if [ -z "$STASH_NAME" ]; then
        echo "✗ Error: Stash was not created successfully"
        [ -f "$temp_metadata" ] && rm -f "$temp_metadata"
        return 1
    fi
    
    # Verify metadata file is actually in the stash before cleanup
    if ! git stash show --name-only "$STASH_NAME" | grep -q "$temp_metadata"; then
        echo "✗ Error: Metadata file was not saved in stash"
        [ -f "$temp_metadata" ] && rm -f "$temp_metadata"
        return 1
    fi
    
    # Safe to remove temp file now that we've verified it's in the stash
    [ -f "$temp_metadata" ] && rm -f "$temp_metadata"
    echo ""
    echo "✓ Commit undone and changes stashed to $STASH_NAME"
}

git_stash() {
    # Parse command line arguments using shared utility
    _git_parse_args "git_stash" "$@" || return 1
    
    _git_validate_all || return 1

    # Check if there's anything to stash (including untracked files)
    if git diff-index --quiet HEAD 2>/dev/null && \
       git diff-index --quiet --cached HEAD 2>/dev/null && \
       test -z "$(git ls-files --others --exclude-standard 2>/dev/null)"; then
        echo "✓ No changes to stash (working directory is clean)"
        return 0
    fi

    local STASH_MSG CURRENT_BRANCH
    CURRENT_BRANCH=$(_git_get_current_branch)
    if [ -n "$CUSTOM_MESSAGE" ]; then
        STASH_MSG="stash $CURRENT_BRANCH $CUSTOM_MESSAGE"
    else
        STASH_MSG="stash $CURRENT_BRANCH"
    fi
    
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
    local staged_files_with_status
    staged_files_with_status=$(git diff --cached --name-status 2>/dev/null)
    if [ -n "$staged_files_with_status" ]; then
        [ "$sections_shown" -gt 0 ] && echo
        printf "  \033[32mChanges to be committed:\033[0m\n"
        _git_display_file_status "$staged_files_with_status" "staged"
        sections_shown=$((sections_shown + 1))
    fi
    
    # Show modified and deleted files (red)
    local modified_files_with_status
    modified_files_with_status=$(git diff --name-status 2>/dev/null)
    if [ -n "$modified_files_with_status" ]; then
        [ "$sections_shown" -gt 0 ] && echo
        printf "  \033[31mChanges not staged for commit:\033[0m\n"
        _git_display_file_status "$modified_files_with_status" "unstaged"
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
    # Parse command line arguments using shared utility
    _git_parse_args "git_clean_branches" "$@" || return 1
    
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
    # Parse command line arguments using shared utility
    _git_parse_args "git_redo" "$@" || return 1
    
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
            
            # Extract branch and commit message from stash message
            local branch_name commit_msg
            # POSIX-compliant: Using sed for regex extraction instead of bash parameter expansion
            # Format: "undo BRANCH COMMIT_MSG"
            # shellcheck disable=SC2001
            branch_name=$(echo "$stash_msg" | sed 's/undo \([^ ]*\) .*/\1/')
            # shellcheck disable=SC2001
            commit_msg=$(echo "$stash_msg" | sed 's/undo [^ ]* //')
            
            # Try to get metadata from the stash
            local metadata
            metadata=$(git stash show -p "$stash_ref" 2>/dev/null | grep -A 20 "## Undo:" | head -10 || echo "")
            
            printf "  %d. %s\n" "$stash_number" "$commit_msg"
            printf "     Branch: %s\n" "$branch_name"
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
    # Format: "undo BRANCH COMMIT_MSG"
    # shellcheck disable=SC2001
    selected_branch_name=$(echo "$selected_stash_msg" | sed 's/undo \([^ ]*\) .*/\1/')
    # shellcheck disable=SC2001
    selected_commit_msg=$(echo "$selected_stash_msg" | sed 's/undo [^ ]* //')

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
    # Parse command line arguments using shared utility
    _git_parse_args "git_squash" "$@" || return 1
    
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
    
    # Validate base branch exists before attempting merge-base
    if ! git rev-parse --verify "$BASE_BRANCH" >/dev/null 2>&1; then
        echo "✗ Error: Base branch '$BASE_BRANCH' does not exist"
        echo "  Available branches: $(git branch -a --format='%(refname:short)' | tr '\n' ' ')"
        return 1
    fi
    
    # Find merge base commit
    local MERGE_BASE
    if ! MERGE_BASE=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null); then
        echo "✗ Error: Could not find merge base with $BASE_BRANCH"
        echo "  This usually means the branches have no common history"
        echo "  Current branch: $CURRENT_BRANCH"
        echo "  Target base: $BASE_BRANCH"
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
    local temp_commit_msg
    temp_commit_msg=$(mktemp -t git-squash-msg.XXXXXX) || {
        echo "✗ Error: Could not create temporary file"
        return 1
    }
    
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
        [ -f "$temp_commit_msg" ] && rm -f "$temp_commit_msg"
        return 1
    fi
    
    # Open editor for commit message
    local EDITOR_CMD
    EDITOR_CMD="${EDITOR:-${VISUAL:-vi}}"
    
    # Validate editor command to prevent command injection
    case "$EDITOR_CMD" in
        *\;*|*\&*|*\|*|*\$*|*\`*|*\(*|*\)*|*\{*|*\}*)
            echo "✗ Error: Editor command contains unsafe characters"
            [ -f "$temp_commit_msg" ] && rm -f "$temp_commit_msg"
            return 1
            ;;
    esac
    
    echo "Opening editor to edit commit message..."
    if ! "$EDITOR_CMD" "$temp_commit_msg"; then
        local editor_exit_code=$?
        echo "✗ Error: Editor exited with error (exit code: $editor_exit_code)"
        echo "  Editor command: $EDITOR_CMD"
        echo "  This could mean:"
        echo "    - Editor was cancelled or interrupted"
        echo "    - Editor command is invalid or not found"
        echo "    - Editor encountered an internal error"
        echo "  Restoring branch to original state..."
        # Try to restore the branch
        git reset --hard HEAD@{1} > /dev/null 2>&1
        [ -f "$temp_commit_msg" ] && rm -f "$temp_commit_msg"
        return 1
    fi
    
    # Check if user cancelled (empty message after removing comments)
    local FINAL_MSG
    FINAL_MSG=$(grep -v '^#' "$temp_commit_msg" | sed '/^$/d')
    
    if [ -z "$FINAL_MSG" ]; then
        echo "✗ Squash cancelled (empty commit message)."
        # Restore the branch
        git reset --hard HEAD@{1} > /dev/null 2>&1
        [ -f "$temp_commit_msg" ] && rm -f "$temp_commit_msg"
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
        [ -f "$temp_commit_msg" ] && rm -f "$temp_commit_msg"
        return 1
    fi
    
    # Cleanup
    [ -f "$temp_commit_msg" ] && rm -f "$temp_commit_msg"
}

git_clean_stashes() {
    # Parse command line arguments using shared utility
    _git_parse_args "git_clean_stashes" "$@" || return 1
    
    _git_validate_all || return 1
    
    # Get current timestamp for age comparison
    local CURRENT_TIMESTAMP
    CURRENT_TIMESTAMP=$(date +%s 2>/dev/null)
    if [ -z "$CURRENT_TIMESTAMP" ]; then
        echo "✗ Error: Failed to get current timestamp"
        return 1
    fi
    
    # Calculate cutoff timestamp (AGE_DAYS ago)
    local CUTOFF_TIMESTAMP
    CUTOFF_TIMESTAMP=$((CURRENT_TIMESTAMP - AGE_DAYS * 24 * 3600))
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Age threshold: $AGE_DAYS days"
        echo "Current timestamp: $CURRENT_TIMESTAMP"
        echo "Cutoff timestamp: $CUTOFF_TIMESTAMP"
        echo "Total stashes: $(git stash list 2>/dev/null | wc -l)"
        echo "=================="
    fi
    
    # Get all stashes and their creation timestamps
    local OLD_STASHES=""
    local stash_count=0
    
    # Use a temporary file to collect old stashes info
    local temp_file
    temp_file=$(mktemp -t git-clean-stashes.XXXXXX) || {
        echo "✗ Error: Could not create temporary file"
        return 1
    }
    
    git stash list --format="%gd|%ct|%gs" 2>/dev/null | while IFS='|' read -r stash_ref stash_timestamp stash_msg; do
        if [ -n "$stash_ref" ] && [ -n "$stash_timestamp" ]; then
            # Compare timestamps (stash_timestamp is in seconds since epoch)
            if [ "$stash_timestamp" -lt "$CUTOFF_TIMESTAMP" ]; then
                # Calculate age in days for display
                local age_seconds=$((CURRENT_TIMESTAMP - stash_timestamp))
                local age_days=$((age_seconds / 86400))
                
                # Format date for display (use portable date command)
                printf "%s|%s|%s|%s\n" "$stash_ref" "$age_days" "$(_git_format_date_quiet "$stash_timestamp")" "$stash_msg" >> "$temp_file"
            fi
        fi
    done
    
    # Check if any old stashes were found
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        [ -f "$temp_file" ] && rm -f "$temp_file"
        echo "✓ No stashes older than $AGE_DAYS days found"
        return 0
    fi
    
    # Count old stashes
    stash_count=$(wc -l < "$temp_file")
    
    echo "Found $stash_count stash(es) older than $AGE_DAYS days:"
    echo
    
    # Display stashes to be deleted
    while IFS='|' read -r stash_ref age_days stash_date stash_msg; do
        if [ -n "$stash_ref" ]; then
            echo "  Stash: $stash_ref"
            echo "  Age: $age_days days (created: $stash_date)"
            echo "  Message: $stash_msg"
            echo
        fi
    done < "$temp_file"
    
    if ! _git_confirm_action "Proceed with deleting these $stash_count old stash(es)?"; then
        echo "✗ Stash cleanup cancelled."
        [ -f "$temp_file" ] && rm -f "$temp_file"
        return 0
    fi
    
    # Delete the old stashes (sort by stash index in reverse order to avoid reference shifting)
    local deleted_count=0
    local failed_count=0
    
    # Create a sorted copy for deletion (highest index first to avoid reference shifting)
    local temp_delete_file
    temp_delete_file=$(mktemp -t git-clean-stashes-delete.XXXXXX) || {
        echo "✗ Error: Could not create temporary file"
        [ -f "$temp_file" ] && rm -f "$temp_file"
        return 1
    }
    sort -t'{' -k2 -nr "$temp_file" > "$temp_delete_file"
    
    while IFS='|' read -r stash_ref age_days stash_date stash_msg; do
        if [ -n "$stash_ref" ]; then
            if git stash drop "$stash_ref" > /dev/null 2>&1; then
                echo "✓ Deleted stash: $stash_ref"
                deleted_count=$((deleted_count + 1))
            else
                echo "✗ Failed to delete stash: $stash_ref"
                failed_count=$((failed_count + 1))
            fi
        fi
    done < "$temp_delete_file"
    
    [ -f "$temp_delete_file" ] && rm -f "$temp_delete_file"
    
    # Cleanup temp file
    rm -f "$temp_file"
    
    echo
    if [ "$failed_count" -eq 0 ]; then
        echo "✓ Successfully deleted $deleted_count stash(es)"
    else
        echo "✓ Deleted $deleted_count stash(es), failed to delete $failed_count stash(es)"
        return 1
    fi
}

git_status() {
    # Temporarily disable debug output
    local old_x_setting=""
    case $- in
        *x*) 
            old_x_setting="x"
            set +x
            ;;
    esac
    
    # Parse command line arguments using shared utility
    _git_parse_args "git_status" "$@" || return 1
    
    _git_validate_all || return 1

    local CURRENT_BRANCH
    
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
    
    # Pre-validate existing branches to avoid repeated git rev-parse calls
    local existing_branches
    existing_branches=$(git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ 2>/dev/null)
    
    # Check common base branches first - prioritize develop over main for feature branches
    for candidate in develop main master origin/develop origin/main origin/master; do
        # Quick check if branch exists using pre-validated list
        if echo "$existing_branches" | grep -q "^$candidate$"; then
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
        local temp_file
        temp_file=$(mktemp -t git-status.XXXXXX) || {
            echo "✗ Error: Could not create temporary file"
            return 1
        }
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
        
        [ -f "$temp_file" ] && rm -f "$temp_file"
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

git_show_branches() {
    # Parse command line arguments using shared utility
    _git_parse_args "git_show_branches" "$@" || return 1
    
    _git_validate_all || return 1
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Listing all local branches with remote tracking status"
        echo "=================="
    fi
    
    # Get all local branches
    local branches
    branches=$(git branch --format='%(refname:short)' 2>/dev/null)
    
    if [ -z "$branches" ]; then
        echo "✓ No local branches found"
        return 0
    fi
    
    # Use a temporary file to avoid subshell issues with while loop
    local temp_file
    temp_file=$(mktemp -t git-show-branches.XXXXXX) || {
        echo "✗ Error: Could not create temporary file"
        return 1
    }
    echo "$branches" > "$temp_file"
    
    # Calculate maximum lengths for column alignment
    local max_branch_len max_remote_len
    
    # Calculate lengths in subshell to suppress all debug output
    local length_result
    length_result=$(
        max_branch_len=0
        max_remote_len=12  # Minimum for "(local only)"
        
        while read -r branch; do
            if [ -n "$branch" ]; then
                # Check branch name length
                branch_len=${#branch}
                if [ "$branch_len" -gt "$max_branch_len" ]; then
                    max_branch_len=$branch_len
                fi
                
                # Check remote ref length
                remote_ref=$(git config "branch.$branch.remote" 2>/dev/null || true)
                remote_branch=$(git config "branch.$branch.merge" 2>/dev/null | sed 's|refs/heads/||' || true)
                
                if [ -n "$remote_ref" ] && [ -n "$remote_branch" ]; then
                    full_remote="${remote_ref}/${remote_branch}"
                    remote_len=${#full_remote}
                    if [ "$remote_len" -gt "$max_remote_len" ]; then
                        max_remote_len=$remote_len
                    fi
                fi
            fi
        done < "$temp_file"
        echo "$max_branch_len $max_remote_len"
    ) 2>/dev/null
    
    # Parse the results
    max_branch_len=$(echo "$length_result" | cut -d' ' -f1)
    max_remote_len=$(echo "$length_result" | cut -d' ' -f2)
    
    # Add 2 characters padding to each column
    max_branch_len=$((max_branch_len + 2))
    max_remote_len=$((max_remote_len + 2))
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "Calculated max_branch_len: $max_branch_len"
        echo "Calculated max_remote_len: $max_remote_len"
    fi
    
    # Process each branch
    while read -r branch; do
        if [ -n "$branch" ]; then
            # Get remote tracking info
            local remote_ref remote_branch
            remote_ref=$(git config "branch.$branch.remote" 2>/dev/null || true)
            remote_branch=$(git config "branch.$branch.merge" 2>/dev/null | sed 's|refs/heads/||' || true)
            
            # Format branch name with padding
            local branch_display
            local fmt_str="%-${max_branch_len}s"
            branch_display=$(printf "$fmt_str" "$branch")
            
            if [ -n "$remote_ref" ] && [ -n "$remote_branch" ]; then
                # Has remote tracking
                local full_remote_ref="$remote_ref/$remote_branch"
                local remote_display
                local fmt_str2="%-${max_remote_len}s"
                remote_display=$(printf "$fmt_str2" "$full_remote_ref")
                
                # Check if remote branch exists
                if git rev-parse --verify "$full_remote_ref" >/dev/null 2>&1; then
                    # Get ahead/behind status
                    local ahead behind
                    ahead=$(git rev-list --count "$full_remote_ref..$branch" 2>/dev/null || echo "0")
                    behind=$(git rev-list --count "$branch..$full_remote_ref" 2>/dev/null || echo "0")
                    
                    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
                        printf "\033[33m%s\033[0m  \033[36m%s\033[0m  Status: \033[31m%s ahead, %s behind\033[0m\n" "$branch_display" "$remote_display" "$ahead" "$behind"
                    elif [ "$ahead" -gt 0 ]; then
                        printf "\033[33m%s\033[0m  \033[36m%s\033[0m  Status: \033[33m%s ahead\033[0m\n" "$branch_display" "$remote_display" "$ahead"
                    elif [ "$behind" -gt 0 ]; then
                        printf "\033[33m%s\033[0m  \033[36m%s\033[0m  Status: \033[31m%s behind\033[0m\n" "$branch_display" "$remote_display" "$behind"
                    else
                        printf "\033[33m%s\033[0m  \033[36m%s\033[0m  Status: \033[32mup to date\033[0m\n" "$branch_display" "$remote_display"
                    fi
                else
                    printf "\033[33m%s\033[0m  \033[36m%s\033[0m  Status: \033[31mremote branch gone\033[0m\n" "$branch_display" "$remote_display"
                fi
            else
                # No remote tracking
                local commit_count
                commit_count=$(git rev-list --count "$branch" 2>/dev/null || echo "0")
                local local_only_display
                local_only_display=$(printf "%-${max_remote_len}s" "(local only)")
                printf "\033[33m%s\033[0m  \033[90m%s\033[0m  Status: \033[90m%s local commit(s)\033[0m\n" "$branch_display" "$local_only_display" "$commit_count"
            fi
            
            # Show last commit info if verbose
            if [ -n "$VERBOSE_MODE" ]; then
                local last_commit
                last_commit=$(git log -1 --format="%h %s" "$branch" 2>/dev/null || echo "No commits")
                local indent_len=$((max_branch_len + 2 + max_remote_len + 2))
                printf "%${indent_len}s└─ %s\n" "" "$last_commit"
            fi
        fi
    done < "$temp_file"
    
    [ -f "$temp_file" ] && rm -f "$temp_file"
}

git_show_stashes() {
    # Temporarily disable debug output
    local old_x_setting=""
    case $- in
        *x*) 
            old_x_setting="x"
            set +x
            ;;
    esac
    
    # Parse command line arguments using shared utility
    _git_parse_args "git_show_stashes" "$@" || return 1
    
    _git_validate_all || return 1
    
    # Debug output
    if [ "$DEBUG_MODE" = "true" ]; then
        echo "=== DEBUG MODE ==="
        echo "Listing all stashes with creation time and age"
        echo "=================="
    fi
    
    # Get current timestamp for age calculation
    local CURRENT_TIMESTAMP
    CURRENT_TIMESTAMP=$(date +%s 2>/dev/null)
    if [ -z "$CURRENT_TIMESTAMP" ]; then
        echo "✗ Error: Failed to get current timestamp"
        return 1
    fi
    
    # Check if there are any stashes
    local stash_count
    stash_count=$(git stash list 2>/dev/null | wc -l)
    
    if [ "$stash_count" -eq 0 ]; then
        echo "✓ No stashes found"
        return 0
    fi
    
    # Use temporary file to collect stash info
    local temp_file
    temp_file=$(mktemp -t git-show-stashes.XXXXXX) || {
        echo "✗ Error: Could not create temporary file"
        return 1
    }
    
    # Get stash information with timestamps
    git stash list --format="%gd|%ct|%gs" 2>/dev/null | while IFS='|' read -r stash_ref stash_timestamp stash_msg; do
        if [ -n "$stash_ref" ] && [ -n "$stash_timestamp" ]; then
            # Calculate age in days
            local age_seconds=$((CURRENT_TIMESTAMP - stash_timestamp))
            local age_days=$((age_seconds / 86400))
            
            # Format date for display
            local formatted_date
            formatted_date=$(_git_format_date_quiet "$stash_timestamp")
            
            # Write to temp file: date|name|age|ref
            printf "%s|%s|%s|%s\n" "$formatted_date" "$stash_msg" "$age_days" "$stash_ref" >> "$temp_file"
        fi
    done
    
    # Check if we have any data
    if [ ! -s "$temp_file" ]; then
        [ -f "$temp_file" ] && rm -f "$temp_file"
        echo "✓ No stashes found"
        return 0
    fi
    
    # Calculate column widths for alignment
    local max_date_len=19  # Default for YYYY-MM-DD HH:MM:SS format
    local max_name_len=0
    local max_age_len=8   # Minimum for "days old"
    
    # Calculate maximum lengths in a subshell to avoid debug output
    local length_result
    length_result=$(
        while IFS='|' read -r formatted_date stash_msg age_days stash_ref; do
            # Check name length
            name_len=${#stash_msg}
            if [ "$name_len" -gt "$max_name_len" ]; then
                max_name_len=$name_len
            fi
            
            # Check age display length
            age_display="$age_days days old"
            age_len=${#age_display}
            if [ "$age_len" -gt "$max_age_len" ]; then
                max_age_len=$age_len
            fi
        done < "$temp_file"
        echo "$max_name_len $max_age_len"
    ) 2>/dev/null
    
    # Parse the results
    max_name_len=$(echo "$length_result" | cut -d' ' -f1)
    max_age_len=$(echo "$length_result" | cut -d' ' -f2)
    
    # Add padding
    max_date_len=$((max_date_len + 2))
    max_name_len=$((max_name_len + 2))
    max_age_len=$((max_age_len + 2))
    
    # Print header
    printf "\033[1mStashes:\033[0m\n\n"
    
    # Display stashes
    while IFS='|' read -r formatted_date stash_msg age_days stash_ref; do
        if [ -n "$stash_ref" ]; then
            # Format columns with proper padding
            local date_display name_display age_display
            local fmt_date="%-${max_date_len}s"
            local fmt_name="%-${max_name_len}s"
            local fmt_age="%-${max_age_len}s"
            
            date_display=$(printf "$fmt_date" "$formatted_date")
            name_display=$(printf "$fmt_name" "$stash_msg")
            age_display=$(printf "$fmt_age" "$age_days days old")
            
            # Color code based on age
            if [ "$age_days" -gt 60 ]; then
                # Old stashes (>60 days) in red
                printf "\033[90m%s\033[0m  \033[33m%s\033[0m  \033[31m%s\033[0m\n" "$date_display" "$name_display" "$age_display"
            elif [ "$age_days" -gt 30 ]; then
                # Medium age (30-60 days) in yellow
                printf "\033[90m%s\033[0m  \033[33m%s\033[0m  \033[33m%s\033[0m\n" "$date_display" "$name_display" "$age_display"
            else
                # Recent stashes (<30 days) in green
                printf "\033[90m%s\033[0m  \033[33m%s\033[0m  \033[32m%s\033[0m\n" "$date_display" "$name_display" "$age_display"
            fi
            
            # Show stash details if verbose mode
            if [ -n "$VERBOSE_MODE" ]; then
                local indent=$((max_date_len + 2))
                
                if [ "$VERBOSE_MODE" = "oneline" ]; then
                    # Show files changed
                    local files_changed
                    files_changed=$(git stash show --name-only "$stash_ref" 2>/dev/null | wc -l)
                    printf "%${indent}s└─ %s file(s) changed\n" "" "$files_changed"
                elif [ "$VERBOSE_MODE" = "full" ]; then
                    # Show full diff stat
                    local diff_stat
                    diff_stat=$(git stash show --stat "$stash_ref" 2>/dev/null | tail -1)
                    printf "%${indent}s└─ %s\n" "" "$diff_stat"
                fi
            fi
        fi
    done < "$temp_file"
    
    # Cleanup
    [ -f "$temp_file" ] && rm -f "$temp_file"
    
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
        alias git-clean-stashes='git_clean_stashes'
        alias git-redo='git_redo'
        alias git-squash='git_squash'
        alias git-status='git_status'
        alias git-show-branches='git_show_branches'
        alias git-show-stashes='git_show_stashes'
    }
    
    # Only run if we're in an interactive shell or aliases are enabled
    case $- in
        *i*) _create_git_aliases ;;
    esac
fi
