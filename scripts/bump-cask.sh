#!/usr/bin/env bash
# Opens a pull request that moves one Thaw 2 cask to the newest release on its
# channel: thaw@2 follows stable 2.x, thaw@2-beta adds betas and release
# candidates. Sets version, sha256 and depends_on macos from the release zip.
# Does nothing when the cask is current or a bump pull request is already open.
#
# Usage: scripts/bump-cask.sh thaw@2|thaw@2-beta
# Needs gh (authenticated through GH_TOKEN), curl, unzip and perl.
# DRY_RUN=1 reports the bump without writing, committing or pushing.

set -euo pipefail

token="${1:?usage: scripts/bump-cask.sh thaw@2|thaw@2-beta}"
repo="thaw-app/Thaw"
cask="Casks/${token}.rb"

case "${token}" in
  thaw@2) pattern='^2\.[0-9]+(\.[0-9]+)*$' ;;
  thaw@2-beta) pattern='^2\.[0-9]+(\.[0-9]+)*(-(beta|rc)[._-]?[0-9]+(\.[0-9]+)*)?$' ;;
  *)
    echo "Unknown cask ${token}" >&2
    exit 1
    ;;
esac

# Prints the highest version read from stdin. Pre-releases sort below their
# release (2.2.0-beta.1 < 2.2.0-rc.1 < 2.2.0), which sort -V gets wrong.
highest_version() {
  perl -e '
    sub key {
      my ($v) = @_;
      my ($core, $kind, $num) = $v =~ /^([\d.]+)(?:-(alpha|nightly|beta|rc)[._-]?([\d.]+))?$/ or return;
      my %rank = (alpha => 0, nightly => 0, beta => 1, rc => 2);
      return [ (map { 0 + $_ } split /\./, $core), -1, (defined $kind ? $rank{$kind} : 3), map { 0 + $_ } split /\./, ($num // "0") ];
    }
    sub cmp_keys {
      my ($a, $b) = @_;
      for my $i (0 .. ($#$a > $#$b ? $#$a : $#$b)) {
        my $c = ($a->[$i] // 0) <=> ($b->[$i] // 0);
        return $c if $c;
      }
      return 0;
    }
    my ($best, $best_key);
    while (my $v = <STDIN>) {
      chomp $v;
      my $k = key($v) or next;
      ($best, $best_key) = ($v, $k) if !defined $best_key || cmp_keys($k, $best_key) > 0;
    }
    print $best // "";
  '
}

# The Homebrew symbol for the macOS an app's LSMinimumSystemVersion names, or
# nothing for a version this script doesn't know.
macos_symbol() {
  case "${1%%.*}" in
    13) echo ventura ;;
    14) echo sonoma ;;
    15) echo sequoia ;;
    26) echo tahoe ;;
    27) echo golden_gate ;;
    *) echo "" ;;
  esac
}

current=$(perl -ne 'print $1 if /^\s*version "([^"]+)"/' "${cask}")
if [[ -z "${current}" ]]
then
  echo "No version line in ${cask}" >&2
  exit 1
fi

tags=$(gh release list --repo "${repo}" --exclude-drafts --limit 1000 --json tagName --jq '.[].tagName')
matching=$(grep -E "${pattern}" <<<"${tags}" || true)
latest=$(highest_version <<<"${matching}")
if [[ -z "${latest}" ]]
then
  echo "No ${token} release found in ${repo}" >&2
  exit 1
fi

newest=$(printf '%s\n%s\n' "${current}" "${latest}" | highest_version)
if [[ "${latest}" == "${current}" || "${newest}" != "${latest}" ]]
then
  echo "${token} is current at ${current}"
  exit 0
fi

prefix="bump/${token/@/-}-"
branch="${prefix}${latest}"
open_branches=$(gh pr list --state open --limit 100 --json headRefName --jq ".[].headRefName | select(startswith(\"${prefix}\"))")
if grep -qxF "${branch}" <<<"${open_branches}"
then
  echo "A pull request for ${token} ${latest} is already open"
  exit 0
fi
# An older bump for this cask is superseded once the newer one opens.
superseded=$(grep -vxF "${branch}" <<<"${open_branches}" || true)

asset="Thaw_${latest}.zip"
url="https://github.com/${repo}/releases/download/${latest}/${asset}"
workdir=$(mktemp -d)
trap 'rm -rf "${workdir}"' EXIT
curl --fail --silent --show-error --location --output "${workdir}/${asset}" "${url}"
if command -v sha256sum >/dev/null
then
  sha=$(sha256sum "${workdir}/${asset}" | cut -d ' ' -f 1)
else
  sha=$(shasum -a 256 "${workdir}/${asset}" | cut -d ' ' -f 1)
fi

unzip -p "${workdir}/${asset}" "Thaw.app/Contents/Info.plist" >"${workdir}/Info.plist"
minimum=$(perl -0ne 'print $1 if m{<key>LSMinimumSystemVersion</key>\s*<string>([^<]+)</string>}' "${workdir}/Info.plist")
macos=$(macos_symbol "${minimum}")
if [[ -z "${macos}" ]]
then
  echo "No Homebrew macOS symbol for LSMinimumSystemVersion ${minimum:-missing}" >&2
  exit 1
fi

echo "Bumping ${token} from ${current} to ${latest} (sha256 ${sha}, macOS ${minimum} :${macos})"
if [[ "${DRY_RUN:-0}" == "1" ]]
then
  if [[ -n "${superseded}" ]]
  then
    echo "Would close superseded bump pull requests: ${superseded//$'\n'/ }"
  fi
  exit 0
fi

perl -pi -e "s/^(\s*version )\"[^\"]+\"/\$1\"${latest}\"/; s/^(\s*sha256 )\"[^\"]+\"/\$1\"${sha}\"/; s/^(\s*depends_on macos: ):\w+/\$1:${macos}/" "${cask}"

# -C and --force-with-lease let a run that stopped after pushing start over in the same clone.
git switch -C "${branch}"
git add "${cask}"
git commit --signoff --message "${token} ${latest}"
git push --force-with-lease --set-upstream origin "${branch}"

body="Moves \`${token}\` from ${current} to [${latest}](https://github.com/${repo}/releases/tag/${latest}).

- sha256 of \`${asset}\`: \`${sha}\`
- \`depends_on macos: :${macos}\`, from the app's LSMinimumSystemVersion ${minimum}

Opened by the bump workflow. Pull requests opened with the workflow token don't start other workflows, so run Cask checks from its Actions page before merging."

url_new=$(gh pr create --base main --head "${branch}" --title "${token} ${latest}" --body "${body}")
echo "${url_new}"
while read -r old
do
  [[ -z "${old}" ]] && continue
  gh pr close "${old}" --delete-branch --comment "Superseded by ${url_new}."
done <<<"${superseded}"
