# DevOps Demo — Windows 365 Cloud PC Platform

A complete demo platform for Windows 365 Cloud PCs showcasing two distinct personas:
**DevOps engineers** deploying real Azure infrastructure via Terraform, and a **Developer**
running a local AI assistant with Ollama + Open WebUI — all auto-configured on login.

---

## Personas

| User | Role | Cloud PC | Environment | Experience on Login |
|---|---|---|---|---|
| DebraBerger | DevOps Engineer | Cloud PC 1 | `environments/user1` | VS Code + Terraform → deploys Windows Server VM |
| PradeepGupta | DevOps Engineer | Cloud PC 2 | `environments/user2` | VS Code + Terraform → deploys VNet + Subnets + NSGs |
| MeganBowen | Developer | Cloud PC 3 | `developer/` | Docker + Ollama + Open WebUI (local LLM, Arena mode) |

---

## How It Works

Every Cloud PC runs a **scheduled task** (deployed via Intune) that fires on login.
It pulls the latest repo, reads `config/user-map.json` to identify the logged-in user,
then launches their role-specific environment automatically — no manual setup needed.

```
User logs in
    └── Scheduled task fires (Interactive SID, runs as logged-on user)
            └── launcher.ps1 runs
                    ├── git pull (sync latest repo)
                    ├── reads config/user-map.json
                    └── DebraBerger / PradeepGupta → opens VS Code at Terraform workspace
                        MeganBowen              → starts Docker + Ollama + Open WebUI
```

---

## Repo Structure

```
devops-demo/
├── .github/workflows/
│   ├── deploy-vm.yml           # CI/CD pipeline for VM deployment (user1)
│   └── deploy-vnet.yml         # CI/CD pipeline for VNet deployment (user2)
├── config/
│   └── user-map.json           # Maps Windows usernames to environments + launch scripts
├── modules/
│   ├── windows-vm/             # Reusable Terraform module: Windows Server VM
│   └── vnet/                   # Reusable Terraform module: VNet + Subnets + NSGs
├── environments/
│   ├── user1/                  # Debra's Terraform workspace (VM deployment)
│   └── user2/                  # Pradeep's Terraform workspace (VNet deployment)
├── developer/
│   ├── docker-compose.yml      # Ollama (port 11434) + Open WebUI (port 3000)
│   └── README.md               # LLM stack documentation
└── scripts/
    ├── setup-logon-task.ps1    # Intune platform script — registers the logon task (run once as SYSTEM)
    ├── install-devops-tools.ps1# Intune script — installs Git + Terraform via winget
    ├── developer-launch.ps1    # Megan's launch script — Docker + Ollama + Open WebUI
    ├── deploy-vm.ps1           # Debra's script — az login + terraform plan/apply for VM
    └── deploy-vnet.ps1         # Pradeep's script — az login + terraform plan/apply for VNet
```

---

## Intune Setup

This platform requires **two PowerShell scripts** deployed via Intune, plus standard app deployments.

### Step 1: Deploy Apps to Cloud PCs

Use Intune to deploy the following apps to each device group:

| App | DevOps Cloud PCs | Developer Cloud PC | Method |
|---|---|---|---|
| Git | Required | Optional | winget / Intune app |
| Terraform | Required | Not needed | winget / Intune app |
| VS Code | Required | Required | Intune app (Microsoft Store or .exe) |
| Docker Desktop | Not needed | Required | Intune app (.exe) |

> Alternatively, deploy `scripts/install-devops-tools.ps1` via Intune to install Git and Terraform automatically.

### Step 2: Deploy `install-devops-tools.ps1` (DevOps Cloud PCs only)

| Setting | Value |
|---|---|
| Script | `scripts/install-devops-tools.ps1` |
| Run as account | **SYSTEM** |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | DevOps Cloud PC device group |

This installs **Git** and **Terraform** via winget. Logs to `C:\ProgramData\Intune\install-devops-tools.log`.

