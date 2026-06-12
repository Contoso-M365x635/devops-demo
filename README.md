# DevOps Demo — Cloud PC + Terraform + Azure

Demo repository for Windows 365 Cloud PC DevOps use case.
Two personas, one repo, independent pipelines deploying real Azure infrastructure.

## Personas

| User | Cloud PC | Environment | Deploys |
|---|---|---|---|
| DevOps-User1 | Cloud PC 1 | `environments/user1` | Windows Server VM |
| DevOps-User2 | Cloud PC 2 | `environments/user2` | VNet + Subnets + NSGs |

## Repo Structure

```
devops-demo/
├── .github/workflows/
│   ├── deploy-vm.yml          # Triggered by changes in environments/user1
│   └── deploy-vnet.yml        # Triggered by changes in environments/user2
├── modules/
│   ├── windows-vm/            # Reusable Windows VM module
│   └── vnet/                  # Reusable VNet module
├── environments/
│   ├── user1/                 # DevOps-User1 workspace (VM deployment)
│   └── user2/                 # DevOps-User2 workspace (VNet deployment)
└── scripts/
    └── logon-sync.ps1         # Intune logon script for Cloud PCs
```

## Prerequisites

1. Azure subscription with Contributor access
2. GitHub org with Actions enabled
3. Service Principal or Workload Identity configured (see Setup below)

## Setup

### 1. Create Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "github-devops-demo" \
  --role Contributor \
  --scopes /subscriptions/YOUR-SUBSCRIPTION-ID \
  --sdk-auth
```

### 2. Add GitHub Secrets

Go to your repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | Service principal app ID |
| `AZURE_TENANT_ID` | Your Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your subscription ID |
| `VM_ADMIN_PASSWORD` | Password for the demo VM (User1 only) |

### 3. Deploy Logon Script via Intune

- Upload `scripts/logon-sync.ps1` to Intune → Devices → Scripts
- Run as logged-on user: **Yes**
- Assign to Cloud PC device group

### 4. Update Username Mapping

Edit `scripts/logon-sync.ps1` and replace `devops-user1` / `devops-user2`
with the actual Entra ID usernames of your demo accounts.

## Demo Flow

### DevOps-User1 (Windows VM)
1. Logs into Cloud PC → repo syncs → VS Code opens `environments/user1`
2. Edits `environments/user1/variables.tf` (e.g. change VM size)
3. Commits and pushes
4. `deploy-vm.yml` pipeline triggers automatically
5. Terraform deploys Windows Server VM to Azure

### DevOps-User2 (VNet)
1. Logs into Cloud PC → repo syncs → VS Code opens `environments/user2`
2. Edits `environments/user2/variables.tf` (e.g. add a subnet)
3. Commits and pushes
4. `deploy-vnet.yml` pipeline triggers automatically
5. Terraform deploys VNet + Subnets + NSGs to Azure

## Triggering Pipelines Manually

From VS Code with the **GitHub Actions** extension installed:
- Open the Source Control panel
- Navigate to Actions → select the workflow
- Click **Run workflow**

Or from GitHub UI: Actions → select workflow → Run workflow.
