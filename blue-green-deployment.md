# 🚀 Blue-Green Deployment în Kubernetes

## 🟩 Ce este Blue-Green Deployment?

Blue-Green Deployment este o strategie de livrare în care două versiuni ale aplicației rulează **în paralel**:

- **Blue**: versiunea activă, folosită de utilizatori.
- **Green**: versiunea nouă, pregătită pentru switch.

📦 **Switch-ul de trafic** se face complet și instant din blue către green, odată ce green a fost testată cu succes.

---

## 🔁 Cum funcționează?

Ai două `Deployment`-uri active în Kubernetes:

- `my-app-blue` – versiunea actuală
- `my-app-green` – versiunea nouă

Un singur `Service` sau `Ingress` redirecționează traficul către **una dintre versiuni**, prin `label selector`.

### 🔧 Exemplu de selector inițial (trafic spre blue):

```yaml
selector:
  app: my-app
  version: blue
```

### 🔁 După ce testăm green, schimbăm selectorul:

```yaml
selector:
  app: my-app
  version: green
```

---

## 🧠 Diferențe față de Canary Deployment

| Aspect             | Blue-Green                          | Canary                                           |
|--------------------|--------------------------------------|--------------------------------------------------|
| Deploy             | Două versiuni complet separate       | Rulează în paralel, dar cu traffic splitting     |
| Trafic             | 100% blue sau 100% green             | Împărțit (ex: 90% la v1, 10% la v2)              |
| Rollback           | Instant: comutare înapoi             | Ajustare treptată a traficului                  |
| Control fin        | Nu                                   | Da (release gradual)                            |
| Când e folosit     | Release atomic                       | Testare treptată în producție                   |

---

## ✅ Avantaje

- Poți testa green în fundal fără să afectezi utilizatorii.
- Switch-ul de trafic este **instant** și complet (fără trafic mixt).
- Ideal pentru aplicații **stateless**, unde rollback-ul e ușor.

---

## ⚠️ Dezavantaje

- Cost temporar dublu (rulezi două versiuni simultan).
- Nu ai feedback gradual de la utilizatori (cum ai în canary).

---

## 🧪 Exemplu complet în Kubernetes

### Deployment - Blue

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-blue
  labels:
    app: my-app
    version: blue
```

### Deployment - Green

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app-green
  labels:
    app: my-app
    version: green
```

### Service - Redirecționează traficul

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  selector:
    app: my-app
    version: green  # 👉 modifici aici pentru switch între blue ↔ green
  ports:
    - port: 80
      targetPort: 8080
```
