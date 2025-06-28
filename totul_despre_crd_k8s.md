# 📘 Kubernetes CRDs - Custom Resource Definitions

## 🧠 Ce este un CRD în Kubernetes?

Un **CRD (Custom Resource Definition)** este o extensie a API-ului Kubernetes care îți permite să definești **tipuri de resurse personalizate**. Acestea funcționează exact ca resursele native (`Pod`, `Service`, `Deployment`), dar pot reprezenta orice structură necesară pentru aplicația sau platforma ta.

---

## ✅ De ce sunt utile CRD-urile?

- 🔧 Extinzi funcționalitatea Kubernetes fără a modifica nucleul.
- 🧩 Permite toolurilor externe (Istio, ArgoCD, cert-manager etc.) să introducă resurse proprii.
- ⚙️ Pot fi gestionate prin controller-e personalizate.
- 🛠️ Permit declarativ managementul componentelor complexe (ex: rollout, backup, rețelistică avansată).

---

## 📦 Exemple de Tooluri care folosesc CRD-uri

| Tool           | Exemplu CRD             |
|----------------|--------------------------|
| Istio          | `VirtualService`, `DestinationRule` |
| ArgoCD         | `Application`           |
| cert-manager   | `Certificate`, `Issuer` |
| Prometheus Operator | `ServiceMonitor`     |
| Velero         | `Backup`, `Restore`     |

---

## 🔧 Exemplu simplu

### ▶️ Resursă nativă: Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: my-app:latest
```

### 🧩 Resursă CRD (ex. din Istio)

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-service
spec:
  hosts:
    - my-service.example.com
  http:
    - route:
        - destination:
            host: my-service
            subset: v1
```

> 💡 `VirtualService` nu este un tip de resursă nativă în Kubernetes. A fost introdus de **Istio** printr-un CRD.

---

## 🚀 Cum instalezi un CRD?

CRD-urile sunt definite în fișiere `.yaml` de tip `CustomResourceDefinition`. Acestea pot fi instalate cu:

```bash
kubectl apply -f crd-definition.yaml
```

> De obicei, aceste fișiere sunt incluse în manifestele de instalare ale aplicațiilor, cum ar fi:

### 🔹 Istio

```bash
istioctl install --set profile=demo
```

Verifică CRD-urile instalate:

```bash
kubectl get crd
```

### 🔹 ArgoCD

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

---

## 🔍 Cum folosești CRD-urile?

Odată instalate, le poți folosi ca orice altă resursă:

```bash
kubectl apply -f my-virtualservice.yaml
kubectl get virtualservices.networking.istio.io
```

---

## 💬 Cum explici CRD-urile la interviu?

> “A CRD, or Custom Resource Definition, is a way to extend Kubernetes by creating new resource types. Tools like Istio or ArgoCD define their own CRDs, such as `VirtualService` or `Application`, and deploy controllers to manage them. I’ve worked with CRDs in the context of traffic shaping with Istio and rollout management with ArgoCD.”

---

## 🔗 Resurse utile

- [Documentație Kubernetes - Extending the Kubernetes API](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Istio VirtualService Docs](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [ArgoCD Application Spec](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)

---

## 📁 Exemple

Poți găsi CRD-urile în manifestele acestor tooluri:
- [Istio CRDs (GitHub)](https://github.com/istio/istio/tree/master/manifests/charts/base/crds)
- [ArgoCD CRDs (GitHub)](https://github.com/argoproj/argo-cd/tree/master/manifests/crds)
- [cert-manager CRDs](https://github.com/cert-manager/cert-manager/tree/master/deploy/crds)

---

## 📌 Tipuri de CRD-uri (în funcție de scop)

| Scop              | Exemple CRD-uri               |
|-------------------|-------------------------------|
| Networking        | `VirtualService`, `Gateway`   |
| Deployments       | `Rollout`, `Application`      |
| Securitate        | `Policy`, `Certificate`, `Issuer` |
| Monitoring        | `ServiceMonitor`, `AlertmanagerConfig` |
| Backup/Restore    | `Backup`, `Restore`, `Schedule` |

---

## 🛠️ Comenzi utile

```bash
kubectl get crd                                 # Listează toate CRD-urile
kubectl describe crd <nume-crd>                 # Detalii despre un CRD
kubectl get <nume-resursa-crd>                  # Listează instanțele acelui tip
```

---

## 📬 Feedback

Dacă ai întrebări sau sugestii, deschide un [Issue](https://github.com/tu-user/crd-tutorial/issues) sau un Pull Request!
