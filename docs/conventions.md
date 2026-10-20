# Conventions

## Git flow
We recommend using the `main` branch to its fullest by following this workflow:
Development is done on short-lived `feature` branches, which are merged into `main` when ready.

## CI/CD

See [CI/CD Setup](cicd_setup.md) for workflows, deployment steps, and release process.

## Tagging
Tags are created by the Tag workflow (used as a reusable building block by the Release workflow).
Tags follow the [Semantic Versioning](https://semver.org/) format:
```text
major.minor.patch, such as 1.2.3
```
### Commit Message
Commit messages should reflect the type of changes.
Hence, we enforce their structure via a commitizen prek hook.
The commit message structure follows the [Conventional Commits](https://www.conventionalcommits.org) structure,
which looks as follows:
```text
<type>(optional scope): <description>
```
where,
- `<type>` must be one of `fix`, `feat`, `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`.
  - Note that `feat` will bump the `minor` version while others will bump the `patch` version.
- `(optional scope)`: can be the JIRA ticket number, for example. It must be in parentheses.
- `<description>`: explicit detail of the changes.
> [!TIP]
> We highly recommend squashing the commit messages for readability.
For more information, see the [official documentation](https://www.conventionalcommits.org).
## Branch naming
The branch name should follow this structure:
```text
<type>/[Optional JIRA ticket number]-[kebab-case-title]
```
where,
- `<type>`: refers to the same [Commit Message's](#commit-message) types.
- `[optional scope]`: refers to the same [Commit Message's](#commit-message) optional scope.
- `[kebab-case-title]`: short and descriptive title (e.g., `added-api-oauth`).
