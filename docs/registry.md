# Ivado Labs Registry

Ivado Labs libraries (e.g. `il-kickstart`) are distributed via a private GCP Artifact Registry. Projects must authenticate before installing or resolving these packages.

## Authentication

Before running `make setup`, authenticate with gcloud (one-time, per machine):
```bash
gcloud auth login
gcloud auth application-default login
```

`make setup` installs [`keyrings.google-artifactregistry-auth`](https://pypi.org/project/keyrings.google-artifactregistry-auth/) automatically, which lets `uv` resolve and pull packages from the Ivado Labs registry without any further configuration.

For CI pipelines, authentication is already handled — the CI workflow authenticates via Workload Identity Federation using `google-github-actions/auth` before running `make setup`.

## Vendoring (client handovers)

> [!IMPORTANT]
> All Ivado Labs registry packages **must be vendored** before handing over a project to a client. Vendoring ensures the project remains fully self-contained.

When vendoring, the package source is downloaded locally and `pyproject.toml` is updated to point to the local copy instead of the registry.

To vendor a package:
```bash
make vendor-package PKG=il-kickstart
```

This will:
1. Resolve the installed version from the `uv` lockfile.
2. Verify your `gcloud` credentials.
3. Download the source tarball from the Artifact Registry.
4. Extract it into `vendor/`.
5. Update `pyproject.toml` to reference the local vendored path.

After vendoring, run `uv sync` to install from the local source:
```bash
uv sync
```

The `vendor/` directory should be committed to version control so the client environment can install without any registry access.
