# FastAPI Health Check App

A containerized FastAPI health-check service with PostgreSQL, Nginx, Azure DevOps CI/CD, Azure Container Registry, and Argo CD GitOps deployment.

## Features

- FastAPI endpoints at `/` and `/health`
- PostgreSQL database health check
- Nginx reverse proxy
- Docker Compose local development
- Azure DevOps CI with testing, linting, secret scanning, SCA, SAST, and image publishing
- Argo CD deployment to dev, UAT, and production

## Requirements

### Local development

- Docker and Docker Compose
- Python 3.12 or newer for local validation

### CI/CD and deployment

- Azure DevOps project and agent pool
- Azure Container Registry
- Kubernetes cluster with Argo CD
- Separate GitOps repository containing Helm charts or plain Kubernetes manifests

## Local Setup

Copy the example environment file and start the stack:

```bash
cp .env.example .env
docker compose up --build
```

Services:

| Service | Address |
| --- | --- |
| FastAPI app | http://localhost:8000 |
| Health check | http://localhost:8000/health |
| Nginx | http://localhost |
| PostgreSQL | localhost:5432 |

### Environment variables

```env
DATABASE_URL=postgresql+asyncpg://appuser:secret@db:5432/healthdb
POSTGRES_DB=healthdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secret
```

Do not commit real secrets. Use Azure Key Vault or another secure secret store in production.

## API

### `GET /`

```json
{
  "message": "FastAPI service is running"
}
```

### `GET /health`

Returns the application and database status:

```json
{
  "status": "ok",
  "database": "connected"
}
```

## CI Pipeline

Pipeline file: [task-2-ci-cd/azure-pipelines-ci.yml](task-2-ci-cd/azure-pipelines-ci.yml)

The pipeline runs for pull requests and pushes to `main`:

| Stage | Purpose |
| --- | --- |
| `UnitTests` | Install dependencies and run `pytest`. |
| `Lint` | Run Ruff and Python compilation checks. |
| `SecretScan` | Scan the complete Git history with Gitleaks. Any detected secret exits with code `1` and fails the pipeline. |
| `SonarQube` | Run SonarQube source and dependency analysis and publish the quality gate. |
| `SAST` | Use Snyk to scan `requirements.txt` for third-party dependency vulnerabilities at all severity levels. Any finding fails the pipeline. |
| `BuildImage` | Build the commit-tagged Docker image once and export it as a pipeline artifact. |
| `Trivy` | Scan the exact exported image for all vulnerabilities. Any vulnerability exits with code `1` and fails the pipeline. |
| `Publish` | Push the scanned image to ACR from `main` only. |

The image is tagged with both the commit SHA and `latest`. The same image artifact is built, scanned, and published; it is not rebuilt between security scanning and publishing. Gitleaks and Trivy are blocking gates, so the image cannot reach ACR when either scan finds a finding.

### Azure DevOps CI configuration

Create these service connections and variables:

- Docker Registry service connection: `acr-service-connection`
- SonarQube service connection: `sonarqube-service-connection`
- Pipeline variable: `ACR_LOGIN_SERVER`, such as `myregistry.azurecr.io`
- Pipeline variable: `SONAR_PROJECT_KEY`
- Secret pipeline variable: `SNYK_TOKEN`

Install the Azure DevOps `Docker` and `SonarQube` extensions. Review the Gitleaks, Snyk, and Trivy scanner versions before production use. The Snyk `SAST` stage runs before `BuildImage`, and its nonzero exit code prevents both image construction and ACR publishing when a third-party dependency vulnerability is found.

## CD Pipeline

Pipeline file: [task-2-ci-cd/azure-pipelines-cd.yml](task-2-ci-cd/azure-pipelines-cd.yml)

The CD pipeline starts after a successful `db-health-check-ci` run on `main`:

1. Wait for manual production approval.
2. Clone the external GitOps repository.
3. Update the newly built ACR image reference.
4. Commit and push the GitOps change.

Create an Azure DevOps variable group named `db-health-check-cd`:

| Variable | Description |
| --- | --- |
| `GITOPS_REPOSITORY` | HTTPS clone URL of the external GitOps repository. |
| `GITOPS_BRANCH` | Branch watched by Argo CD, normally `main`. |
| `GITOPS_TOKEN` | Secret Azure DevOps PAT with repository push permission. |
| `GITOPS_UPDATE_MODE` | `helm-values` or `manifest`. |
| `GITOPS_FILE` | Path to the target `values.yaml` or Kubernetes manifest. |

Update modes:

- `helm-values`: updates the first `repository` and `tag` fields in the selected values file.
- `manifest`: updates the first `image` field in the selected Kubernetes manifest.

The GitOps commit uses `[skip ci]` to prevent a recursive image build.

## Argo CD GitOps

Application definitions: [task-2-ci-cd/gitops/argocd/application.yaml](task-2-ci-cd/gitops/argocd/application.yaml)

Replace the example Azure DevOps URL in that file with the external GitOps repository. The repository should expose these paths:

```text
environments/dev
environments/uat
environments/prod
```

| Environment | Namespace | Sync behavior |
| --- | --- | --- |
| Dev | `db-health-check-dev` | Automated sync, self-heal, and prune. |
| UAT | `db-health-check-uat` | Automated sync, self-heal, and prune. |
| Production | `db-health-check-prod` | No automated sync. An operator manually reviews and syncs the approved change. |

Each environment may contain a Helm chart or plain Kubernetes manifests. Kustomize is not required.

## Repository Structure

```text
.
├── app/
│   ├── __init__.py
│   └── main.py
├── tests/
│   └── test_app.py
├── task-2-ci-cd/
│   ├── azure-pipelines-ci.yml
│   ├── azure-pipelines-cd.yml
│   └── gitops/argocd/application.yaml
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
├── requirements.txt
├── verify_app.py
└── README.md
```
