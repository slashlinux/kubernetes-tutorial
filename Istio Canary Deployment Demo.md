# Istio Canary Deployment Demo

Acest document conține pași și resurse pentru a simula un **Canary Deployment** cu **Istio** în Kubernetes, folosind un generator de trafic (Fortio).

---

## ✅ Ce conține

- Două Deployment-uri (v1 și v2)
- Un Service Kubernetes
- Un `DestinationRule` și `VirtualService` cu routing 90/10
- Un pod Fortio pentru generarea traficului
- Scripturi shell pentru a analiza distribuția traficului și codurile HTTP

---

## 🛠️ Tehnologii folosite

- **Istio** – pentru controlul traficului (sidecar Envoy, gateway, virtual service)
- **Fortio** – pentru generarea de trafic HTTP
- **Prometheus** – opțional, pentru observabilitate și integrare cu Flagger
- **Helm** – pentru upgrade-uri progresive ale versiunii canary
- **Kubernetes** – orchestratorul principal

---

## 🌀 Flow de trafic

```
Fortio ➝ Istio Gateway ➝ VirtualService ➝ Envoy Sidecar ➝ Deployment v1 / v2
```

Routingul se face astfel:
- 90% din trafic spre `v1`
- 10% din trafic spre `v2` (canary)

---

## 📁 Fișiere utile

### istio-canary-demo.yaml

Conține toate componentele Istio + aplicația v1 și v2:
- Deployment v1
- Deployment v2
- Service
- DestinationRule
- VirtualService

### istio-fortio-exposed.yaml

Pod Fortio configurat cu:
```yaml
image: fortio/fortio
command: ["sleep", "3650d"]
```

---

## 🔍 Scripturi

### check-canary-log-distribution.sh

Verifică ce versiune a aplicației a fost atinsă de Fortio:

```bash
./check-canary-log-distribution.sh default myapp
```

Scrie și într-un fișier: `canary-distribution.log`

---

### check-canary-log-codes.sh

Afișează codurile HTTP returnate:

```bash
./check-canary-log-codes.sh default myapp
```

Scrie în: `canary-codes.log`

---

## 🔄 Upgrade automat cu Helm

Poți folosi Flagger sau un script propriu care:
- Monitorizează codurile `200 OK` din Prometheus
- Crește weight din 5% în 5% la `v2`
- Face rollback automat dacă apar multe `5xx`

---

## 🔗 Utilitar: grpcurl

Pentru aplicații gRPC:
```bash
grpcurl -plaintext my-service:50051 list
```

---

## 🧠 Recomandare

Creează un repo GitHub cu structură:
```
devops-wiki/
├── kubernetes/
├── ci-cd/
├── terraform/
├── tools/
├── scripts/
```

---

## 📌 Resurse însoțitoare

- `istio-canary-demo.zip` – YAML complet
- `check-canary-scripts.zip` – scripturi shell


---

## 🧪 Cum îl folosești

Fă scripturile executabile:

```bash
chmod +x check-canary-log-codes.sh
./check-canary-log-codes.sh
```

🎯 Vei vedea un output precum:

```
🔹 Version v1:
   Total requests: 87
   ✅ 200 OK     : 85
   ❌ 404 NotFound: 1
   🛑 503 Errors : 1
   📊 200: 97.7% | 404: 1.1% | 503: 1.1%

🔹 Version v2:
   Total requests: 13
   ✅ 200 OK     : 10
   ❌ 404 NotFound: 3
   🛑 503 Errors : 0
   📊 200: 76.9% | 404: 23.1% | 503: 0.0%
```

---

## 🎯 Prometheus + Flagger: deployment automat

### 1. Creezi o metrică custom bazată pe rata de succes

```yaml
- name: success-rate
  interval: 30s
  threshold: 99
  query: |
    sum(
      rate(istio_requests_total{
        destination_workload_namespace="{{ namespace }}",
        destination_workload=~"{{ target }}",
        response_code!~"5.*"
      }[1m])
    )
    /
    sum(
      rate(istio_requests_total{
        destination_workload_namespace="{{ namespace }}",
        destination_workload=~"{{ target }}"
      }[1m])
    ) * 100
```

> Dacă n-ai Prometheus instalat, folosește `istioctl install --set profile=demo`.

---

### 2. Instalezi Flagger

```bash
helm repo add flagger https://flagger.app
helm upgrade -i flagger flagger/flagger \
  --namespace istio-system \
  --set meshProvider=istio
```

---

### 3. Creezi metrică custom `success-rate`

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

---

### 4. Creezi obiectul Canary

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

### 5. Faci deploy cu Helm o singură dată

```bash
helm upgrade -i my-app ./chart \
  --namespace istio-canary-demo \
  --set image.tag=1.1.0
```

Flagger detectează imaginea nouă și:
- pornește canary deployment
- crește traficul din 5% în 5%
- face rollback dacă `success-rate < 99` pentru 3 runde

---

### 🔍 Verificare

```bash
kubectl get canaries -n istio-canary-demo --watch
```

Output:
```
NAME      STATUS        WEIGHT    PROGRESSING
my-app    Progressing   15        true
```

---

✅ Ce ai rezolvat:

| Problemă                          | Soluție                   |
|----------------------------------|---------------------------|
| Deploy automat cu pași mici      | ✅ Flagger + Istio        |
| Creștere treptată a traficului  | ✅ `stepWeight: 5`        |
| Validare după 200 OK             | ✅ metrică Prometheus     |
| Rollback dacă apar erori         | ✅ `threshold: 3`         |
| Fără helm upgrade repetat        | ✅ doar 1 helm deploy     |

