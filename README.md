# Insurance Data API

Microservice providing insurance portfolio data to external clients via REST API.

**Live API:** `https://insurance-api.jollyhill-e1fde3a9.swedencentral.azurecontainerapps.io/insurance-data`

---

## Architecture

```
GitHub (source code)
       │
       │  git push → main
       ▼
GitHub Actions CI/CD
  ├── [test]            pytest → unit tests
  ├── [build-and-push]  docker build → push to Azure Container Registry (OIDC, no secrets)
  └── [deploy]          Azure Container Apps (rolling update, zero downtime)
                               │
                               ├── GET /health              ← liveness probe
                               ├── GET /insurance-data      ← paginated data
                               └── GET /insurance-data/{id} ← single record
                               │
                          Azure Blob Storage (dataset)
                          Azure Monitor + Log Analytics
```

**Stack:**
- **API:** Python 3.12 + Flask
- **Container:** Docker (multi-stage build + virtualenv)
- **Cloud:** Azure Container Apps
- **Registry:** Azure Container Registry
- **Storage:** Azure Blob Storage
- **IaC:** Terraform
- **CI/CD:** GitHub Actions

## Security

- **Managed Identity** — the application authenticates to ACR and Blob Storage without any passwords or connection strings. Access is granted via Azure RBAC roles (`AcrPull`, `Storage Blob Data Reader`)
- **OIDC in pipeline** — GitHub Actions authenticates to Azure using federated tokens (no long-lived secrets in GitHub Secrets)
- **Non-root container** — Dockerfile runs as `appuser`
- **Multi-stage Docker build** — build dependencies and cache do not reach the final image

## High Availability & Minimal Downtime

- **Rolling updates** — Azure Container Apps deploys a new revision before stopping the old one, ensuring zero downtime for clients
- **Liveness probe** — `/health` endpoint checked every 10 seconds; unhealthy containers are restarted automatically
- **Auto-scaling** — 1 to 5 replicas based on traffic, handles new client onboarding without manual intervention
- **Image tagged with commit SHA** — every deployment is fully traceable, rollback is a single `az containerapp update` command

## Infrastructure as Code

All infrastructure managed by Terraform: Container Registry, Container Apps Environment, Blob Storage, Managed Identity, role assignments, Log Analytics Workspace.

```bash
cd infra/
terraform init
terraform apply
```

---

## CI/CD Pipeline

Every `push` to `main` triggers three sequential jobs:

| Job | What it does |
|---|---|
| `test` | Runs pytest — pipeline stops if tests fail |
| `build-and-push` | Logs in via OIDC, builds Docker image tagged with commit SHA, pushes to ACR |
| `deploy` | Deploys new revision to Container Apps using `az containerapp update` |

Pipeline file: [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)

## Required GitHub Secrets

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | Application (client) ID from App registrations |
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `ACR_NAME` | `insurancedevopsacr` |

---

## Monitoring & Security Tools

| Tool | Purpose | Justification |
|---|---|---|
| **Azure Monitor + Log Analytics** | Centralized logs from all replicas | KQL queries, error detection, access audit — essential for insurance data compliance |
| **Liveness probe (`/health`)** | Service availability | Automatic restart on failure, no manual intervention required |
| **Auto-scaling (Container Apps)** | Performance under load | Scales to 5 replicas without downtime as new clients are onboarded |
| **Managed Identity** | Eliminates static credentials | Zero passwords in code, pipeline and config — best practice for regulated industries |
| **Azure Container Registry** | Private image registry | Built-in vulnerability scanning (CVE), RBAC access control |
| **OIDC (GitHub Actions)** | Secure CI/CD authentication | Short-lived tokens instead of long-lived secrets — reduces attack surface |
| **Terraform** | Infrastructure as Code | Reproducible infrastructure, change history in git, code review for infra changes |

---

## API Endpoints

| Endpoint | Description |
|---|---|
| `GET /health` | Returns status and number of loaded records |
| `GET /insurance-data` | Returns paginated list of records (default: 10) |
| `GET /insurance-data?limit=5&offset=10` | Pagination parameters |
| `GET /insurance-data/{id}` | Returns single record by ID |

---

## Dataset

Source: [Insurance Customer Data — Kaggle](https://www.kaggle.com/datasets/chetan0361/insurance-customer-data?resource=download)
