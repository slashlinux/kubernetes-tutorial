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

```
#!/bin/bash
set -e

echo "🚀 Installing prerequisites..."
sudo apt update
sudo apt install -y curl wget git make ca-certificates apt-transport-https gnupg lsb-release golang-go conntrack containernetworking-plugins

echo "🐳 Installing Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER

echo "📦 Installing crictl..."
VERSION="v1.29.0"
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar -C /usr/local/bin -xzf crictl-$VERSION-linux-amd64.tar.gz
rm crictl-$VERSION-linux-amd64.tar.gz

echo "📥 Installing cri-dockerd..."
mkdir -p ~/cri-bin && cd ~/cri-bin
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd-0.3.1.amd64.tgz
tar -xzvf cri-dockerd-0.3.1.amd64.tgz
sudo mv cri-dockerd/cri-dockerd /usr/local/bin/cri-dockerd
sudo chmod +x /usr/local/bin/cri-dockerd

cd ~/cri-dockerd
sudo cp -a packaging/systemd/* /etc/systemd/system
sudo sed -i 's:/usr/bin/cri-dockerd:/usr/local/bin/cri-dockerd:' /etc/systemd/system/cri-docker.service
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.socket
sudo systemctl enable --now cri-docker.service

echo "🧩 Installing kubeadm, kubelet, kubectl..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt update
sudo apt install -y kubeadm kubelet kubectl

echo "⬇️ Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

echo "🔥 Starting Minikube with driver=none..."
sudo CHANGE_MINIKUBE_NONE_USER=true minikube start --driver=none


```

* 
# ✅ Minikube Local (Ubuntu 24.04) - Installare cu `--driver=none`

Acest ghid conține **toate comenzile reale testate** pentru instalarea și rularea Minikube cu driver `none` pe Ubuntu 24.04 într-un mediu fără VirtualBox sau KVM.

---

## 🧱 1. Precondiții sistem

```bash
sudo apt update
sudo apt install -y curl wget git make ca-certificates apt-transport-https gnupg lsb-release
```

Instalează Go (dacă lipsește):

```bash
sudo apt install -y golang-go
```

---

## 🐳 2. Instalează Docker Engine

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Permite rularea Docker fără sudo:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Test:

```bash
docker run hello-world
```

---

## 🔧 3. Instalează `cri-dockerd` (fără build local)

```bash
mkdir ~/cri-bin && cd ~/cri-bin
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd-0.3.1.amd64.tgz
tar -xzvf cri-dockerd-0.3.1.amd64.tgz
sudo mv cri-dockerd/cri-dockerd /usr/local/bin/cri-dockerd
sudo chmod +x /usr/local/bin/cri-dockerd
```

Configurează systemd:

```bash
cd ~/cri-dockerd
sudo cp -a packaging/systemd/* /etc/systemd/system
sudo sed -i 's:/usr/bin/cri-dockerd:/usr/local/bin/cri-dockerd:' /etc/systemd/system/cri-docker.service
sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.socket
sudo systemctl enable --now cri-docker.service
```

---

## 🔗 4. Instalează `conntrack`, `crictl`, CNI plugins

```bash
sudo apt install -y conntrack
```

### Instalează `crictl`:

```bash
VERSION="v1.29.0"
curl -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar -C /usr/local/bin -xzf crictl-$VERSION-linux-amd64.tar.gz
rm crictl-$VERSION-linux-amd64.tar.gz
```

### Instalează `containernetworking-plugins`:

```bash
sudo apt install -y containernetworking-plugins
```

---

## 📦 5. Instalează `kubeadm`, `kubectl`, `kubelet`

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg

