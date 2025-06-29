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
```

✅ Acces local doar pe localhost . ➡️ Această comandă ascultă doar pe 127.0.0.1 (nu merge dacă încerci să accesezi de pe alt device sau VM).
```
kubectl -n argo-rollouts port-forward deployment/argo-rollouts-dashboard 3100:3100
```

✅ Acces din rețea (ex: de pe alt PC sau Mac către VM)
Comandă cu --address:
```
kubectl -n argo-rollouts port-forward deployment/argo-rollouts-dashboard 3100:3100 --address 0.0.0.0

```
➡️ Acum dashboardul e accesibil pe:
(ex: 192.168.1.123 → acces de pe Mac la http://192.168.1.123:3100/rollouts)

```
http://<ip_local_VM>:3100/rollouts
ip a | grep inet
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
    - name: http
      route:
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

## 7️⃣ analysistemplate_prometheus.yaml

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
argorollout.yaml
```
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
            name: canary-app
            routes:
              - http
          destinationRule:
            name: demo-rollout
            canarySubsetName: v2
            stableSubsetName: v1
      steps:
        - setWeight: 20
        - pause: {duration: 10s}
        - setWeight: 100
```
```bash
kubectl apply -f argorollout.yaml
```


```
petrisor@petrisor:~$ helm install canary-app ./canary-app
NAME: canary-app
LAST DEPLOYED: Sun Jun 29 15:27:15 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
petrisor@petrisor:~$ kubectl get virtualservice
kubectl argo rollouts get rollout demo-rollout
NAME         GATEWAYS                          HOSTS   AGE
canary-app   ["istio-system/ingressgateway"]   ["*"]   8s
Name:            demo-rollout
Namespace:       default
Status:          ◌ Progressing
Message:         updated replicas are still becoming available
Strategy:        Canary
  Step:          3/3
  SetWeight:     100
  ActualWeight:  100
Images:          nginx:1.27 (stable)
Replicas:
  Desired:       3
  Current:       3
  Updated:       3
  Ready:         2
  Available:     2

NAME                                     KIND        STATUS         AGE  INFO
⟳ demo-rollout                           Rollout     ◌ Progressing  8s   
└──# revision:1                                                          
   └──⧉ demo-rollout-f5b46d586           ReplicaSet  ✔ Healthy      8s   stable
      ├──□ demo-rollout-f5b46d586-8p6bg  Pod         ✔ Running      8s   ready:1/1
      ├──□ demo-rollout-f5b46d586-ptbfj  Pod         ✔ Running      8s   ready:1/1
      └──□ demo-rollout-f5b46d586-rx48x  Pod         ✔ Running      8s   ready:1/1
```
---
✅ Fa port-forward argo-rollouts
Comandă cu --address:
```
kubectl -n argo-rollouts port-forward deployment/argo-rollouts-dashboard 3100:3100 --address 0.0.0.0

```
✅ Fa port-forward svc/canary-app 8080:80
Comandă cu --address:
```
petrisor@petrisor:~$ kubectl port-forward svc/canary-app 8080:80
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
Handling connection for 8080

petrisor@petrisor:~$ curl http://localhost:8080
Hello from version v1
```

✅ Doar dacă vrei să testezi prin gateway-ul Istio extern, comanda:
Când e nevoie de port-forward pe istio-ingressgateway?

Situație	                                                Trebuie port-forward pe IngressGateway?
Ai acces la EXTERNAL-IP (din cloud)	                        ❌ Nu, folosești direct acel IP
Vrei să testezi din local, fără IP public	                ✅ Da
Testezi direct pe svc/canary-app în cluster	                ❌ Nu, folosești kubectl port-forward svc/canary-app


```
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
# Ascultă pe toate interfețele (0.0.0.0) ca să poți testa și din afara VM-ului, dacă vrei
kubectl -n istio-system port-forward svc/istio-ingressgateway \
  --address 0.0.0.0 8080:80

### îți permite să accesezi aplicația prin Istio Ingress Gateway, adică:
curl http://localhost:8080

```
## 9️⃣ Testează cu Fortio
```bash
kubectl run -n default fortio --image=fortio/fortio -it --rm -- /usr/bin/fortio load -t 60s -qps 5 http://<INGRESS-IP>/
# Trafic 60 s, 5 request-uri/secundă, prin gateway
kubectl run fortio-client -n default --image=fortio/fortio -it --rm -- fortio load -t 60s -qps 5 http://localhost:8080

```
```bash
kubectl get svc istio-ingressgateway -n istio-system
```

---

🎉 Ai acum un setup complet cu Istio + Argo Rollouts + Prometheus Canary deployment!
