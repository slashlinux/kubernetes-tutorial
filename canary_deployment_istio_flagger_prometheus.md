# 📘 Istio + Canary Deployment: Ghid Complet

## 🧠 Ce este Istio?

Istio este un **service mesh** pentru Kubernetes, care adaugă:

* 🔄 routing avansat (canary, A/B testing, retries)
* 🔐 securitate (mTLS, autentificare, autorizare)
* 📊 observabilitate (metrics, logs, traces)
* 💥 fault injection (simulări de erori, delay-uri)

Funcționează printr-un **sidecar proxy (Envoy)** injectat în fiecare pod. Acesta interceptează traficul și aplică regulile definite în resursele Istio.

## 🧱 Arhitectură și Componente

```
[App] → [Envoy Sidecar] → [Istio Control Plane]
```

* `istiod` – control plane Istio
* `istio-ingressgateway` – proxy pentru trafic extern
* `Envoy sidecar` – injectat automat în poduri
* CRD-uri:

  * `VirtualService` – rutează traficul
  * `DestinationRule` – definește subset-uri
  * `Gateway` – echivalent de ingress

---

## ⚖️ Istio vs NGINX Ingress

| Criteriu             | NGINX Ingress   | Istio                           |
| -------------------- | --------------- | ------------------------------- |
| Setup                | Simplu          | Complex                         |
| Funcționalitate      | Doar HTTP/HTTPS | mTLS, retries, circuit breaker  |
| Canary / A/B Testing | Limitat         | Avansat, cu weight              |
| Fault Injection      | ❌ Nu            | ✅ Da                            |
| RBAC                 | Nu              | Da (AuthorizationPolicy)        |
| Observabilitate      | Manual          | Out-of-the-box (Prometheus etc) |

---

## ✅ Când alegi Istio?

* Proiecte enterprise cu multe microservicii
* Cerințe de securitate stricte
* Canary deployments precise
* Observabilitate completă

## ✅ Când alegi NGINX?

* MVP-uri, aplicații REST simple
* Fără nevoi de split traffic sau mTLS
* Ușor de înțeles și întreținut

---

## 🛠️ Instalare Istio (Offline Friendly)

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.3 sh -
cd istio-1.20.3
istioctl install --set profile=demo -y
```

Verificare:

```bash
kubectl get crds | grep istio
kubectl get svc -n istio-system
```

Etichetare namespace pentru injection sidecar:

```bash
kubectl label namespace default istio-injection=enabled
```

---

## 🧪 Canary Deployment cu Istio

### 🔧 Deployment-uri

Două versiuni diferite ale aplicației (v1 și v2) folosind `http-echo`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
      version: v1
  template:
    metadata:
      labels:
        app: my-app
        version: v1
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo
          args: ["-text=v1"]
          ports:
            - containerPort: 5678
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-app
      version: v2
  template:
    metadata:
      labels:
        app: my-app
        version: v2
    spec:
      containers:
        - name: echo
          image: hashicorp/http-echo
          args: ["-text=v2"]
          ports:
            - containerPort: 5678
```

### 🔧 Service + Routing Istio

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 5678
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: my-app
spec:
  host: my-app
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-app
spec:
  hosts:
    - "*"
  gateways:
    - istio-system/ingressgateway
  http:
    - route:
        - destination:
            host: my-app
            subset: v1
          weight: 90
        - destination:
            host: my-app
            subset: v2
          weight: 10
```

### 🔧 Generator trafic (Fortio)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: traffic-generator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fortio
  template:
    metadata:
      labels:
        app: fortio
    spec:
      containers:
        - name: fortio
          image: fortio/fortio
          command: ["sleep", "3600"]
```

Test manual:

```bash
kubectl exec -it deploy/traffic-generator -- \
  fortio load -c 5 -qps 10 -n 100 http://my-app
```

---

## 🧪 Canary Deployment Automat cu Flagger

### 🔧 Instalare:

```bash
helm repo add flagger https://flagger.app
helm upgrade -i flagger flagger/flagger \
  --namespace istio-system \
  --set meshProvider=istio
```

### 🔧 Definire Metrică de tip Success Rate

```yaml
apiVersion: flagger.app/v1beta1
kind: MetricTemplate
metadata:
  name: success-rate
  namespace: istio-canary-demo
spec:
  provider:
    type: prometheus
    address: http://prometheus.istio-system:9090
  query: |
    sum(rate(istio_requests_total{
      destination_workload=~"{{ target }}",
      response_code!~"5.*",
      reporter="destination"
    }[1m])) 
    /
    sum(rate(istio_requests_total{
      destination_workload=~"{{ target }}",
      reporter="destination"
    }[1m])) * 100
```

### 🔧 Canary Resource

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: my-app
  namespace: istio-canary-demo
spec:
  provider: istio
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  service:
    port: 80
  canaryAnalysis:
    interval: 1m
    threshold: 3
    stepWeight: 5
    maxWeight: 50
    metrics:
      - name: success-rate
        templateRef:
          name: success-rate
```

---

## 🧪 Validare Routing

### 🔎 Cu Fortio

```bash
kubectl exec -it deploy/traffic-generator -- \
  fortio load -n 100 http://my-app
```

### 🔎 Cu Loguri

```bash
kubectl logs -l version=v1 | wc -l
kubectl logs -l version=v2 | wc -l
```

### 🔎 Cu Prometheus (PromQL)

```promql
istio_requests_total{destination_workload="my-app", destination_version="v1"}
istio_requests_total{destination_workload="my-app", destination_version="v2"}
```

---

## 📌 TL;DR pentru interviu

* `VirtualService` permite split de trafic cu `weight`
* Fortio validează direct routingul (200 OK, proporții)
* Poți valida și prin loguri sau Prometheus
* Flagger permite rollout automat + rollback dacă apar erori

---

## 🧠 Resurse Utile

* [https://istio.io/](https://istio.io/)
* [https://flagger.app/](https://flagger.app/)
* [https://prometheus.io/](https://prometheus.io/)
* [https://fortio.org/](https://fortio.org/)
