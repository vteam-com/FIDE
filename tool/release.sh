#!/bin/bash
# Releases FIDE: sets the new version in pubspec.yaml, checks and builds
# the code, then commits, tags and pushes it. The pushed tag starts the
# Release workflow, which builds macOS, Windows and Linux and publishes
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

fail() {
	echo "Release stopped: $*" >&2
	exit 1
}

usage() {
	sed -n '7,10p' "$0" | sed 's/^# \{0,1\}//' >&2
	exit 1
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

# --- The repository is ready ----------------------------------------------
[ "$(git branch --show-current)" = "$RELEASE_BRANCH" ] ||
	fail "releases are made from $RELEASE_BRANCH"
[ -z "$(git status --porcelain)" ] ||
	fail "commit or stash your changes first"
git fetch --quiet --tags "$REMOTE" "$RELEASE_BRANCH"
[ "$(git rev-parse HEAD)" = "$(git rev-parse "$REMOTE/$RELEASE_BRANCH")" ] ||
	fail "$RELEASE_BRANCH differs from $REMOTE/$RELEASE_BRANCH: pull or push first"
! git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null ||
	fail "tag $tag already exists"

printf 'Release %s -> %s+%s, tagged %s? [y/N] ' "$current" "$version" "$build" "$tag"
read -r answer
[[ "$answer" =~ ^[Yy]$ ]] || fail "cancelled"

# --- Set the version, then check and build ---------------------------------
# Until the commit, any failure puts pubspec.yaml back as it was
trap 'git checkout --quiet -- "$PUBSPEC"' EXIT
sed -i.bak "s/^version: .*/version: $version+$build/" "$PUBSPEC"
rm "$PUBSPEC.bak"

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

[ "$(git status --porcelain)" = " M $PUBSPEC" ] ||
	fail "the checks changed more files than $PUBSPEC: $(git status --porcelain | tr '\n' ' ')"

# --- Commit, tag and push ----------------------------------------------------
git commit --quiet -m "Release $tag" -- "$PUBSPEC"
trap - EXIT
git tag -a "$tag" -m "FIDE $version"
git push --atomic "$REMOTE" "$RELEASE_BRANCH" "$tag" ||
	fail "push failed; $tag is committed and tagged here, retry with: git push --atomic $REMOTE $RELEASE_BRANCH $tag"

echo "Released $tag: the Release workflow now builds and publishes it"
echo "https://github.com/vteam-com/FIDE/actions/workflows/release.yml"