### Step 3: Deploy `setup-logon-task.ps1` (All Cloud PCs)

| Setting | Value |
|---|---|
| Script | `scripts/setup-logon-task.ps1` |
| Run as account | **SYSTEM** |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | All Cloud PC device groups (DevOps + Developer) |

This is the **core platform script**. It:
1. Copies `launcher.ps1` to `C:\ProgramData\DevOpsDemo\`
2. Registers a Windows scheduled task that fires on every user login
3. Uses **Interactive SID (S-1-5-4)** so the task runs as whoever is logged in — no username needed

> **Why SYSTEM + Scheduled Task instead of Intune user-context scripts?**
> Intune's PowerShell agent runs as SYSTEM and cannot reliably impersonate user sessions.
> The scheduled task (with Interactive SID) runs in the actual logged-on user's context at login — giving full access to the user profile, Desktop, and network tokens.

### Step 4: Update Username Mapping

Edit `config/user-map.json` to match the actual Windows usernames on your Cloud PCs.
Run `echo %USERNAME%` in CMD on each Cloud PC to get the exact value.

```json
{
  "users": {
    "DebraBerger":  { "folder": "environments/user1", "launch": "" },
    "PradeepGupta": { "folder": "environments/user2", "launch": "" },
    "MeganBowen":   { "folder": "developer",          "launch": "scripts/developer-launch.ps1" }
  },
  "default": { "folder": "", "launch": "" }
}
```

Commit and push changes — they'll be picked up on next login via `git pull`.

---

## Azure Prerequisites (DevOps Personas)

1. Azure subscription with Contributor access
2. GitHub Actions secrets configured (for CI/CD pipelines):

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | Service principal app ID |
| `AZURE_TENANT_ID` | Your Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |
| `VM_ADMIN_PASSWORD` | Password for demo VM (Debra only) |

3. Create Service Principal:

```bash
az ad sp create-for-rbac \
  --name "github-devops-demo" \
  --role Contributor \
  --scopes /subscriptions/YOUR-SUBSCRIPTION-ID \
  --sdk-auth
```

---

## Demo Flow

### DevOps — Debra Berger (Windows VM deployment)

1. Logs into Cloud PC → repo syncs → VS Code opens `environments/user1`
2. Runs `scripts/deploy-vm.ps1` → browser opens for `az login`
3. Terraform plan shown → confirms → VM deployed to Azure
4. Or: edit `variables.tf`, commit & push → GitHub Actions pipeline triggers automatically

### DevOps — Pradeep Gupta (VNet deployment)

1. Logs into Cloud PC → repo syncs → VS Code opens `environments/user2`
2. Runs `scripts/deploy-vnet.ps1` → browser opens for `az login`
3. Terraform plan shown → confirms → VNet + Subnets + NSGs deployed to Azure
4. Or: edit `variables.tf`, commit & push → GitHub Actions pipeline triggers automatically

### Developer — Megan Bowen (Local AI assistant)

1. Logs into Cloud PC → Docker Desktop starts automatically
2. Ollama + Open WebUI containers start via `docker compose`
3. Two LLM models pulled automatically: `phi3:mini` + `gemma2:2b`
4. Browser opens to `http://localhost:3000` (Open WebUI)
5. Use **Arena mode** to compare models side by side
6. VS Code opens `developer/` folder for code work

---

## Log Locations

| Component | Log File |
|---|---|
| Intune tools install | `C:\ProgramData\Intune\install-devops-tools.log` |
| Logon sync / launcher | `%USERPROFILE%\Projects\devops-sync.log` |
| Developer LLM launch | `%USERPROFILE%\Projects\devops-sync.log` |

---

## Triggering Pipelines Manually

From GitHub UI: **Actions → select workflow → Run workflow**

Or from VS Code with the **GitHub Actions** extension:
Source Control panel → Actions → select workflow → Run workflow
