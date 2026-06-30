# Azure Static Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish `apps/mobile/design/LiftMate - prezentacja.html` once as a public HTTPS site on Azure Static Web Apps Free.

**Architecture:** Create an unconnected Azure Static Web Apps resource in the existing `rg-liftmate-dev` resource group. Copy the self-contained presentation to a temporary directory as `index.html`, deploy that directory manually with a transient deployment token, and verify the production endpoint without adding deployment configuration to the repository.

**Tech Stack:** Azure CLI, Azure Static Web Apps Free, Azure Static Web Apps CLI, PowerShell

---

### Task 1: Validate the source and Azure target

**Files:**
- Read: `apps/mobile/design/LiftMate - prezentacja.html`
- Create: none
- Modify: none

- [ ] **Step 1: Confirm the committed source file and active subscription**

Run:

```powershell
git status --short --branch
Get-Item 'apps\mobile\design\LiftMate - prezentacja.html' | Select-Object FullName,Length
az account show --query '{name:name,id:id,state:state}' --output table
```

Expected: the file exists, the subscription is `Enabled`, and no unrelated workspace files are modified by deployment preparation.

- [ ] **Step 2: Confirm resource-group and name availability state**

Run:

```powershell
az group show --name rg-liftmate-dev --query '{name:name,location:location}' --output table
az staticwebapp show --name liftmate-prezentacja-jdemb --resource-group rg-liftmate-dev --output none
```

Expected: the resource group exists. A missing Static Web App is acceptable and means it must be created; an existing resource must be inspected and reused only when its SKU is `Free`.

### Task 2: Create and deploy the free static site

**Files:**
- Read: `apps/mobile/design/LiftMate - prezentacja.html`
- Create outside repository: `$env:TEMP\liftmate-prezentacja-deploy\index.html`
- Modify: none

- [ ] **Step 1: Create the Azure resource explicitly on the Free SKU**

Run when the resource does not already exist:

```powershell
az staticwebapp create --name liftmate-prezentacja-jdemb --resource-group rg-liftmate-dev --location westeurope --sku Free --output none
```

Expected: exit code 0 and a `Microsoft.Web/staticSites` resource named `liftmate-prezentacja-jdemb`.

- [ ] **Step 2: Prepare a disposable deployment directory**

Run:

```powershell
$deployDir = Join-Path $env:TEMP 'liftmate-prezentacja-deploy'
New-Item -ItemType Directory -Path $deployDir -Force | Out-Null
Copy-Item -LiteralPath 'apps\mobile\design\LiftMate - prezentacja.html' -Destination (Join-Path $deployDir 'index.html') -Force
Get-FileHash -Algorithm SHA256 'apps\mobile\design\LiftMate - prezentacja.html', (Join-Path $deployDir 'index.html')
```

Expected: both SHA-256 values are identical.

- [ ] **Step 3: Deploy with a transient token**

Run:

```powershell
$token = az staticwebapp secrets list --name liftmate-prezentacja-jdemb --resource-group rg-liftmate-dev --query properties.apiKey --output tsv
npx --yes @azure/static-web-apps-cli@latest swa deploy $deployDir --deployment-token $token --env production
$token = $null
```

Expected: the CLI reports a successful production deployment. The token is never written to the repository or printed in the final report.

### Task 3: Verify the public result

**Files:**
- Read: none
- Create: none
- Modify: none

- [ ] **Step 1: Verify Azure resource properties**

Run:

```powershell
az staticwebapp show --name liftmate-prezentacja-jdemb --resource-group rg-liftmate-dev --query '{host:defaultHostname,sku:sku.name,state:repositoryUrl}' --output table
```

Expected: `sku` is `Free`, `host` is populated, and no repository integration is configured.

- [ ] **Step 2: Verify the production response and content**

Run:

```powershell
$hostName = az staticwebapp show --name liftmate-prezentacja-jdemb --resource-group rg-liftmate-dev --query defaultHostname --output tsv
$response = Invoke-WebRequest -Uri ("https://" + $hostName + "/") -UseBasicParsing
$response.StatusCode
$response.Content -match '<title>Bundled Page</title>'
$response.Content -match 'LiftMate'
```

Expected: status `200`, followed by `True` and `True`.

- [ ] **Step 3: Verify repository cleanliness and report the public URL**

Run:

```powershell
git status --short
```

Expected: deployment created no untracked token, workflow, or `index.html` file in the repository. Report `https://<host>/` to the user.
