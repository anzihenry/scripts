---
title: macOS Automation Scripts
status: current
owner: project-maintainers
updated: 2026-10-10
---

# macOS Automation Scripts

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Shell automation for macOS 14+: developer environment setup, Homebrew maintenance, macOS installer creation, and launchd jobs. The unified CLI uses the system Bash 3.2 and Zsh and provides colored logs, timing, idempotent checks, and dry-run support. See [VERSION](VERSION) for the source version.

## Quick start

```bash
git clone https://github.com/anzihenry/scripts.git
cd scripts
./bin/macos-scripts --help
./bin/macos-scripts maintain brew --dry-run
```

With Homebrew already installed, install through the tap:

```bash
brew tap anzihenry/scripts https://github.com/anzihenry/scripts
brew install anzihenry/scripts/macos-scripts
macos-scripts --help
```

See the [installation guide](docs/guides/installation.en.md) for fresh machines and piped bootstrap.

## Documentation

- [Documentation map](docs/README.en.md), [documentation conventions](docs/documentation.en.md)
- [Usage and maintenance](docs/guides/using.en.md), [scheduled jobs](docs/guides/jobs.en.md)
- [Development and validation](docs/guides/development.en.md), [architecture](docs/engineering/architecture.en.md)
- [Planning](docs/planning/README.en.md), [initiatives](docs/initiatives/README.en.md)
- [Releasing](docs/guides/releasing.en.md), [version records](docs/releases/README.en.md), [CHANGELOG](CHANGELOG.en.md)

Agent collaboration rules are in [AGENTS.md](AGENTS.md) (Chinese). Contributors follow the [code of conduct](.github/CODE_OF_CONDUCT.md) (Chinese).

## License

[MIT](LICENSE).
