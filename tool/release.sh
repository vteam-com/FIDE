#!/bin/bash
# Releases FIDE: sets the new version in pubspec.yaml, adds the release to
# CHANGELOG.md (one line per commit since the last release), checks and
# builds the code, then commits, tags and pushes it. The pushed tag starts
# the Release workflow, which builds macOS, Windows and Linux and publishes
# them as the latest GitHub Release, the README's downloads.
#
# Usage: tool/release.sh <major|minor|patch|X.Y.Z>
#   patch  1.2.3 -> 1.2.4      minor  1.2.3 -> 1.3.0
#   major  1.2.3 -> 2.0.0      X.Y.Z  that exact version
# The build number (after the +) goes up by one on every release.

set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=tool/fcheck.env
. tool/fcheck.env

RELEASE_BRANCH="main"
REMOTE="origin"
PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"
# The commits that only set a version, left out of the changelog
RELEASE_COMMIT='^Release v'

fail() {
	echo "Release stopped: $*" >&2
	exit 1
}

usage() {
	sed -n '/^# Usage:/,/^$/s/^# \{0,1\}//p' "$0" >&2
	exit 1
}

# Escapes the Markdown of each line outside its `code` spans, so a <tag>,
# a * or a \ in a commit subject shows as written
markdown_text() {
	awk -F'`' -v OFS='`' '{ for (i = 1; i <= NF; i += 2) gsub(/[\\<*]/, "\\\\&", $i); print }'
}

[ $# -eq 1 ] || usage

# --- The new version ----------------------------------------------------
current="$(sed -n 's/^version: *//p' "$PUBSPEC")"
[ -n "$current" ] || fail "no version in $PUBSPEC"
current_name="${current%%+*}"
current_build="0"
[[ "$current" == *+* ]] && current_build="${current#*+}"
IFS=. read -r major minor patch <<<"$current_name"

case "$1" in
	major) version="$((major + 1)).0.0" ;;
	minor) version="$major.$((minor + 1)).0" ;;
	patch) version="$major.$minor.$((patch + 1))" ;;
	[0-9]*.[0-9]*.[0-9]*)
		[[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage
		version="$1"
		;;
	*) usage ;;
esac
build="$((current_build + 1))"
tag="v$version"
previous_tag="v$current_name"

# --- The repository is ready ----------------------------------------------
[ "$(git branch --show-current)" = "$RELEASE_BRANCH" ] ||
	fail "releases are made from $RELEASE_BRANCH"
[ -z "$(git status --porcelain)" ] ||
	fail "commit or stash your changes first"
[ -f "$CHANGELOG" ] || fail "no $CHANGELOG"
git fetch --quiet --tags "$REMOTE" "$RELEASE_BRANCH"
# Commits not pushed yet go out with the release; commits only on the
# remote would get the push at the end rejected, after the build
git merge-base --is-ancestor "$REMOTE/$RELEASE_BRANCH" HEAD ||
	fail "$REMOTE/$RELEASE_BRANCH has commits $RELEASE_BRANCH lacks: pull first"

# The remote holds the releases: a tag found only here was never pushed, so
# it is left over from an earlier try and the release moves it
[ -z "$(git ls-remote --tags "$REMOTE" "refs/tags/$tag")" ] ||
	fail "$tag is already released on $REMOTE"
stale_tag="$(git log -1 --format='%h %s' "refs/tags/$tag" 2>/dev/null || true)"

# --- The changelog ----------------------------------------------------------
git rev-parse --quiet --verify "refs/tags/$previous_tag" >/dev/null ||
	fail "no tag $previous_tag for $PUBSPEC's version $current_name"
git merge-base --is-ancestor "$previous_tag" HEAD ||
	fail "$previous_tag is not in $RELEASE_BRANCH's history"
changes="$(git log --no-merges --format='%s' "$previous_tag..HEAD" |
	{ grep -v "$RELEASE_COMMIT" || true; } | markdown_text | sed 's/^/- /')"
[ -n "$changes" ] || fail "nothing to release: no commits since $previous_tag"
section="## $version - $(date +%Y-%m-%d)

$changes"

printf '%s\n\n' "$section"
[ -z "$stale_tag" ] ||
	echo "Tag $tag, never pushed, moves from $stale_tag to this release"
printf 'Release %s -> %s+%s with this %s entry, tagged %s? [y/N] ' \
	"$current" "$version" "$build" "$CHANGELOG" "$tag"
read -r answer
[[ "$answer" =~ ^[Yy]$ ]] || fail "cancelled"

# --- Set the version and the changelog, then check and build ---------------
# Until the commit, any failure puts both files back as they were
trap 'git checkout --quiet -- "$PUBSPEC" "$CHANGELOG"' EXIT
sed -i.bak "s/^version: .*/version: $version+$build/" "$PUBSPEC"
rm "$PUBSPEC.bak"
# The new release goes above the one before, under the file's introduction
SECTION="$section" awk '
	!added && /^## / { print ENVIRON["SECTION"]; print ""; added = 1 }
	{ print }
	END { if (!added) { print ""; print ENVIRON["SECTION"] } }
' "$CHANGELOG" >"$CHANGELOG.new"
mv "$CHANGELOG.new" "$CHANGELOG"

echo "--- Pub Get"
flutter pub get >/dev/null
echo "--- Analyze"
flutter analyze --no-pub
echo "--- Test"
flutter test --no-pub --reporter=compact
echo "--- fCheck"
dart pub global activate fcheck "$FCHECK_VERSION" >/dev/null
dart pub global run fcheck --strict
echo "--- Build macOS"
flutter build macos --release

others="$(git status --porcelain -- ":(exclude)$PUBSPEC" ":(exclude)$CHANGELOG")"
[ -z "$others" ] ||
	fail "the checks changed more files than $PUBSPEC and $CHANGELOG: $(echo "$others" | tr '\n' ' ')"

# --- Commit, tag and push ----------------------------------------------------
git commit --quiet -m "Release $tag" -- "$PUBSPEC" "$CHANGELOG"
trap - EXIT
# --force moves a tag never pushed (stale_tag); one on the remote stopped above
git tag --force -a "$tag" -m "FIDE $version" >/dev/null
git push --atomic "$REMOTE" "$RELEASE_BRANCH" "$tag" ||
	fail "push failed; $tag is committed and tagged here, retry with: git push --atomic $REMOTE $RELEASE_BRANCH $tag"

echo "Released $tag: the Release workflow now builds and publishes it"
echo "https://github.com/vteam-com/FIDE/actions/workflows/release.yml"
