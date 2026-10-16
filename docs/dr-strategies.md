# AWS Disaster Recovery Strategies

AWS describes four DR strategies, ordered from cheapest/slowest to most expensive/fastest. Two numbers decide between them:

- **RTO (Recovery Time Objective)** — how long the business can tolerate the service being down.
- **RPO (Recovery Point Objective)** — how much data (measured in time) the business can afford to lose.

## Comparison

| | Backup & Restore | Pilot Light | **Warm Standby** | Multi-Site Active/Active |
|---|---|---|---|---|
| **RTO** | Hours | 10s of minutes | **Minutes** | Near zero |
| **RPO** | Hours | Seconds–minutes | **Seconds** | Near zero |
| **DR Region compute** | None | None (AMIs/templates only) | **Scaled-down, running** | Full production |
| **DR Region data** | Backups only | Live replica | **Live replica** | Live, multi-writer |
| **Serves traffic before failover?** | No | No | **Health checks / reads** | Yes |
| **Failover work** | Restore data + build everything | Start/scale compute, promote DB | **Scale out, promote DB** | Re-route only |
| **Relative cost** | $ | $$ | **$$$** | $$$$ |

## How each would look for this application

### Backup & Restore
AWS Backup copies Aurora snapshots and EBS/S3 backups to eu-central-1. On disaster, Terraform builds the whole stack and restores the latest snapshot. Cheap, but restore + build easily takes hours, and RPO equals the backup interval.

### Pilot Light
Aurora Global Database secondary and DynamoDB global tables run in DR (the "pilot light"). The ALB, launch template and ASG exist but with **0** instances. Failover requires scaling from zero — adds AMI boot and warm-up time to RTO, and nothing proves the DR app tier actually works until the incident.

### Warm Standby ✅ (chosen)
Everything from Pilot Light **plus** a running, minimum-size app tier behind a live ALB. Route 53 can health-check the DR stack continuously, so we *know* it works. Failover = scale out + promote database.

### Multi-Site Active/Active
Both Regions take production writes. Requires a data model that tolerates multi-Region writes (DynamoDB global tables can; a single-writer Aurora Global Database cannot without write-forwarding trade-offs) and conflict handling. Justified only when RTO/RPO must be near zero.

## Why Warm Standby here

| Requirement | Backup & Restore | Pilot Light | Warm Standby | Active/Active |
|---|---|---|---|---|
| RTO ≤ 15 min | ❌ | ⚠️ borderline | ✅ | ✅ |
| RPO ≤ 1 min | ❌ | ✅ | ✅ | ✅ |
| DR stack proven continuously | ❌ | ❌ | ✅ | ✅ |
| No multi-writer redesign | ✅ | ✅ | ✅ | ❌ |
| Cost proportional to risk | ✅ | ✅ | ✅ | ❌ |

Warm Standby is the cheapest option that meets **all** requirements.

## Reference
- [Disaster Recovery of Workloads on AWS (whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-options-in-the-cloud.html)
- [AWS Well-Architected — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