echo 'deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt update
sudo apt install -y kubeadm kubelet kubectl
```

---

## 🚀 6. Instalează Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

---

## ✅ 7. Pornește Minikube (driver none)

```bash
minikube delete
minikube start --driver=none
```

Testare:

```bash
kubectl get nodes
kubectl get pods -A
```

---

## 🧪 8. Test pod NGINX

```bash
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --type=NodePort --port=80
kubectl get svc nginx
```

---

## 🧹 Cleanup (opțional)

```bash
minikube delete
```

---

> Ghid creat pe baza instalării reale pe Ubuntu 24.04 (driver none, fără VM, fără VirtualBox).
* [istioctl](https://istio.io/latest/docs/setup/getting-started/#download)

---



# 🧠 Kubernetes Control Plane & System Components (Minikube Explained)

Acest `README.md` explică toate componentele Kubernetes vizibile într-un cluster local pornit cu Minikube (`--driver=none`), utile pentru începători și pentru interviuri DevOps.

---

## 📍 `kubectl get nodes`

```
petrisor@petrisor:~$ kubectl get pods -A
NAME       STATUS   ROLES           AGE   VERSION
petrisor   Ready    control-plane   44s   v1.33.1

NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
kube-system   coredns-674b8bbfcf-xc5qk           1/1     Running   0          36s
kube-system   etcd-petrisor                      1/1     Running   0          41s
kube-system   kube-apiserver-petrisor            1/1     Running   0          41s
kube-system   kube-controller-manager-petrisor   1/1     Running   0          41s
kube-system   kube-proxy-fkr6d                   1/1     Running   0          36s
kube-system   kube-scheduler-petrisor            1/1     Running   0          43s
kube-system   storage-provisioner                1/1     Running   0          39s
```

- **`petrisor`** – numele nodului tău (local)
- **`control-plane`** – acest nod rulează toate componentele de orchestrare (nu doar workload-uri)

---

## 📍 `kubectl get pods -A` – explicat componentă cu componentă

### 🔹 1. kube-apiserver-<hostname>

- Piesa centrală a control-plane-ului
- Primește comenzi de la `kubectl`, dashboard sau aplicații externe
- Expune API REST
- Comunicarea internă între componente tot prin API Server se face

### 🔹 2. etcd-<hostname>

- Baza de date **key-value** unde se salvează **toată starea clusterului**
- Ex: ce poduri rulează, ce deployments există, ce configmaps sau secrets sunt definite
- Este un serviciu critic — fără el, clusterul „uită” tot

### 🔹 3. kube-controller-manager-<hostname>

- Rulează toate „control loop”-urile (verifică și reface starea dorită)
- Ex: dacă un deployment are 3 replici și unul pică, el recreează podul
- Alte controale: job-uri, replicaset, garbage collection etc.

### 🔹 4. kube-scheduler-<hostname>

- Decide pe ce nod se lansează fiecare nou pod
- Ține cont de:
  - resurse disponibile (CPU/RAM)
  - afinități și taints
  - zone de disponibilitate

### 🔹 5. kube-proxy-xxxxx

- Se ocupă de **routing-ul traficului intern** între poduri și servicii
- Creează `iptables`/`ipvs` pentru fiecare `Service`
- Rulează pe fiecare nod (worker sau control-plane)

### 🔹 6. coredns-xxxxx

- DNS intern al clusterului
- Transformă adrese ca `nginx.default.svc.cluster.local` în IP-uri interne
- Fiecare pod îl folosește implicit pentru `dnsPolicy: ClusterFirst`

### 🔹 7. storage-provisioner

- În Minikube, creează volume locale temporare
- Răspunde la cereri de `PersistentVolumeClaim`
- Simulează dynamic provisioning exact cum ar face AWS EBS, GCP PD etc.

---

## 📊 Rezumat grafic logic

```
+--------------------+         +-----------------------+
|  kube-apiserver    | <-----> |  etcd (state DB)      |
+--------------------+         +-----------------------+
        ↑   ↓
+-------------------------+
| controller-manager      |
| scheduler               |
+-------------------------+
        ↓
+-----------------------------+
| kubelet + kube-proxy (nod) | <---> CoreDNS
+-----------------------------+
```

---

## 📎 Recomandări pentru învățare

- Rulează `kubectl describe pod -n kube-system <nume>` pentru fiecare componentă
- Verifică logurile: `kubectl logs -n kube-system <pod>`
- Testează pierderea unui pod și vezi cum controller-manager îl reface

> Ghid creat pentru învățare locală pe Ubuntu 24.04 + Minikube v1.36.0


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
