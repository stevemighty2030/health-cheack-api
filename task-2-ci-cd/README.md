# Task 2: Separate CI/CD with Azure DevOps, ACR, and Argo CD

This folder contains separate Azure DevOps pipelines:

- `azure-pipelines-ci.yml` validates pull requests, builds the Docker image, and pushes `$(ACR_LOGIN_SERVER)/db-health-check:<commit-sha>` to Azure Container Registry on `main`.
- `azure-pipelines-cd.yml` is manual-trigger only and is started by a successful CI pipeline on `main`. It requires a production approval, then commits the approved image tag to the GitOps repository.
- `gitops/` contains the Kubernetes manifests watched by Argo CD.

## Azure DevOps setup

1. Create a Docker Registry service connection named `acr-service-connection` for ACR.
2. Define the pipeline variable `ACR_LOGIN_SERVER`, for example `myregistry.azurecr.io`.
3. Import `azure-pipelines-ci.yml` as the pipeline `db-health-check-ci`.
4. Import `azure-pipelines-cd.yml` as a separate pipeline.
5. Create variable group `db-health-check-cd` with:
   - `GITOPS_REPOSITORY`: HTTPS clone URL for the GitOps repository.
   - `GITOPS_BRANCH`: branch Argo CD watches, normally `main`.
   - `GITOPS_TOKEN`: secret PAT with repository push permission.
6. Protect the production approval by configuring the Azure DevOps environment/checks as required by the organization.

The CD pipeline also includes `ManualValidation@1`, so production promotion cannot continue until an operator resumes the run. The GitOps commit uses `[skip ci]` to avoid recursively rebuilding the image.

## Argo CD setup

Apply `gitops/argocd/application.yaml` once to the Argo CD cluster after replacing the example repository URL and destination namespace. Argo CD then watches `gitops/overlays/production` and automatically syncs the image tag committed by the CD pipeline.
