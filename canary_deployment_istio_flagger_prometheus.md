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
# 🐳 Istio + Canary Deployment + Helm + Real App (Node.js)

## 🧠 Ce face această aplicație?

Aceasta este o aplicație Node.js care răspunde cu mesajul:

```
Hello from version v1
```

sau

```
Hello from version v2
```

în funcție de variabila de mediu `VERSION`. Este ideală pentru Canary Deployment și generare de trafic cu Fortio.

---

## 📦 Structura Helm Chart

```
helm-canary-app/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── destinationrule.yaml
    └── virtualservice.yaml
```

---

## 1️⃣ Codul aplicației (Node.js)

**📄 app.js**

```javascript
const express = require('express');
const app = express();

const version = process.env.VERSION || 'v1';

app.get('/', (req, res) => {
  res.send(`Hello from version ${version}`);
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Listening on port ${port}`);
});
```

---

## 2️⃣ Dockerfile

**📄 Dockerfile**

```Dockerfile
FROM node:18
WORKDIR /app
COPY app.js .
RUN npm init -y && npm install express
ENV VERSION=v1
CMD ["node", "app.js"]
```

---

## 3️⃣ Helm Chart

### 📄 Chart.yaml

```yaml
apiVersion: v2
name: canary-app
version: 0.1.0
```

---

### 📄 values.yaml

```yaml
app:
  name: canary-app
  image:
    repository: your-dockerhub-user/canary-app
    tag: v1
  port: 8080
  version: v1
```

---

### 📄 templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.app.name }}-{{ .Values.app.version }}
  labels:
    app: {{ .Values.app.name }}
    version: {{ .Values.app.version }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Values.app.name }}
      version: {{ .Values.app.version }}
  template:
    metadata:
      labels:
        app: {{ .Values.app.name }}
        version: {{ .Values.app.version }}
    spec:
      containers:
        - name: {{ .Values.app.name }}
          image: "{{ .Values.app.image.repository }}:{{ .Values.app.image.tag }}"
          ports:
            - containerPort: {{ .Values.app.port }}
          env:
            - name: VERSION
              value: "{{ .Values.app.version }}"
```

---

### 📄 templates/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.app.name }}
spec:
  selector:
    app: {{ .Values.app.name }}
  ports:
    - port: 80
      targetPort: {{ .Values.app.port }}
```

---

### 📄 templates/destinationrule.yaml

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: {{ .Values.app.name }}
spec:
  host: {{ .Values.app.name }}
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

---

### 📄 templates/virtualservice.yaml

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: {{ .Values.app.name }}
spec:
  hosts:
    - "*"
  gateways:
    - istio-system/ingressgateway
  http:
    - route:
        - destination:
            host: {{ .Values.app.name }}
            subset: v1
          weight: 90
        - destination:
            host: {{ .Values.app.name }}
            subset: v2
          weight: 10
```



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
* 


## 3️⃣ Create Istio routing components

### DestinationRule

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: demo-rollout
spec:
  host: demo-rollout
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

### VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-rollout
spec:
  hosts:
    - demo-rollout
  http:
    - route:
        - destination:
            host: demo-rollout
            subset: stable
          weight: 100
        - destination:
            host: demo-rollout
            subset: canary
          weight: 0
```

---

## 4️⃣ Create the Rollout with `trafficRouting: istio`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-rollout
spec:
  replicas: 3
  selector:
    matchLabels:
      app: demo-rollout
  template:
    metadata:
      labels:
        app: demo-rollout
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
  strategy:
    canary:
      trafficRouting:
        istio:
          virtualService:
            name: demo-rollout
            routes:
              - http
          destinationRule:
            name: demo-rollout
            canarySubsetName: canary
            stableSubsetName: stable
      steps:
        - setWeight: 20
        - pause: {duration: 10s}
        - setWeight: 100
```

---

## 🧪 Test Rollout

```bash
kubectl argo rollouts get rollout demo-rollout -w
```

---

## 🌐 Access via Istio IngressGateway

Expose via port-forward (for testing):

```bash
kubectl -n argo-rollouts port-forward deployment/argo-rollouts-dashboard --address 0.0.0.0 3100:3100
kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80
```

Then access:

```
http://localhost:8080/
```

---

## ✅ Notes

- Make sure app and service are named `demo-rollout`
- Service must point to pods with `version: stable/canary` labels

---

Happy Canary Deploying with Istio + Argo! 🎯

