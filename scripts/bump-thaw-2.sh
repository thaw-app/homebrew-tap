#!/usr/bin/env bash
# Opens a pull request that moves Casks/thaw@2.rb to the newest stable 2.x
# release of thaw-app/Thaw. Does nothing when the cask is current or a bump
# pull request for that version is already open.
#
# Needs gh (authenticated through GH_TOKEN), curl, perl and shasum or sha256sum.
# DRY_RUN=1 reports the bump without writing, committing or pushing.

set -euo pipefail

repo="thaw-app/Thaw"
cask="Casks/thaw@2.rb"

current=$(perl -ne 'print $1 if /^\s*version "([^"]+)"/' "${cask}")
if [[ -z "${current}" ]]
then
  echo "No version line in ${cask}" >&2
  exit 1
fi

# Stable 2.x tags only: Thaw 3 needs macOS 27, and pre-releases go to thaw@beta.
latest=$(gh release list --repo "${repo}" --exclude-pre-releases --exclude-drafts --limit 200 \
  --json tagName --jq '.[].tagName' |
  grep -E '^2\.[0-9]+(\.[0-9]+)*$' |
  sort -V |
  tail -n 1 || true)
if [[ -z "${latest}" ]]
then
  echo "No stable 2.x release found in ${repo}" >&2
  exit 1
fi

newest=$(printf '%s\n%s\n' "${current}" "${latest}" | sort -V | tail -n 1)
if [[ "${latest}" == "${current}" || "${newest}" != "${latest}" ]]
then
  echo "thaw@2 is current at ${current}"
  exit 0
fi

branch="bump/thaw-2-${latest}"
open_pr=$(gh pr list --head "${branch}" --state open --json number --jq '.[].number')
if [[ -n "${open_pr}" ]]
then
  echo "A pull request for ${latest} is already open"
  exit 0
fi

asset="Thaw_${latest}.zip"
url="https://github.com/${repo}/releases/download/${latest}/${asset}"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
curl --fail --silent --show-error --location --output "${workdir}/${asset}" "${url}"
if command -v sha256sum >/dev/null
then
  sha=$(sha256sum "${workdir}/${asset}" | cut -d ' ' -f 1)
else
  sha=$(shasum -a 256 "${workdir}/${asset}" | cut -d ' ' -f 1)
fi

echo "Bumping thaw@2 from ${current} to ${latest} (sha256 ${sha})"
if [[ "${DRY_RUN:-0}" == "1" ]]
then
  exit 0
fi

perl -pi -e "s/^(\s*version )\"[^\"]+\"/\$1\"${latest}\"/; s/^(\s*sha256 )\"[^\"]+\"/\$1\"${sha}\"/" "${cask}"

git switch --create "${branch}"
git add "${cask}"
git commit --signoff --message "thaw@2 ${latest}"
git push --set-upstream origin "${branch}"

body="Moves \`thaw@2\` from ${current} to [${latest}](https://github.com/${repo}/releases/tag/${latest}).

- sha256 of \`${asset}\`: \`${sha}\`
- Check \`depends_on macos\` against the release notes. The bump only changes the version and checksum.

Opened by the bump workflow. Pull requests opened with the workflow token don't start other workflows, so run Cask checks from its Actions page before merging."

gh pr create --base main --head "${branch}" --title "thaw@2 ${latest}" --body "${body}"
