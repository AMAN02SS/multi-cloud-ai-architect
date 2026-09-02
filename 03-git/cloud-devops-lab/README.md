                    GitHub
                       │
                       ▼
                 Pull Request
                       │
                       ▼
                GitHub Actions
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Build         Test       Security
          │            │            │
          └────────────┼────────────┘
                       ▼
                Terraform Validate
                       │
                       ▼
                 Terraform Plan
                       │
                       ▼
                 Docker Build
                       │
                       ▼
                 Trivy Scan
                       │
                       ▼
                 Push to ACR
                       │
                       ▼
                  Deploy Azure
                       │
                       ▼
              Azure Monitor# Cloud Devops Lab
