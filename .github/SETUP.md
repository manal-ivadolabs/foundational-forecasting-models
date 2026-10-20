# GitHub Actions Setup

## General

- Update `zensical.toml` (the docs configuration)
- Modify [CODEOWNERS](../../CODEOWNERS) by adding your team members or GitHub group

## Workflow Permissions

Allow workflows to push tags and create releases:

**Settings > Actions > General > Workflow permissions > Read and write permissions**

## Dependabot

Enable vulnerability alerts and automated security updates:

**Settings > Advanced Security** — enable the ones you want

## Slack Notifications

To enable GitHub notifications in your project's Slack channel:

1. Open (or create) your project's development Slack channel
2. `/invite @github`
3. `/github subscribe [repository name]`

See [GitHub Slack integration docs](https://github.com/integrations/slack?tab=readme-ov-file#installation) for customization options.

## Docs (optional)

If the repository is for internal initiatives, we provide hosting on GCP.
If it's not the case, then remove the `deploy-docs` job from `.github/workflows/release.yaml`.
You can then create your own deployment setup for docs.
Be careful since GitHub Pages sites are publicly accessible by default; they can only be restricted to private access if you use GitHub Enterprise Cloud.

## Release Process

| Trigger | What happens |
|---------|-------------|
| Push to `main` | Auto-deploys to **dev** via CD |
| **Actions > Deploy > Run workflow** | Deploy any version to any environment |
| **Actions > Tag > Run workflow** | Create a semver tag (`major` / `minor` / `patch`) |
| **Actions > Release > Run workflow** | Tag, create GitHub release, deploy to **prod**, and publish docs |
