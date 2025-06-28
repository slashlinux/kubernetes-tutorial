# 🧪 Minikube Kubernetes Cluster cu VirtualBox + Istio + Canary Deployment

## 🛠️ Ce vei face în acest tutorial:

1. Instalezi Minikube pe VirtualBox (local)
2. Rulezi un cluster Kubernetes
3. Instalezi un NGINX simplu + generezi trafic
4. Instalezi Istio (service mesh)
5. Rulezi un Canary Deployment cu două versiuni ale aplicației

---

## 🔧 1. Cerințe preliminare

### 🖥️ Local (Linux, macOS sau Windows):

* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [minikube](https://minikube.sigs.k8s.io/docs/start/)
* [istioctl](https://istio.io/latest/docs/setup/getting-started/#download)

---

## 🚀 2. Creează un cluster Minikube cu VirtualBox

```bash
minikube start --driver=virtualbox --cpus=4 --memory=4096
```

Verifică:

```bash
kubectl get nodes
```

---

## 🌐 3. Instalează un NGINX pod expus ca serviciu

```yaml
# nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

```yaml
# nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
  type: NodePort
```

```bash
kubectl apply -f nginx-deployment.yaml
kubectl apply -f nginx-service.yaml
minikube service nginx-service
```

---

## 🕸️ 4. Instalează Istio în cluster

```bash
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled
```

Verifică:

```bash
kubectl get pods -n istio-system
```

---

## 🧪 5. Canary Deployment cu Istio

### 5.1 Creează două versiuni ale aplicației `httpbin`

```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/httpbin/httpbin.yaml
```

Modifică una dintre versiuni (ex: httpbin-v2 cu un alt mesaj sau tag).

### 5.2 Creează un Gateway, VirtualService și DestinationRule

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
```

```yaml
# destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin
spec:
  host: httpbin
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

```yaml
# virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - route:
    - destination:
        host: httpbin
        subset: v1
      weight: 90
    - destination:
        host: httpbin
        subset: v2
      weight: 10
```

```bash
kubectl apply -f gateway.yaml
kubectl apply -f destination-rule.yaml
kubectl apply -f virtual-service.yaml
```

---

## 📊 6. Generează trafic și observă routing-ul

```bash
kubectl exec -it <fortio-pod> -c fortio /usr/bin/fortio curl http://httpbin.default
```

Sau accesează:

```bash
minikube tunnel
```

---

## 🧼 7. Curățare

```bash
kubectl delete -f .
minikube delete
```

---

## 📘 Resurse utile

* [https://istio.io/latest/docs/](https://istio.io/latest/docs/)
* [https://minikube.sigs.k8s.io/docs/](https://minikube.sigs.k8s.io/docs/)
* [https://kubernetes.io/docs/concepts/](https://kubernetes.io/docs/concepts/)

---

📦 Gata! Acum ai un cluster Kubernetes local cu Istio și un canary deployment funcțional pentru test!
