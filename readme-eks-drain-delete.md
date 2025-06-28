# 🧹 Cum să elimini corect un EKS NodeGroup și un Cluster (cu drain și cleanup)

Acești pași demonstrează cum să drenezi noduri în EKS și să elimini complet un NodeGroup sau întregul cluster, într-un mod controlat și sigur.

---

## 🔹 1. Patch la PodDisruptionBudgets (PDB)

Unele componente (ex: `coredns`, `metrics-server`) pot avea restricții PDB care împiedică evicția.

Patch-uim pentru a permite evicția:

```bash
kubectl patch pdb coredns -n kube-system -p '{"spec":{"maxUnavailable": "100%"}}'
kubectl patch pdb metrics-server -n kube-system -p '{"spec":{"maxUnavailable": "100%"}}'
```

---

## 🔹 2. Drain Node

Draining-ul mută podurile active de pe nodul respectiv, ignorând DaemonSet-urile și ștergând datele din EmptyDir:

```bash
kubectl drain ip-192-168-60-9.ec2.internal \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force
```

📌 Exemple de mesaje:

```
Warning: ignoring DaemonSet-managed Pods...
evicting pod kube-system/coredns...
evicting pod kube-system/metrics-server...
node/ip-192-168-60-9.ec2.internal drained
```

---

## 🔹 3. Șterge NodeGroup-ul

După ce nodul a fost drenat complet:

```bash
eksctl delete nodegroup --cluster=eksdemo1 \
                        --name=eksdemo1-ng-public1 \
                        --region=us-east-1
```

---

## 🔹 4. Șterge Clusterul EKS

Dacă vrei să elimini complet întregul cluster EKS:

```bash
eksctl delete cluster eksdemo1 --region=us-east-1
```

---

## ✅ TL;DR – Rezumat

| Pas                          | Comandă                                                               |
|------------------------------|------------------------------------------------------------------------|
| Patch PDB                    | `kubectl patch pdb ...`                                               |
| Drain nod                    | `kubectl drain --ignore-daemonsets --delete-emptydir-data --force`   |
| Șterge nodegroup             | `eksctl delete nodegroup`                                            |
| Șterge cluster               | `eksctl delete cluster`                                              |

Acest proces asigură o eliminare sigură a resurselor fără întreruperi necontrolate sau blocaje.
