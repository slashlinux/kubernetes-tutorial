# 🌐 Ingress în Kubernetes

## 🛣️ Ce este Ingress-ul?

Ingress-ul este un **router HTTP** sau o **poartă de intrare** pentru traficul care vine din exteriorul clusterului Kubernetes către aplicațiile din interior.

> 🧠 Gândește-te la el ca la un **NGINX reverse proxy** care citește `host` și `path` din requesturi și le direcționează către serviciile corespunzătoare din cluster.

---

## ❌ Fără Ingress?

Dacă nu folosești Ingress, ai doar aceste opțiuni pentru expunerea aplicației:

- `NodePort` – port expus pe fiecare worker node (incomod și neintuitiv)
- `LoadBalancer` – doar în cloud (AWS, GCP), dar e **scump**

---

## ✅ Cu Ingress – exemplu simplu:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  rules:
    - host: myapp.petrisor.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app-service
                port:
                  number: 80
```

📥 Asta înseamnă:

➡️ Orice request HTTP către `myapp.petrisor.dev` va fi redirecționat către `my-app-service` pe portul 80.

---

## 🧠 Ce trebuie să ai ca să funcționeze?

### 🔹 1. Ingress Controller

Ingress-ul NU funcționează de unul singur. Ai nevoie de un **Ingress Controller**, adică o aplicație care citește și aplică regulile din resursa `Ingress`.

### Exemple comune:

| Ingress Controller       | Folosit în                     |
|--------------------------|--------------------------------|
| `NGINX`                  | Cel mai comun și popular       |
| `AWS ALB Controller`     | Cloud-native (automat creează ALB) |
| `Traefik`                | Rapid, simplu, ușor de configurat |
| `Istio Gateway`          | Parte din service mesh-ul Istio |

---

## 🔗 Ingress în Istio

În cazul în care folosești **Istio**, Ingress-ul e tratat diferit.

Istio are propriul **Ingress Gateway**:

- `istio-ingressgateway` este echivalentul unui Ingress Controller
- În loc de obiectul `Ingress`, se folosesc:
  - `Gateway` – definește punctul de intrare
  - `VirtualService` – definește regulile de rutare (host, path, versiuni etc.)

---

## ✅ Concluzie

Ingress este esențial pentru accesul HTTP/HTTPS din exterior în Kubernetes. Te ajută să controlezi traficul într-un mod flexibil și centralizat.
