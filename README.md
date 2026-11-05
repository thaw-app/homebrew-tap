# homebrew-tap

Homebrew casks for Thaw that Homebrew's main cask repository can't carry.

## Thaw 2

Thaw 3 needs macOS 27, and Homebrew's `thaw` cask moves to it when 3.0.0 is released. Thaw 2 keeps running on macOS 26, and from 2.2 on macOS 15 too. Install it from this tap:

```sh
brew tap thaw-app/tap
brew trust --cask thaw-app/tap/thaw@2
brew install --cask thaw-app/tap/thaw@2
```

Homebrew 7 loads casks from a tap only after you trust them, which is what the second line does.

`thaw@2` follows stable 2.x releases only. It can't be installed next to `thaw` or `thaw@beta`, since all three install the same `Thaw.app`. Thaw updates itself once installed, so Homebrew leaves upgrades to it.

## How the cask stays current

The [Bump thaw@2](.github/workflows/bump.yml) workflow runs every day, and on demand from its Actions page. When [thaw-app/Thaw](https://github.com/thaw-app/Thaw/releases) has a newer stable 2.x release, [`scripts/bump-thaw-2.sh`](scripts/bump-thaw-2.sh) opens a pull request with the new version and checksum. Check `depends_on macos` against the release notes before merging: the bump changes only the version and checksum.

[Cask checks](.github/workflows/cask-checks.yml) runs `brew style`, `brew audit --strict --online`, `brew livecheck` and a dry run of the bump script on every pull request. A pull request the bump workflow opens doesn't start it, because GitHub doesn't run workflows for changes made with a workflow's own token. Run Cask checks on the bump branch from its Actions page.

To try a change locally, link the checkout into Homebrew's taps and trust it:

```sh
mkdir -p "$(brew --repository)/Library/Taps/thaw-app"
ln -s "$PWD" "$(brew --repository)/Library/Taps/thaw-app/homebrew-tap"
brew trust --cask thaw-app/tap/thaw@2
brew audit --cask --strict --online thaw-app/tap/thaw@2
DRY_RUN=1 scripts/bump-thaw-2.sh
```

The tap's repository settings are managed by [platform](https://github.com/thaw-app/platform).
