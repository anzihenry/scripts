---
title: macOS Automation Scripts
status: current
owner: project-maintainers
updated: 2026-10-17
---

# macOS Automation Scripts

[中文](README.md)

Translation of the Chinese primary version. Commands and historical log excerpts retain their original language where applicable.

Shell automation for macOS 14+: developer environment setup, Homebrew maintenance, and macOS installer creation. The unified CLI uses the system Zsh and provides colored logs, timing, idempotent checks, and dry-run support. See [VERSION](VERSION) for the source version.

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
- [Usage and maintenance](docs/guides/using.en.md)
- [Development and validation](docs/guides/development.en.md), [architecture](docs/engineering/architecture.en.md)
- [Planning](docs/planning/README.en.md), [initiatives](docs/initiatives/README.en.md)
- [Releasing](docs/guides/releasing.en.md), [version records](docs/releases/README.en.md), [CHANGELOG](CHANGELOG.en.md)

Agent collaboration rules are in [AGENTS.md](AGENTS.md) (Chinese). Contributors follow the [code of conduct](.github/CODE_OF_CONDUCT.md) (Chinese).

## License

[MIT](LICENSE).

## Start a new Zsh project

Use `zsh tools/create_zsh_project.sh --name my-tool --description "My macOS tool" /path/to/new-project`. The generator refuses existing destinations and creates an independent CLI with metadata, pinned offline zsh-kit, tests and CI. See [component contracts](packages/zsh-kit/README.md) and the [development guide](docs/guides/development.en.md).

See [file-organizer](examples/file-organizer/README.md) for an independently runnable generated example with dry-run, idempotence, conflict protection, recovery and offline upgrade acceptance.
