# Accessing AWS S3, RabbitMQ, and PostgreSQL from Pods in Amazon EKS via OIDC / IRSA

> **Goal** – Provide a battle‑tested, production‑ready workflow showing how Kubernetes pods in an EKS cluster can **read & write** to:
>
> * an S3 bucket
> * a RabbitMQ broker
> * a PostgreSQL database (Amazon RDS)
>
> …using **IAM Roles for Service Accounts (IRSA)**, **OIDC federation**, and native AWS network paths.

---

## ✨ Why IRSA instead of classic secrets?

* **Least‑privilege IAM** per workload
* **No long‑lived AWS keys** inside containers
* Works natively with AWS SDKs & CLIs (they auto‑retrieve a web‑identity token)
* Rotate / revoke permissions without redeploying pods

---

## 🗺️ High‑level flow

```
Pod (uses SA: app-sa) ──▶  kube‑api requests projected
                           service‑account token

Pod  ──▶  AWS SDK simultaneously picks up
          projected OIDC web‑identity token

AWS STS (AssumeRoleWithWebIdentity)
    │
    ├─▶  returns temporary creds scoped by IAM Role (irsa‑role‑app)
    │
Pod  ──▶  S3, RDS (PostgreSQL), RabbitMQ (via VPC ENI)
          using the temporary credentials
```

* Network path for S3 = VPC Endpoint → S3 service inside AWS backbone (private).
* Network path for RabbitMQ (if Amazon MQ) = ENI ▶ broker subnet(s).
* Network path for RDS = ENI ▶ subnet DB.

---

## 0 . Prerequisites

| Item                                   | Notes                                      |
| -------------------------------------- | ------------------------------------------ |
| **EKS 1.29**                           | Irrelevant minor version; IRSA works 1.13+ |
| **AWS CLI v2** & **Eksctl ≥ 0.170**    | For snippets                               |
| **Helm**                               | If installing charts                       |
| Route 53 public / private hosted zones | For DB / broker endpoints                  |

---

## 1 . Enable the cluster OIDC provider (once per cluster)

```bash
# Using eksctl (preferred)
eksctl utils associate-iam-oidc-provider \
  --region eu-central-1 \
  --cluster my-eks \
  --approve
```

This creates an **OIDC IdP** in IAM (`oidc.eks.eu-central-1.amazonaws.com/id/ABCDEFG`)
that trusts tokens signed by the EKS control plane.

---

## 2 . Create fine‑grained IAM policies

### 2.1 S3 policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my‑media‑bucket/*"
    }
  ]
}
```

### 2.2 RDS (PostgreSQL) policy (IAM DB auth)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["rds-db:connect"],
      "Resource": "arn:aws:rds-db:eu-central-1:123456789012:dbuser:db‑PXJ5KXO3ABCD/postgres_app"
    }
  ]
}
```

> 🔗 `arn:aws:rds-db:…` is the **DB resource ID**, *not* the ARN of the RDS instance. Get it via `aws rds describe-db-instances --query "DBInstances[].DbiResourceId"`.

### 2.3 RabbitMQ (Amazon MQ) policy *(if using Amazon MQ)*

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "mq:Connect",
        "mq:Get*",
        "mq:Create*"
      ],
      "Resource": "arn:aws:mq:eu-central-1:123456789012:broker:my‑rabbitmq-*"
    }
  ]
}
```

> For self‑hosted RabbitMQ inside the VPC, skip IAM and use Kubernetes `Secret` with username/password.

---

## 3 . Create the IAM Role for Service Account

```bash
# Example with AWS CLI JSON inline (S3 + RDS policies attached)
ROLE_NAME="irsa-role-app"
POLICY_ARN_S3="arn:aws:iam::123456789012:policy/s3-media-policy"
POLICY_ARN_RDS="arn:aws:iam::123456789012:policy/rds-connect-policy"

aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-central-1.amazonaws.com/id/ABCDEFG"},
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {"StringEquals": {"oidc.eks.eu-central-1.amazonaws.com/id/ABCDEFG:sub": "system:serviceaccount:data-plane:app-sa"}}
    }]
  }'

aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${POLICY_ARN_S3}
aws iam attach-role-policy --role-name ${ROLE_NAME} --policy-arn ${POLICY_ARN_RDS}
```

*Change namespace `data-plane` / SA `app-sa` to suit your workload.*

---

## 4 . Create Kubernetes `ServiceAccount` annotated with the role ARN

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: data-plane
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/irsa-role-app
```

Apply:

```bash
kubectl apply -f sa-irsa.yaml
```

---

## 5 . Deploy a demo pod using that Service Account

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: data-plane
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      serviceAccountName: app-sa
      containers:
        - name: app
          image: public.ecr.aws/aws-samples/eks-iam-demo:latest
          env:
            - name: BUCKET
              value: my-media-bucket
```

The demo image runs `aws s3 cp` on a loop; within \~30 seconds you should see successful `200 OK` uploads without any AWS credential env‑vars.

---

## 6 . Database connectivity with IAM token

```bash
# Inside your container or init‑script
aws rds generate-db-auth-token \
  --region eu-central-1 \
  --hostname mydb.cluster‑xyz.eu-central-1.rds.amazonaws.com \
  --port 5432 \
  --username postgres_app
```

Pass the resulting token as **password** to the PostgreSQL client library — valid for 15 minutes.

---

## 7 . RabbitMQ connectivity (Amazon MQ)

1. Determine broker endpoint (ALB DNS if active/standby / ENI IP if cluster).
2. AWS MQ uses IAM for auth: the SDK signs an `mqtt` request with SigV4 once you have IRSA creds.
3. For AMQP 0‑9‑1 you usually stick with user/password — store them in AWS Secrets Manager, mount via Secret Provider Class (csi‑driver‑secrets‑store).

---

## 8 . VPC Networking – who talks to whom?

```
+---------+       (private ENI)        +-----------+
|  Pod A  | ─────────────────────────▶ |  S3 VPCE  |
+---------+                            +-----------+
      │                                   │
      │              AWS backbone         ▼
      │                                 S3 bucket
      │
      │
      │                  ENI             +--------------+
      └─────────────────────────────────▶ |  RDS subnet  |
                                         +--------------+
```

* **S3**: traffic stays inside VPC if S3 Gateway Endpoint configured; else, via NAT.
* **RDS**: uses RDS private DNS → resolves to subnet ENI.
* **RabbitMQ (Amazon MQ)**: ENI in broker subnet; security group must allow the pod subnet CIDRs.

---

## 9 . Audit & troubleshooting

| Check               | Command                                                                           |
| ------------------- | --------------------------------------------------------------------------------- |
| Verify SA has token | `kubectl exec pod -c app -- ls /var/run/secrets/eks.amazonaws.com/serviceaccount` |
| Decode token        | `jwt decode $(cat token)`                                                         |
| See assumed role    | `aws sts get-caller-identity` in the pod                                          |
| ALB / SG issues     | Check `aws elbv2 describe-load-balancers` + SG rules                              |
| RDS auth fail       | verify IAM role allows `rds-db:connect` & token not expired                       |

---

## 10 . Cleanup

```bash
kubectl delete ns data-plane
aws iam detach-role-policy --role-name irsa-role-app --policy-arn ${POLICY_ARN_S3}
aws iam delete-role --role-name irsa-role-app
```

---

### Further reading

* AWS Blog – *Fine‑grained IAM roles for EKS applications*
* AWS Docs – *IAM Roles for Service Accounts (IRSA)*
* AWS Go SDK – *Configuring credential providers*

---

© 2025 Petrisor Ciocoiu – Feel free to adapt.
