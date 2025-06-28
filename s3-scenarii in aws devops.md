# 📦 DevOps Taskuri Reale cu AWS S3

Acest document sumarizează cele mai frecvente taskuri pe care le fac DevOps engineers cu AWS S3, folosind instrumente precum Jenkins, Helm, Terraform și AWS SDK-uri.

---

## 🟡 1. Upload / Download de fișiere din S3

| Task                                                | Tool / Limbaj                        |
|-----------------------------------------------------|--------------------------------------|
| Upload loguri aplicație din poduri EKS în S3        | `boto3`, `aws s3 cp`, `fluent-bit`  |
| Download artifact `.tgz` pentru Helm în Jenkins     | `aws s3 cp` în script shell          |
| Backup DB (PostgreSQL dump) și încărcare în S3      | `cronjob` + `pg_dump`                |
| Restore din backup (download S3 → aplicație)        | `aws-sdk`, `boto3`, sau `curl` semnat|
| Export rapoarte PDF/CSV din aplicație în S3         | Aplicație scrisă în Java sau Python  |

---

## 🟢 2. Securitate și acces (IAM & IRSA)

| Task                                                      | Soluție                                                       |
|-----------------------------------------------------------|---------------------------------------------------------------|
| Setare IRSA ca podurile să scrie în bucket                | IAM role + trust policy pentru EKS                            |
| Creare bucket privat + policy only from specific VPC      | Terraform + `aws_s3_bucket_policy`                            |
| Limitare acces doar la un prefix                          | IAM policy cu `arn:aws:s3:::bucket-name/folder/*`             |
| Stocare artifacte build + TTL 7 zile                      | Lifecycle policy în Terraform                                 |
| Acces temporar (STS signed URL) pentru clienți externi    | `aws sts` + `generate_presigned_url()` în `boto3`             |

---

## 🔵 3. Automatizări cu Terraform / CI/CD

| Task                                                              | Tool                                      |
|-------------------------------------------------------------------|-------------------------------------------|
| Creează bucket pentru artefacte cu Terraform                      | `aws_s3_bucket` + `aws_s3_bucket_versioning` |
| Push artifact după build Maven către S3                           | Jenkins stage cu `aws s3 cp`              |
| Rulează `terraform apply` doar dacă fișierul a apărut în S3       | `aws s3 ls` + condiție în pipeline        |
| Mount S3 ca sistem de fișiere într-un EC2                         | `s3fs` sau `goofys`                        |
| Upload Helm chart (`.tgz`) ca release într-un bucket S3           | `helm package && aws s3 cp`               |

---

## 🔴 4. Event-driven & Logging

| Task                                                         | Soluție                                                   |
|--------------------------------------------------------------|------------------------------------------------------------|
| Trigger Lambda când se urcă fișier nou în S3                | S3 Event Notification → Lambda                            |
| S3 access logs → alt bucket                                  | `aws_s3_bucket_logging` config                            |
| Monitorizare spațiu ocupat în bucket                         | `aws s3 ls --summarize --human-readable --recursive`      |
| Trimitere notificare Slack când apare un fișier nou         | Event → SNS → Lambda → Slack API                          |
| Parsare automată loguri nginx puse în S3                    | Lambda + Athena + Glue                                    |

---

## ⚫ Bonus: CI/CD + Helm + S3

- Jenkins job build → zip → upload `.zip` în S3 → alt job îl ia din S3 și face `helm upgrade`
- Pipeline de deploy cu artifact din JFrog/S3 → helm chart version injectat din `artifact.json` (descărcat din S3)
- Fiecare release push-uit într-un S3 versionat (cu metadata în DynamoDB)

---

## ⚙️ TL;DR

DevOps taskuri cu S3 sunt frecvente și includ:
- Backup/restaurare
- CI/CD artifacts
- Helm charts
- Logs
- Lambda triggers
- Securitate cu IRSA
- Automatizări Terraform
