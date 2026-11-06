#!/bin/bash

set -e

### Update debian/changelog from the latest upstream KernelSU release.

get_redirected() {
  if command -v curl >/dev/null; then
    curl -Ls -w '%{url_effective}' -o /dev/null "$1"
  elif command -v wget >/dev/null; then
    wget -O /dev/null "$1" 2>&1 | grep "Location: " | head -1 | cut -f2
  else
    echo "Could not find curl or wget" >&2
    return 1
  fi
}

# Get latest upstream version
url=https://github.com/tiann/KernelSU

_upstream_version=$(get_redirected "$url/releases/latest")
_upstream_version=${_upstream_version##*/}

echo "Latest upstream release: $_upstream_version"

# The source format is 3.0 (native), whose version must not contain a Debian
# revision: v3.3.0-2 -> 3.3.0+2
_newver=${_upstream_version#v}
_newver=${_newver//-/+}
if [ -z "$_newver" ] || [ "$_newver" = "$_upstream_version" ]; then
  echo "Could not determine the upstream version" >&2
  exit 1
fi

_current=$(dpkg-parsechangelog -SVersion)
if [ "$_newver" = "$_current" ]; then
  echo "Already at version $_newver, nothing to do."
  exit 0
fi

# Update debian/changelog
dch -v "$_newver" -D unstable "Bumped to upstream $_upstream_version."

# Verify that the new version still builds as a .deb
if ! dpkg-buildpackage -us -uc -b; then
  echo "Error: dpkg-buildpackage failed with the updated changelog." >&2
  exit 1
fi

## Update repo

git add debian/changelog

# Check git signing option
commit_flags=()
if git config --get commit.gpgSign | grep -q 'true'; then
  commit_flags=(-S)
fi

git commit "${commit_flags[@]}" -m "Bumped version to $_newver"

# Push commit
git push origin master
