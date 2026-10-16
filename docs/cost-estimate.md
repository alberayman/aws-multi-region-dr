# Cost Estimate

> **Approximate on-demand list prices, eu-west-1 / eu-central-1.** Prices change and differ per Region — always confirm with the [AWS Pricing Calculator](https://calculator.aws/) before deploying. Free-tier credits are not included.

## Lab mode (if the design is implemented)

Sized for a build-and-demo session, then destroyed.

| Resource | Lab sizing | ≈ cost / hour |
|---|---|---|
| NAT Gateway | 1 per Region × 2 | ~$0.10 + data |
| Application Load Balancer | 1 per Region × 2 | ~$0.06 + LCUs |
| EC2 | 2 × t3.small primary + 1 × t3.small DR | ~$0.07 |
| Aurora (Serverless v2) | Minimum ACUs, primary + secondary | ~$0.15–0.30 + I/O |
| Public IPv4 addresses | ALB + NAT addresses | ~$0.03 |
| DynamoDB, S3, KMS, Secrets Manager, Route 53, Lambda, SNS | On-demand / per request / monthly | cents |
| **Total** | | **≈ $0.45–0.60 / hour** |

- A 4-hour build + demo ≈ **$2–3**.
- **Left running 24/7 ≈ $350–450 / month** — destroy after every session.

### Cost guardrails
- AWS Budgets alert (e.g. $10/month) with email notification.
- `terraform destroy` both Regions at the end of every session; check for leftover **NAT Gateways, Elastic IPs and Aurora clusters** — these are the usual surprises.
- Tag every resource `Project=saa-dr` and filter Cost Explorer by that tag.

## What warm standby costs in production (relative)

| Layer | Primary | DR (warm standby) |
|---|---|---|
| Compute | 100% | ~25–50% (minimum ASG) |
| Database | 100% | ~100% of one instance (secondary cluster must be able to take the write load once promoted) |
| Networking | 100% | ~100% (ALB, NAT per AZ) |
| Replication | — | Cross-Region data transfer + Aurora replicated write I/O + S3 RTC fee |

Rule of thumb: warm standby adds roughly **40–70%** on top of a single-Region deployment, depending on how much of the bill is database vs compute. That premium is what buys the 15-minute RTO.
