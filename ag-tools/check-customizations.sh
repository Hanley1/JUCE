#!/usr/bin/env bash
# check-customizations.sh — guard Audible Genius's edits to JUCE across a JUCE update.
#
# Our JUCE is a fork: upstream JUCE plus a handful of our own edits under modules/.
# Updating JUCE (merging a new upstream release in) is where those edits get lost:
# a conflict settled by taking JUCE's side, or a file JUCE renamed so our edit is left
# behind in the old name. Neither one fails the build. This script catches both.
#
#   ag-tools/check-customizations.sh inventory
#       Lists every modules/ file where we differ from upstream JUCE and FAILS if any
#       of them has no entry in AG-CUSTOMIZATIONS.md. Run it any time; run it after
#       adding a new edit to JUCE so the notes stay complete.
#
#   ag-tools/check-customizations.sh survived <pre-update-ref>
#       Run AFTER merging a new JUCE release. <pre-update-ref> is our branch as it was
#       just before the update (tag it first: git tag ag-pre-update-<ver>). For every
#       line we had added to JUCE before the update, checks that the line is still
#       present now. Missing lines are printed per file, and the script FAILS.
#       A missing line is not automatically wrong (JUCE may now do the same thing
#       itself, e.g. the Wine fix), but every one needs a decision, not silence.
#
# Options:
#   --base <ref>   upstream commit to compare against, instead of working it out as
#                  merge-base(<ref>, upstream/master). Needed if there is no `upstream`
#                  remote (git remote add upstream https://github.com/juce-framework/JUCE.git).
#
# Exit 0 = clean, 1 = something needs a decision, 2 = usage / setup error.
# Whitespace-only differences are ignored throughout.

set -u
cd "$(dirname "$0")/.." || exit 2
NOTES="AG-CUSTOMIZATIONS.md"

die() { echo "ERROR: $*" >&2; exit 2; }

mode="${1:-}"; shift || true
ref=""; base=""
while [ $# -gt 0 ]; do
    case "$1" in
        --base) base="${2:-}"; shift 2 ;;
        *) [ -z "$ref" ] && ref="$1" || die "unexpected argument: $1"; shift ;;
    esac
done

find_base() {   # $1 = our ref
    if [ -n "$base" ]; then echo "$base"; return; fi
    git rev-parse -q --verify upstream/master >/dev/null \
        || die "no upstream/master. Add the remote and fetch:
  git remote add upstream https://github.com/juce-framework/JUCE.git && git fetch upstream
or pass --base <upstream tag/commit>."
    git merge-base "$1" upstream/master || die "no merge base between $1 and upstream/master"
}

changed_files() {   # $1 = base, $2 = ref (omit for the working tree)
    # modules/ files that differ beyond whitespace. --name-only ignores -w, so each
    # candidate is re-checked for a real hunk.
    git diff --name-only "$@" -- modules | while IFS= read -r f; do
        git diff -w --ignore-blank-lines "$@" -- "$f" | grep -q '^@@' && echo "$f"
    done
}

case "$mode" in
inventory)
    [ -f "$NOTES" ] || die "$NOTES not found"
    b=$(find_base HEAD)
    echo "Comparing the working tree with upstream $(git describe --tags "$b" 2>/dev/null || echo "$b")"
    missing=0; n=0
    while IFS= read -r f; do
        n=$((n+1))
        if grep -qF "\`$f\`" "$NOTES"; then
            echo "  ok        $f"
        else
            echo "  UNNOTED   $f"; missing=$((missing+1))
        fi
    done <<EOF
$(changed_files "$b")
EOF
    echo
    if [ "$missing" -gt 0 ]; then
        echo "FAIL: $missing of $n changed file(s) have no entry in $NOTES."
        echo "Add an entry (what it does, why, who uses it) before the next JUCE update."
        exit 1
    fi
    echo "OK: all $n changed file(s) are documented in $NOTES."
    ;;

survived)
    [ -n "$ref" ] || die "usage: $0 survived <pre-update-ref>"
    git rev-parse -q --verify "$ref^{commit}" >/dev/null || die "unknown ref: $ref"
    b=$(find_base "$ref")
    echo "Our edits as of $ref, relative to upstream $(git describe --tags "$b" 2>/dev/null || echo "$b")"
    echo "Checking each added line is still present in the working tree."
    echo
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    lost_total=0; files_hit=0
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        # lines we added (normalised: all whitespace removed), minus trivial ones
        git diff -w --ignore-blank-lines "$b" "$ref" -- "$f" \
            | sed -n 's/^+\([^+].*\)$/\1/p; s/^+$//p' \
            | tr -d ' \t\r' \
            | awk 'length($0) >= 6 && $0 !~ /^(#endif|#else|@end|break;|return;|\}\)?;?|\/\/+)$/' \
            | sort -u > "$tmp/added"
        [ -s "$tmp/added" ] || continue
        if [ ! -f "$f" ]; then
            echo "  GONE      $f  (file no longer exists: JUCE probably renamed or moved it."
            echo "            Find its new name and re-apply our edit there.)"
            sed 's/^/              - /' "$tmp/added" | head -8
            lost_total=$((lost_total + $(wc -l < "$tmp/added"))); files_hit=$((files_hit+1))
            continue
        fi
        tr -d ' \t\r' < "$f" | sort -u > "$tmp/now"
        comm -23 "$tmp/added" "$tmp/now" > "$tmp/lost"
        if [ -s "$tmp/lost" ]; then
            c=$(wc -l < "$tmp/lost" | tr -d ' ')
            echo "  MISSING   $f  ($c of $(wc -l < "$tmp/added" | tr -d ' ') added line(s))"
            sed 's/^/              - /' "$tmp/lost" | head -8
            lost_total=$((lost_total + c)); files_hit=$((files_hit+1))
        else
            echo "  ok        $f"
        fi
    done <<EOF
$(changed_files "$b" "$ref")
EOF
    echo
    if [ "$lost_total" -gt 0 ]; then
        echo "FAIL: $lost_total line(s) of our edits are missing, in $files_hit file(s)."
        echo "For each: re-apply it, or confirm JUCE now does the same thing and mark it"
        echo "retired in AG-CUSTOMIZATIONS.md. Lines shown with whitespace removed."
        exit 1
    fi
    echo "OK: every edit we had before the update is still present."
    ;;

*)
    sed -n '2,30p' "$0"; exit 2 ;;
esac
