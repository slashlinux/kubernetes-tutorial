# 🔐 IAM Role pentru Kubernetes ServiceAccount (IRSA în EKS)

Acest ghid explică pas cu pas cum atașezi un **IAM Role** unui **ServiceAccount** în Kubernetes, folosind **IRSA (IAM Roles for Service Accounts)**.

---

## 🎯 Scop

Podurile care folosesc acel ServiceAccount vor avea **permisiuni IAM temporare**, fără să conțină **access key/secret key**.

---

## ✅ Pașii Compleți

### 🔹 PAS 1: [Doar o dată per cluster] – Verifici OIDC provider

```bash
aws eks describe-cluster --name <cluster-name> \
  --query "cluster.identity.oidc.issuer" --output text
```

✅ Dacă primești un URL precum:
```
https://oidc.eks.eu-central-1.amazonaws.com/id/EXAMPLE123
```
=> IRSA este activat.

---

### 🔹 PAS 2: Creezi IAM Role cu trust policy pentru IRSA

```json
// trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/<oidc-id>"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.eu-central-1.amazonaws.com/id/<oidc-id>:sub": "system:serviceaccount:<namespace>:<serviceaccount-name>"
        }
      }
    }
  ]
}
```

---

### 🔹 PAS 3: Creezi rolul în AWS

```bash
aws iam create-role \
  --role-name my-irsa-s3-role \
  --assume-role-policy-document file://trust-policy.json
```

---

### 🔹 PAS 4: Atașezi politica de acces

```bash
aws iam attach-role-policy \
  --role-name my-irsa-s3-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

---

### 🔹 PAS 5: Creezi ServiceAccount în Kubernetes

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-access-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/my-irsa-s3-role
```

```bash
kubectl apply -f serviceaccount.yaml
```

---

### 🔹 PAS 6: Folosești SA în pod/deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s3-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: s3-app
  template:
    metadata:
      labels:
        app: s3-app
    spec:
      serviceAccountName: s3-access-sa
      containers:
        - name: app
          image: your-repo/s3-app:latest
```

---

### 🧪 PAS 7: Testezi în pod

```bash
curl http://169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
```

✅ Vei vedea token-ul temporar AWS generat de IRSA.

---

## ℹ️ Ce este `$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`?

| Variabilă | Setată de | Conținut | Folosită de |
|-----------|-----------|----------|-------------|
| `$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` | AWS EKS / ALB controller | Endpoint relativ pt token IAM temporar | SDK AWS Java, Python, etc |

📦 Exemplu:

```bash
$ echo $AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
/v2/credentials/abcd1234-5678

$ curl http://169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI
{
  "AccessKeyId": "...",
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "2025-06-26T12:45:01Z"
}
```

---

## ✅ TL;DR – Rezumat

| Ce creezi          | Cum                                                       |
|---------------------|------------------------------------------------------------|
| IAM Role            | Cu trust policy pentru IRSA                                |
| AWS Policy          | Atașată role-ului                                          |
| ServiceAccount K8s  | Cu `eks.amazonaws.com/role-arn` în metadata.annotations    |
| Deployment          | Folosește acel ServiceAccount                              |

---

Dacă vrei un script complet Terraform pentru această configurație, cere și îl primești. 😉
