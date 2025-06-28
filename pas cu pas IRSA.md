
# 🛡️ IRSA (IAM Roles for Service Accounts) în Amazon EKS

Acest ghid oferă pașii complet corecți și în ordine logică pentru a configura accesul la resursele AWS din poduri EKS, folosind IRSA.

---

## 🔧 PAS CU PAS – Configurare IRSA pentru EKS

### ✅ 1. Creezi IAM Roles (cu Trust către OIDC al EKS)

#### a. S3 IAM Role:
```bash
aws iam create-role \
  --role-name s3-iam-role \
  --assume-role-policy-document file://trust-policy.json
```

#### b. PostgreSQL IAM Role (pentru IAM Auth RDS):
```bash
aws iam create-role \
  --role-name rds-iam-role \
  --assume-role-policy-document file://trust-policy.json
```

#### c. RabbitMQ IAM Role (dacă folosești AWS MQ):
```bash
aws iam create-role \
  --role-name rabbitmq-iam-role \
  --assume-role-policy-document file://trust-policy.json
```

> ℹ️ Dacă RabbitMQ e în Kubernetes, **nu ai nevoie** de IAM Role pentru el.

---

### ✅ 2. Atașezi politici IAM

Exemplu pentru S3:
```bash
aws iam attach-role-policy \
  --role-name s3-iam-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

---

### ✅ 3. Creezi un `ServiceAccount` în Kubernetes

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sa-s3
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::975050111127:role/s3-iam-role
```

---

### ✅ 4. Asociezi ServiceAccount-ul cu microserviciul (în `deployment.yaml`)

```yaml
spec:
  serviceAccountName: sa-s3
```

---

### ✅ 5. Testezi accesul din pod (opțional)

```bash
aws s3 ls s3://my-bucket-name --region us-east-1
```

---

## 🧩 trust-policy.json (exemplu)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::975050111127:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED6AABCD7E952B660EXAMPLE"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED6AABCD7E952B660EXAMPLE:sub": "system:serviceaccount:default:sa-s3"
        }
      }
    }
  ]
}
```

> 🛠️ Înlocuiește `EXAMPLED6AABCD7E952B660EXAMPLE` cu OIDC ID-ul tău și `default` cu namespace-ul tău.

---

## 🔍 Cum afli `eks-oidc-id` și namespace

### 1. Află OIDC ID-ul EKS:
```bash
aws eks describe-cluster \
  --name eksdemo1 \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text
```

### 2. Află namespace-ul:
```bash
kubectl get ns
```
sau folosește `default`.

---

## ✅ Comandă rapidă pentru asociere OIDC cu clusterul:

```bash
eksctl utils associate-iam-oidc-provider \
    --region us-east-1 \
    --cluster eksdemo1 \
    --approve
```

---

## 📌 TL;DR:

- [x] Creezi roluri IAM cu trust pe OIDC
- [x] Atașezi politici restrictive per resursă
- [x] Creezi `ServiceAccount` cu ARN
- [x] Îl legi în `Deployment`
- [x] Testezi accesul cu AWS CLI din pod

---

## 📎 Scurtă recapitulare vizuală:

```
[POD] → [SA cu rol IAM] → [STS] → [AssumeRoleWithWebIdentity] → [IAM Role] → [Resursă AWS (S3, RDS)]
```
