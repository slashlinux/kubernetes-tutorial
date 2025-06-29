# ✅ Canary Deployment cu Istio + Argo Rollouts + Prometheus

## 🧱 Precondiții:
- Ai `kubectl`, `helm`, `istioctl`, `docker` instalate
- Cluster Kubernetes funcțional (ex: `minikube` pornit)

---

## 1️⃣ Instalează Istio cu Istio Gateway
```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
cd istio-1.20.0
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y
```
✅ Verificare:
```bash
kubectl get svc -n istio-system
```

---

## 2️⃣ Instalează Prometheus (de la Istio)
```bash
kubectl apply -f samples/addons/prometheus.yaml
```
✅ Verificare:
```bash
kubectl get pods -n istio-system | grep prometheus
```

---

## 3️⃣ Instalează Argo Rollouts + Dashboard
```bash
kubectl create ns argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/dashboard-install.yaml

kubectl -n argo-rollouts port-forward deployment/argo-rollouts-dashboard 3100:3100
```
🔗 Deschide: [http://localhost:3100/rollouts](http://localhost:3100/rollouts)

---

## 4️⃣ Creează aplicația ta (Node.js + Docker + Helm Chart)
📁 Structură:
```
canary-app/
├── app.js
├── Dockerfile
├── values.yaml
├── Chart.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    ├── destinationrule.yaml
    └── virtualservice.yaml
```

✅ Codul aplicației (Node.js):
```js
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

✅ Dockerfile:
```Dockerfile
FROM node:18
WORKDIR /app
COPY app.js .
RUN npm init -y && npm install express
ENV VERSION=v1
CMD ["node", "app.js"]
```

✅ values.yaml
```yaml
app:
  name: canary-app
  image:
    repository: your-dockerhub-user/canary-app
    tag: v1
  port: 8080
  version: v1
```

✅ Chart.yaml
```yaml
apiVersion: v2
name: canary-app
version: 0.1.0
```

✅ templates/deployment.yaml
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

✅ templates/service.yaml
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

✅ templates/destinationrule.yaml
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

✅ templates/virtualservice.yaml
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

---

## 5️⃣ Build și push imagini
```bash
docker build -t your-dockerhub-user/canary-app:v1 .
docker push your-dockerhub-user/canary-app:v1

docker build -t your-dockerhub-user/canary-app:v2 . # modifică VERSION=v2
docker push your-dockerhub-user/canary-app:v2
```

---

## 6️⃣ Deploy aplicația cu Helm
```bash
helm upgrade --install canary-app ./canary-app
```

---

## 7️⃣ AnalysisTemplate Prometheus
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate-check
spec:
  metrics:
    - name: success-rate
      interval: 30s
      successCondition: result[0] >= 0.95
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus.istio-system:9090
          query: |
            sum(rate(http_requests_total{status=~"2.."}[1m])) /
            sum(rate(http_requests_total[1m]))
```
```bash
kubectl apply -f analysis-template.yaml
```

---

## 8️⃣ Creează Rollout
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-app-rollout
spec:
  replicas: 3
  selector:
    matchLabels:
      app: canary-app
  template:
    metadata:
      labels:
        app: canary-app
        version: v2
    spec:
      containers:
      - name: canary-app
        image: your-dockerhub-user/canary-app:v2
        ports:
        - containerPort: 8080
        env:
        - name: VERSION
          value: "v2"
  strategy:
    canary:
      trafficRouting:
        istio:
          virtualService:
            name: canary-app
            routes:
              - http
          destinationRule:
            name: canary-app
            canarySubsetName: v2
            stableSubsetName: v1
      steps:
        - setWeight: 20
        - pause: {duration: 10s}
        - setWeight: 100
  analysis:
    templates:
      - templateName: success-rate-check
    args:
      - name: service
        value: canary-app
```
```bash
kubectl apply -f argorollout.yaml
```

---

## 9️⃣ Testează cu Fortio
```bash
kubectl run -n default fortio --image=fortio/fortio -it --rm -- /usr/bin/fortio load -t 60s -qps 5 http://<INGRESS-IP>/
```
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

---

🎉 Ai acum un setup complet cu Istio + Argo Rollouts + Prometheus Canary deployment!
