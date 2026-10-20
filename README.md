[![Python 3.12](https://img.shields.io/badge/python-3.12-blue.svg)](https://www.python.org/downloads/release/python-3128/)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![Dependabot](https://badgen.net/badge/Dependabot/enabled/green?icon=dependabot)](https://dependabot.com/)
![Coverage](coverage.svg)
![Security Review](https://img.shields.io/badge/Security_Review-Missing-red?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iI2ZmZiIgc3Ryb2tlPSJjdXJyZW50Q29sb3IiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBjbGFzcz0iZmVhdGhlciBmZWF0aGVyLXNoaWVsZC1jaGVjayI+PHBhdGggZD0iTTEyIDIyczgtNCA4LTEwVjVsLTgtMy04IDN2N2MwIDYgOCAxMCA4IDEweiI+PC9wYXRoPjxwb2x5bGluZSBwb2ludHM9IjkgMTIgMTEgMTQgMTUgMTAiPjwvcG9seWxpbmU+PC9zdmc+)

> [!IMPORTANT]
>
> Run `make init` for first-time setup, then delete this section.

# project_name_to_change
...

## Install

This project requires:
- [OpenTofu](https://opentofu.org/docs/intro/install/) to manage the infrastructure.
- [Docker](https://docs.docker.com/engine/install/) to handle building of images.
- [Node](https://nodejs.org/en/download) to install the AI assistant skills.
- Access to the Ivado Labs [private registry](docs/registry.md) on GCP Artifact Registry, which serves Ivado Labs libraries such as the pre-installed [`kickstart`](https://github.com/ivado-labs/kickstart).

Then set up the project:
```bash
make setup
```

Finally, [install the AI assistant skills](https://github.com/ivado-labs/il-skills#get-started).

## Usage

To run tests, run:
```bash
make test
```

To pin and update supply-chain references (Docker, curl, etc), run:
```bash
make secure                 # run all security maintenance targets
make secure-supply-chain    # run only supply-chain maintenance
```

The secure-supply-chain target runs `uv run il-supply-chain-security auto-pin` with the
tool's default 7 days cooldown. Review and commit its changes, including
`il-supply-chain-security.json` and `scripts/secure-curl.sh` when generated.

<details>
<summary><strong>Environment Configuration</strong></summary>

This project uses per-environment `.env` files with a symlink for easy switching.

- `.env` — Symlink to the active environment file
- `.env.local` — Local development (auto-created by `make setup`)
- `.env.example` — Template with all variables (tracked in git)
- `.env.<name>` — Additional environments, created via `make env`

```bash
make env            # switch or create environments (interactive)
make env-current    # show active environment
```

New environments are created with mandatory defaults only — add your own vars from `.env.example`. Switching to an existing environment only re-points the symlink.

> **Note:** All `.env.*` files (except `.env.example`) are gitignored. Never commit credentials.

</details>

## Docs
- [Conventions](docs/conventions.md) — Git flow, CI/CD workflows, branching, and commit conventions
- [uv](docs/uv.md)
- [Ivado Labs Registry](docs/registry.md)
- [AI assistants](docs/agents/assistants.md)
- [CI/CD Setup](docs/cicd_setup.md)
