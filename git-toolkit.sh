#!/usr/bin/env bash

# Cross-platform compatibility
# Note: Removed 'set -e' to maintain compatibility with terminal environments like Warp
#set -e

# Shared constants
if [ -z "$PROTECTED_BRANCHES_PATTERN" ]; then
    readonly PROTECTED_BRANCHES_PATTERN="^(main|master|develop)$"
fi
if [ -z "$DATE_FORMAT" ] || [ "$DATE_FORMAT" = "" ]; then
    readonly DATE_FORMAT='%Y-%m-%d %H:%M:%S'
fi

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
    local format="${DATE_FORMAT:-'%Y-%m-%d %H:%M:%S'}"
    date "+$format" 2>/dev/null
}

_git_validate_all() {
    _git_validate_repo || return 1
    _git_validate_commits || return 1
    return 0
}

git-undo() {
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
    _git_validate_all || return 1

    # Check if there's anything to stash
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
    _git_validate_all || return 1

    # Get current branch name
    local CURRENT_BRANCH
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    # Collect branches to delete
    local MERGED_BRANCHES=""
    local GONE_BRANCHES=""
    
    # Get all branches with merged/gone status in a single pass
    # Process branch list once to avoid repeated greps
    local ALL_BRANCHES_INFO
    ALL_BRANCHES_INFO=$(git for-each-ref refs/heads --format='%(refname:short) %(upstream:track)' 2>/dev/null | 
        while read -r branch track; do
            # Skip protected branches
            if echo "$branch" | grep -qE "$PROTECTED_BRANCHES_PATTERN" || test "$branch" = "$CURRENT_BRANCH"; then
                continue
            fi
            
            # Check if merged
            local status=""
            if git merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
                status="merged"
            fi
            
            # Check if gone from remote
            if test "$track" = "[gone]"; then
                if test -n "$status"; then
                    status="$status, gone from remote"
                else
                    status="gone from remote"
                fi
            fi
            
            # Only output branches that are either merged or gone
            if test -n "$status"; then
                echo "$branch|$status"
            fi
        done
    )
    
    if test -z "$ALL_BRANCHES_INFO"; then
        echo "✓ No branches to clean up"
        return 0
    fi
    
    echo "About to delete branches:"
    echo "$ALL_BRANCHES_INFO" | while IFS='|' read -r branch status; do
        if test -n "$branch"; then
            local BRANCH_INFO
            BRANCH_INFO=$(git log --oneline -1 "$branch" 2>/dev/null || echo "No commits")
            echo "  Branch: $branch ($status)"
            echo "  Last commit: $BRANCH_INFO"
        fi
    done
    echo
    
    if ! _git_confirm_action "Proceed with branch cleanup?"; then
        echo "✗ Branch cleanup cancelled."
        return 0
    fi
    
    echo "$ALL_BRANCHES_INFO" | while IFS='|' read -r branch status; do
        if test -n "$branch"; then
            if git branch -d "$branch" > /dev/null 2>&1; then
                echo "✓ Deleted branch: $branch"
            else
                # Try force delete for unmerged branches that are gone from remote
                if echo "$status" | grep -q "gone from remote"; then
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

git-redo() {
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

git-squash() {
    _git_validate_all || return 1
    _git_check_clean_working_dir || return 1

    # Get current branch
    local CURRENT_BRANCH
    CURRENT_BRANCH=$(_git_get_current_branch)
    
    # Check if we're on main/master/develop (can't squash these)
    if echo "$CURRENT_BRANCH" | grep -qE "$PROTECTED_BRANCHES_PATTERN"; then
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
    local FIRST_COMMIT_HASH FIRST_COMMIT_MSG FIRST_COMMIT_AUTHOR FIRST_COMMIT_DATE
    FIRST_COMMIT_HASH=$(git rev-list "$MERGE_BASE..HEAD" | tail -1)
    FIRST_COMMIT_MSG=$(git log -1 --pretty=format:"%B" "$FIRST_COMMIT_HASH" 2>/dev/null)
    FIRST_COMMIT_AUTHOR=$(git log -1 --pretty=format:"%an <%ae>" "$FIRST_COMMIT_HASH" 2>/dev/null)
    FIRST_COMMIT_DATE=$(git log -1 --pretty=format:"%ai" "$FIRST_COMMIT_HASH" 2>/dev/null)
    
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

git-show() {
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
            -*)
                echo "✗ Error: Unknown option '$1'"
                echo "Usage: git-show [-v|-vv] [branch-name]"
                echo "  -v   Show commits since fork (feature branches) or pending commits (main/master/develop)"
                echo "  -vv  Show full commits since fork (feature branches) or pending commits (main/master/develop)"
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
    
    # Validate that the target branch exists
    if ! git rev-parse --verify "$TARGET_BRANCH" > /dev/null 2>&1; then
        echo "✗ Error: Branch '$TARGET_BRANCH' does not exist"
        return 1
    fi
    
    # Check if target branch is main/master/develop - show pending commits
    if echo "$TARGET_BRANCH" | grep -qE "$PROTECTED_BRANCHES_PATTERN"; then
        # For main/master/develop branches, show commits since last push
        local REMOTE_BRANCH="origin/$TARGET_BRANCH"
        local PENDING_COMMITS=""
        
        # Check if remote tracking branch exists
        if git rev-parse --verify "$REMOTE_BRANCH" > /dev/null 2>&1; then
            # Get commits ahead of remote
            PENDING_COMMITS=$(git rev-list --count "$REMOTE_BRANCH..$TARGET_BRANCH" 2>/dev/null)
            
            if [ "$PENDING_COMMITS" -gt 0 ]; then
                echo "The $TARGET_BRANCH branch has $PENDING_COMMITS pending commit(s) since last push"
                
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
                echo "The $TARGET_BRANCH branch is up to date with remote (no pending commits)"
            fi
        else
            # No remote tracking branch
            local TOTAL_COMMITS
            TOTAL_COMMITS=$(git rev-list --count "$TARGET_BRANCH" 2>/dev/null)
            echo "The $TARGET_BRANCH branch has $TOTAL_COMMITS total commit(s) (no remote tracking branch)"
            
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
        local temp_file="/tmp/git-show-$$"
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
    echo "The $TARGET_BRANCH branch forked from $CLEAN_BASE_NAME at commit $BASE_COMMIT"
    
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
