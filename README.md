# Insurance Data API — DevOps Demo

Microservice providing insurance portfolio data to external clients via REST API.
Built as a recruitment task for a DevOps internship at a reinsurance company.

---

## Architecture

```
GitHub (source code)
       │
       │  git push → main
       ▼
GitHub Actions CI/CD
  ├── [test]    pytest → unit tests
  ├── [build]   docker build → push to Azure Container Registry
  └── [deploy]  Azure Container Apps (rolling update, zero downtime)
                       │
                       ├── GET /health              ← liveness probe
                       ├── GET /insurance-data      ← paginated data
                       └── GET /insurance-data/{id} ← single record
                       │
                  Azure Monitor + Application Insights
```

**Stack:**
- **API:** Python 3.12 + FastAPI
- **Container:** Docker
- **Cloud:** Azure Container Apps
- **Registry:** Azure Container Registry
- **IaC:** Terraform
- **CI/CD:** GitHub Actions

---

## How to run locally

**Prerequisites:** Docker

```bash
# Build
docker build -f docker/Dockerfile -t insurance-api .

# Run
docker run -p 8080:80 insurance-api

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/insurance-data
curl http://localhost:8080/insurance-data?limit=5&offset=10
curl http://localhost:8080/insurance-data/0
```

Swagger UI available at: `http://localhost:8080/docs`

---

## Run tests

```bash
pip install -r app/requirements.txt pytest httpx
pytest app/tests/ -v
```

---

## CI/CD Pipeline

Every `push` to `main` triggers three sequential jobs:

| Job | What it does |
|---|---|
| `test` | Runs pytest — pipeline stops if tests fail |
| `build-and-push` | Builds Docker image, tags with commit SHA, pushes to ACR |
| `deploy` | Deploys new revision to Container Apps, verifies `/health` |

PRs only run `test` — no deployment.

---

## Deploy infrastructure (Terraform)

```bash
cd infra/
terraform init
terraform apply
```

Required GitHub secrets:

| Secret | How to get |
|---|---|
| `AZURE_CREDENTIALS` | `az ad sp create-for-rbac --sdk-auth` |
| `ACR_NAME` | output from `terraform apply` |
| `ACR_USERNAME` | Azure Portal → Container Registry → Access keys |
| `ACR_PASSWORD` | Azure Portal → Container Registry → Access keys |

---

## Security

- **No secrets in code** — all credentials in GitHub Secrets
- **HTTPS enforced** — Container Apps provides TLS automatically
- **Non-root container** — Dockerfile runs as `appuser`
- **Read-only dataset** — API only reads data, no write endpoints
- **Minimal base image** — `python:3.12-slim` reduces attack surface

## High Availability & Reliability

- **Auto-scaling** — Container Apps scales 1–5 replicas based on traffic
- **Rolling updates** — new revision deployed before old one stops (zero downtime)
- **Liveness probe** — `/health` checked continuously, unhealthy containers restarted
- **Application Insights** — real-time metrics, error tracking, alerting

## Monitoring

| Tool | Purpose |
|---|---|
| **Application Insights** | Request traces, error rates, response times, alerts |
| **Azure Monitor** | Infrastructure metrics (CPU, memory, replica count) |
| **Log Analytics** | Centralized logs from all replicas, queryable with KQL |
| **Liveness probe** | Automatic restart of unhealthy container instances |
