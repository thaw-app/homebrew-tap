# homebrew-tap

Homebrew casks for Thaw 2, which Homebrew's main cask repository can't carry.

## Thaw 2

Thaw 3 needs macOS 27, and Homebrew's `thaw` cask moves to it when 3.0.0 is released. Thaw 2 keeps running on macOS 26, and from 2.2 on macOS 15 too. This tap has one cask for each of Thaw 2's update channels:

| Cask | Follows | macOS |
| --- | --- | --- |
| `thaw@2` | stable 2.x releases | 26, and 15 from 2.2 |
| `thaw@2-beta` | 2.x betas and release candidates, and stable 2.x when it's newer | 15 and later |

Install one of them:

```sh
brew tap thaw-app/tap
brew trust --cask thaw-app/tap/thaw@2
brew install --cask thaw-app/tap/thaw@2
```

For the beta channel, use `thaw@2-beta` in the last two lines. Homebrew 7 loads casks from a tap only after you trust them, which is what the second line does.

Neither cask has a maximum macOS. On macOS 27, Thaw 2 opens with a warning that offers Thaw 3 through its beta updates, but `brew install thaw@beta` is the direct route there.

All Thaw casks install the same `Thaw.app`, so `thaw@2`, `thaw@2-beta`, `thaw` and `thaw@beta` can't be installed side by side. Thaw updates itself once installed, so Homebrew leaves upgrades to it.

## How the casks stay current

The [Bump Thaw 2 casks](.github/workflows/bump.yml) workflow runs every day, and on demand from its Actions page. When [thaw-app/Thaw](https://github.com/thaw-app/Thaw/releases) has a newer release on a cask's channel, [`scripts/bump-cask.sh`](scripts/bump-cask.sh) opens a pull request. It sets the version, the checksum, and `depends_on macos` from the app's minimum macOS.

[Cask checks](.github/workflows/cask-checks.yml) runs `brew style`, `brew audit --strict --online`, `brew livecheck` and a dry run of the bump script on every pull request. A pull request the bump workflow opens doesn't start it, because GitHub doesn't run workflows for changes made with a workflow's own token. Run Cask checks on the bump branch from its Actions page.

`thaw@2-beta` points at GitHub pre-releases, which Homebrew's audit rejects by default. [`audit_exceptions/github_prerelease_allowlist.json`](audit_exceptions/github_prerelease_allowlist.json) allows them for that cask.

To try a change locally, link the checkout into Homebrew's taps and trust it:

```sh
mkdir -p "$(brew --repository)/Library/Taps/thaw-app"
ln -s "$PWD" "$(brew --repository)/Library/Taps/thaw-app/homebrew-tap"
brew trust --cask thaw-app/tap/thaw@2 thaw-app/tap/thaw@2-beta
brew audit --cask --strict --online thaw-app/tap/thaw@2 thaw-app/tap/thaw@2-beta
DRY_RUN=1 scripts/bump-cask.sh thaw@2-beta
```

Run `brew style thaw-app/tap` without `--fix`: its fixer rewrites this README's code blocks.

The tap's repository settings are managed by [platform](https://github.com/thaw-app/platform).
