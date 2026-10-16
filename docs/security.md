# Security & Compliance Controls

Mapped to the AWS Well-Architected **Security Pillar**. Every control applies to **both** Regions — a DR Region with weaker security is an attacker's easiest way in.

## Network
- Three subnet tiers per AZ; only the ALB and NAT Gateways sit in public subnets.
- **Security group chaining:** `alb-sg` (443 from internet) → `app-sg` (app port from `alb-sg` only) → `db-sg` (DB port from `app-sg` only).
- No inbound SSH anywhere; admin access through **SSM Session Manager** (logged to CloudWatch Logs / S3).
- VPC endpoints for SSM, Secrets Manager, KMS, S3 and DynamoDB keep AWS API traffic off the internet and reduce NAT data charges.
- AWS WAF on each ALB: AWS managed core rule set, known-bad-inputs, SQLi rules, rate-based rule.

## Identity
- Humans use IAM Identity Center (SSO) — no IAM users with long-lived keys.
- **Lambda runbook role:** only `autoscaling:UpdateAutoScalingGroup` on the DR ASG ARN and `sns:Publish` on the DR topic.
- **SSM Automation role:** only `rds:FailoverGlobalCluster` / `rds:Describe*` on the global cluster; approvers limited to an on-call IAM role.
- EC2 instance profile: read the app secret, write logs — nothing else.

## Data
- **KMS multi-Region keys** (primary in eu-west-1, replica in eu-central-1) encrypt Aurora, EBS, S3, DynamoDB, Secrets Manager and backups — DR does not depend on a key in the failed Region.
- Secrets Manager secret replicated to DR; automatic rotation enabled.
- TLS everywhere: ACM cert on ALB, TLS to Aurora enforced by parameter group.
- S3: Block Public Access, versioning (required for CRR), bucket policy denying non-TLS requests.
- AWS Backup with cross-Region copy; optional **Vault Lock** for immutable backups.

## Detection & audit
- CloudTrail organisation trail, all Regions, log file validation on.
- AWS Config rules (e.g. `rds-storage-encrypted`, `restricted-ssh`, `s3-bucket-public-read-prohibited`).
- Optional: GuardDuty and Security Hub in both Regions.

## Compliance notes
- Both Regions are in the EU, which simplifies GDPR data-residency obligations.
- DR tests (game days) produce evidence for audits that ask "is the recovery plan tested?" (e.g. ISO 27001 business-continuity controls).
- Regulated workloads usually also need a documented, approved DR policy and defined RTO/RPO sign-off by the business — this design supplies the technical part only.
