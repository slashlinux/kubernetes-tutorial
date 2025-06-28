# GitLab CI + Argo CD + Kubernetes Deployment Flow

Acest document descrie un flow complet CI/CD pentru o aplicație Spring Boot, folosind GitLab CI pentru build & push Docker image și Argo CD pentru deploy automat (GitOps) într-un cluster Kubernetes (ex: AWS EKS).

---

## 🔧 Tehnologii folosite

* GitLab CI/CD
* Docker
* Helm
* Argo CD
* Kubernetes (EKS, AKS, GKE etc.)
* Spring Boot app

---

## 📁 Structura proiectului

```
my-spring-app/
├── .gitlab-ci.yml
├── Dockerfile
├── helm/
│   └── my-spring-app/
│       ├── Chart.yaml
│       ├── templates/
│       │   └── deployment.yaml
│       └── values.yaml
├── src/
└── pom.xml
```

---

## 🧪 .gitlab-ci.yml

```yaml
stages:
  - build
  - docker
  - prepare-helm

variables:
  DOCKER_IMAGE: registry.gitlab.com/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME

build:
  stage: build
  script:
    - mvn clean package -DskipTests
  artifacts:
    paths:
      - target/*.jar

docker:
  stage: docker
  script:
    - docker build -t $DOCKER_IMAGE:$CI_COMMIT_SHORT_SHA .
    - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY
    - docker push $DOCKER_IMAGE:$CI_COMMIT_SHORT_SHA
  only:
    - main

prepare-helm:
  stage: prepare-helm
  script:
    - sed -i "s/tag:.*/tag: $CI_COMMIT_SHORT_SHA/" helm/my-spring-app/values.yaml
    - git config --global user.email "ci@gitlab.com"
    - git config --global user.name "GitLab CI"
    - git add helm/my-spring-app/values.yaml
    - git commit -m "Update image tag to $CI_COMMIT_SHORT_SHA [ci skip]" || echo "No changes"
    - git push origin main
  only:
    - main
```

---

## 🐳 Dockerfile

```dockerfile
FROM openjdk:17-jdk
COPY target/*.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

---

## 📦 Helm values.yaml

```yaml
image:
  repository: registry.gitlab.com/mygroup/my-spring-app
  tag: latest # GitLab CI actualizează automat
```

## 📄 deployment.yaml (Helm Template)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-spring-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-spring-app
  template:
    metadata:
      labels:
        app: my-spring-app
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
```

---

## 🚀 Argo CD Application YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-spring-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.com/mygroup/my-spring-app.git
    targetRevision: main
    path: helm/my-spring-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-spring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Deployezi acest YAML cu:

```bash
kubectl apply -f app.yaml -n argocd
```

---

## 🔁 Flow complet explicat

1. Developer face push in `main`
2. GitLab CI:

   * build .jar
   * build Docker image + push in registry
   * update `values.yaml` cu tag imagine nou
   * push înapoi în Git
3. Argo CD detectează modificarea în Git
4. Argo CD face sync: `helm upgrade` cu noul tag în EKS

---

## 🔗 Tutoriale utile suplimentare

* [GitLab CI/CD cu Kubernetes](https://docs.gitlab.com/ee/user/project/clusters/kubernetes.html)
* [Argo CD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
* [Helm template basics](https://helm.sh/docs/chart_template_guide/)
* [Deploy EKS cu Terraform](https://developer.hashicorp.com/terraform/tutorials/aws/eks)

---

## ✅ Recomandări

* Activează webhook GitLab → Argo CD (pentru sync instant)
* Adaugă `readinessProbe`, `livenessProbe`, HPA în Helm
* Fă versiune staging/prod separată (cu valori Helm diferite)
* Activează RBAC în Argo CD pentru echipe mari

---

## 📦 Extras

Pentru testare rapidă, poți înlocui Docker Registry-ul GitLab cu DockerHub, ECR sau JFrog.

### Terraform + Argo CD auto-install

Dacă vrei să creezi infrastructura EKS + Argo CD preinstalat automat, folosește următorul repository ca bază:

➡️ **Exemplu complet pe GitHub:** [terraform-eks-argocd-example](https://github.com/caiotavares/terraform-eks-argocd)

**Include:**

* Cluster EKS
* IAM roles + OIDC provider
* Install Argo CD cu Helm
* Configurare namespace `argocd`

După `terraform apply`, accesează UI Argo CD cu:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

User: `admin`
Password: `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`

---
