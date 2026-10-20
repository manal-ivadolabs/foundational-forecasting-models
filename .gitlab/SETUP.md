# GitLab CI/CD Setup

## General

- Update `zensical.toml` (the docs configuration)
- No `CODEOWNERS` needed — required reviewers are configured via protected branch merge request approvals (Settings → Repository → Protected branches → main → Allowed to merge)

## Pipelines

CI/CD is auto-detected from `.gitlab-ci.yml` — no manual pipeline creation required. Once the file is in the repo, all pipelines are active immediately.

## GCP Authentication

> **In progress — not yet available.** GitLab Workload Identity Federation setup is not yet configured in il-registry. This section will be updated once it is. Contact [jonathan.marcil@ivadolabs.com](mailto:jonathan.marcil@ivadolabs.com) for help.

## Permissions

Grant the CI/CD bot permission to push tags:

1. **Settings → Repository → Protected tags**
2. Add a wildcard rule (e.g. `*`) and set **Allowed to create** to include **Maintainers** or the CI/CD service account as needed

> The CI job authenticates via `CI_JOB_TOKEN` for git push. No additional token configuration is required for tag creation.

## PR Validation

CI jobs run automatically on merge requests — no additional configuration needed. GitLab detects merge request pipelines via `$CI_PIPELINE_SOURCE == "merge_request_event"`.

To enforce CI as a merge requirement:

1. **Settings → Repository → Protected branches → main**
2. Enable **Require a pipeline to succeed**

## Docs (optional)

The release pipeline deploys documentation to [GitLab Pages](https://docs.gitlab.com/ee/user/project/pages/). Docs can be restricted to project members only.

1. Enable Pages: **Settings → General → Visibility, project features, permissions → Pages → Only Project Members**
2. No deployment token or external service needed — the `pages` job handles deployment automatically via the `public/` artifact convention.

> The `pages` job is set to `when: manual` on main — trigger it from **CI/CD → Pipelines** on main's pipeline.

## Release Process

| Action | How |
|--------|-----|
| Push to `main` | Auto-deploys to **dev**; `plan:qa` runs automatically |
| Deploy to QA | Click **deploy:qa** on main's pipeline (gated on dev success) |
| Rollback prod | Go to the pipeline of the version you want to roll back to → click **rollback:prod** |
| Full release (tag + prod deploy) | Click **release:patch**, **release:minor**, or **release:major** on main's pipeline — automatically chains: tag → release notes → plan:prod → deploy:prod |
| Deploy docs | Click **pages** on main's pipeline |
