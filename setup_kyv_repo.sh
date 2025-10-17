#!/bin/bash

# Ustawienie zmiennej dla nazwy repozytorium (zapewnia spójność ścieżek)
REPO_NAME="website-simple-argocd-k8s-github-kustomize"
GITHUB_ORG="exea-centrum" # Zastąp swoją organizacją/użytkownikiem GitHub, jeśli to konieczne
NAMESPACE="davtrokyverno02"
IMAGE_ID="${REPO_NAME}"
KUSTOMIZE_PATH="./manifests/production"

echo "Przygotowanie struktury plików dla projektu GitOps: ${REPO_NAME}"

# 1. Tworzenie katalogów
echo "Tworzenie katalogów..."
mkdir -p src
mkdir -p .github/workflows
mkdir -p manifests/base
mkdir -p manifests/production
mkdir -p argocd

# 2. Tworzenie plików aplikacji (HTML)
echo "Tworzenie src/index.html..."
cat <<EOF > src/index.html
<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Website Davtro - GitOps Powered</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;800&display=swap" rel="stylesheet">
    <style>
        body {
            font-family: 'Inter', sans-serif;
            background-color: #f3f4f6;
        }
        .card {
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
            transition: transform 0.3s ease;
        }
        .card:hover {
            transform: translateY(-5px);
        }
    </style>
</head>
<body class="flex items-center justify-center min-h-screen p-4">
    <div id="app" class="card bg-white p-8 md:p-12 rounded-xl text-center max-w-lg w-full">
        <h1 class="text-4xl md:text-5xl font-extrabold text-gray-900 mb-4">
            Wdrożenie Davtro
        </h1>
        <p class="text-xl text-gray-600 mb-8">
            ✅ Zasilane przez ArgoCD, Kustomize i GitHub Actions!
        </p>
        <div id="version-info" class="text-sm font-mono text-indigo-600 bg-indigo-50 p-3 rounded-lg inline-block">
            Wersja: 1.0.0 (Data: <span id="deployment-date">Ładowanie...</span>)
        </div>
        <div class="mt-8">
            <a href="https://argo-cd.readthedocs.io/" target="_blank" class="inline-flex items-center justify-center px-6 py-3 border border-transparent text-base font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 transition duration-150 ease-in-out">
                Sprawdź ArgoCD
            </a>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', () => {
            const dateElement = document.getElementById('deployment-date');
            const now = new Date();
            dateElement.textContent = now.toLocaleString('pl-PL', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        });
    </script>
</body>
</html>
EOF

# 3. Tworzenie Dockerfile
echo "Tworzenie Dockerfile..."
cat <<EOF > Dockerfile
# Użycie lekkiego obrazu Nginx jako bazy
FROM nginx:alpine

# Usunięcie domyślnej strony Nginx
RUN rm -rf /usr/share/nginx/html/*

# Skopiowanie naszej strony do katalogu Nginx
COPY src/index.html /usr/share/nginx/html/index.html

# Domyślny port Nginx (80)
EXPOSE 80
EOF

# 4. Tworzenie GitHub Action Workflow
echo "Tworzenie .github/workflows/build-and-push.yml..."
cat <<EOF > .github/workflows/build-and-push.yml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main 

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    
    env:
      IMAGE_NAME: ${IMAGE_ID}
      NAMESPACE: ${NAMESPACE}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: \${{ github.actor }}
          password: \${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/\${{ github.repository_owner }}/\${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=
            type=raw,value=latest,enable=\${{ github.ref == format('refs/heads/{0}', 'main') }}
            
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: \${{ steps.meta.outputs.tags }}
          labels: \${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          
      - name: Output Image Tag
        run: |
          echo "Obraz został wypchnięty jako: ghcr.io/\${{ github.repository_owner }}/\${{ env.IMAGE_NAME }}:\${{ steps.meta.outputs.sha }}"
EOF

# 5. Tworzenie Manifestów Bazowych (Kustomize Base)
echo "Tworzenie manifests/base/deployment.yaml..."
cat <<EOF > manifests/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website-deployment
  labels:
    app: davtro-website
spec:
  replicas: 2
  selector:
    matchLabels:
      app: davtro-website
  template:
    metadata:
      labels:
        app: davtro-website
      annotations: # Przykład adnotacji dla Vault Agent Injector
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "website-k8s-role"
    spec:
      serviceAccountName: website-sa 
      containers:
      - name: website
        image: ghcr.io/${GITHUB_ORG}/${IMAGE_ID}:v1.0.0-placeholder # TAG do zastąpienia przez Kustomize/ArgoCD
        ports:
        - containerPort: 80
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
---
apiVersion: v1
kind: ServiceAccount # SA dla Kyverno/Vault
metadata:
  name: website-sa
  labels:
    app: davtro-website
EOF

echo "Tworzenie manifests/base/service.yaml..."
cat <<EOF > manifests/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: website-service
  labels:
    app: davtro-website
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: davtro-website
EOF

echo "Tworzenie manifests/base/ingress.yaml..."
cat <<EOF > manifests/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: website-ingress
  labels:
    app: davtro-website
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    kubernetes.io/ingress.class: "nginx"
spec:
  rules:
  - host: davtro.local.domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: website-service
            port:
              number: 80
EOF

echo "Tworzenie manifests/base/kustomization.yaml..."
cat <<EOF > manifests/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- ingress.yaml

images:
- name: ghcr.io/${GITHUB_ORG}/${IMAGE_ID}
  newTag: v1.0.0-placeholder
EOF

# 6. Tworzenie Overlayu Produkcyjnego (Kustomize Production)
echo "Tworzenie manifests/production/kustomization.yaml..."
cat <<EOF > manifests/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Zaciągnij manifesty z katalogu bazowego
resources:
- ../base

# Ustawienie docelowej przestrzeni nazw, zgodnie z wymaganiem
namespace: ${NAMESPACE}

# Łatka: zwiększenie liczby replik na produkcji
patches:
- patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
  target:
    kind: Deployment
    name: website-deployment
EOF

# 7. Tworzenie Manifestu ArgoCD Application
echo "Tworzenie argocd/argocd-app.yaml..."
cat <<EOF > argocd/argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: davtro-website-app
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/${GITHUB_ORG}/${REPO_NAME}.git
    targetRevision: HEAD 
    path: ${KUSTOMIZE_PATH} # Wskazuje na manifests/production

  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE} 

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true # Utworzy przestrzeń nazw 'davtro'
EOF

echo ""
echo "✅ Struktura repozytorium została utworzona pomyślnie."
echo ""
echo "NASTĘPNE KROKI:"
echo "1. Zainicjuj repozytorium Git (jeśli jeszcze tego nie zrobiłeś):"
echo "   git init"
echo "   git add ."
echo "   git commit -m \"Initial commit for GitOps setup\""
echo "   git branch -M main"
echo "   git remote add origin https://github.com/${GITHUB_ORG}/${REPO_NAME}.git"
echo "   git push -u origin main"
echo ""
echo "2. Upewnij się, że masz skonfigurowany Vault Agent Injector oraz Kyverno w MicroK8s."
echo ""
echo "3. Zastosuj manifest ArgoCD w klastrze (jeśli ArgoCD jest już zainstalowane w ns 'argocd'):"
echo "   kubectl apply -f argocd/argocd-app.yaml -n argocd"
echo ""
echo "ArgoCD rozpocznie synchronizację do przestrzeni nazw 'davtro'."
