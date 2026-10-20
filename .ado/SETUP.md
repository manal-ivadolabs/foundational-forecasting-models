# Azure DevOps Setup

## General

- Update `zensical.toml` (the docs configuration)
- Required reviewers are configured via branch policies (see [PR Validation](#pr-validation)), not `CODEOWNERS`

## Pipelines

Create 5 pipelines via the Azure CLI (requires [`az pipelines`](https://learn.microsoft.com/en-us/cli/azure/pipelines)):

```bash
az pipelines create --name "CI"      --branch main --yaml-path .ado/pipelines/ci.yaml
az pipelines create --name "CD"      --branch main --yaml-path .ado/pipelines/cd.yaml
az pipelines create --name "Deploy"  --branch main --yaml-path .ado/pipelines/deploy.yaml
az pipelines create --name "Tag"     --branch main --yaml-path .ado/pipelines/tag.yaml
az pipelines create --name "Release" --branch main --yaml-path .ado/pipelines/release.yaml
```

Alternatively, create them manually via **Pipelines > New pipeline > Azure Repos Git > select repo > Existing Azure Pipelines YAML file**, then rename each via **⋮ > Rename/move** (Azure DevOps does not pick up the display name from YAML).

## GCP Authentication

Pipelines need access to Ivado Labs' private Python package registry (GCP Artifact Registry) to install internal libraries. Authentication is handled via Workload Identity Federation (WIF) — no long-lived service account keys needed.

**Prerequisites:** your project must be registered in the WIF pool. Follow [ivado-labs/il-registry — AZURE.md](https://github.com/ivado-labs/il-registry/blob/main/AZURE.md) to register it and create the required Azure DevOps service connection.

Once that's done:

1. Create a variable group named **`common-vars`** (**Pipelines > Library > + Variable group**) with the following variable:

   | Variable             | Value                              |
   |----------------------|------------------------------------|
   | `POOL_PROVIDER_NAME` | Your project's codename as registered in il-registry (e.g. `my-project`) |

2. Authorize all pipelines to use it: on the variable group page, select **Pipeline permissions > ⋮ > Open access**

The CI, CD, Deploy, and Release pipelines reference this group in their YAML (`variables: - group: common-vars`). Open access avoids a per-pipeline authorization prompt on first run.

## Permissions

Grant the Build Service permission to push tags:

1. **Project Settings > Repositories > [repo] > Security**
2. Find `[repo] Build Service ([org])` and set:
   - **Contribute**: Allow
   - **Create tag**: Allow

## PR Validation

Enable CI on pull requests:

1. **Project Settings > Repositories > [repo] > Policies > Branch Policies > main**
2. **Build Validation > + Add** > select the **CI** pipeline

## Docs (optional)

The Release pipeline deploys documentation to [Azure Static Web Apps](https://azure.microsoft.com/en-us/products/app-service/static). Docs are **private by default** — `.ado/staticwebapp.config.json` restricts all routes to the `reader` role.

1. Create a Static Web App in the Azure portal
2. When Azure creates the SWA, it auto-generates a pipeline file (e.g. `azure-static-web-apps-xxxx.yml`) in the repo root — **delete it**. Deployment is handled by `release.yaml` instead.
3. Copy the deployment token
4. Add it as a pipeline variable on the **Release** pipeline:

| Variable                          | Value                        |
|-----------------------------------|------------------------------|
| `AZURE_STATIC_WEB_APPS_API_TOKEN` | *(deployment token from portal)* |

5. Invite users: **Azure portal → Static Web App → Settings → Role management → Invite** — enter their email, set role to `reader`

> The 7-day limit applies to the invitation link only. Once accepted, access is permanent until revoked.
>
> If a user gets a 403 after accepting the invite, their session token predates the role assignment. They should log out at `/.auth/logout` then sign back in.

## Release Process

| Trigger | What happens |
|---------|-------------|
| Push to `main` | Auto-deploys to **dev** via CD |
| **Pipelines > Deploy > Run pipeline** | Deploy any version to any environment |
| **Pipelines > Tag > Run pipeline** | Create a semver tag (`major` / `minor` / `patch`) |
| **Pipelines > Release > Run pipeline** | Tag, publish release notes, deploy to **prod**, and publish docs |

**QA**

1. Go to **Pipelines > Deploy > Run pipeline**
2. Select `qa` as the environment and enter the version (tag or commit SHA) already deployed to dev

**PROD**

1. Go to **Pipelines > Release > Run pipeline**
2. Select the release type (`major`, `minor`, or `patch`)
