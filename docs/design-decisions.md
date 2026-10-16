# Architecture Decision Records

Each decision lists the options considered, the choice, and the trade-off accepted.

---

## ADR-01 — Region pair: eu-west-1 → eu-central-1

| Option | Pros | Cons |
|---|---|---|
| us-east-1 → eu-west-1 (as in the original brief) | Largest service catalogue | Personal data leaves the EU; extra GDPR transfer controls |
| **eu-west-1 → eu-central-1** | Both EU, low latency between them, all services in this design available | Frankfurt is often slightly pricier than Ireland |
| eu-west-1 → eu-west-2 (London) | Close | UK is outside the EU (adequacy decision, but another legal regime to track) |

**Decision:** eu-west-1 primary, eu-central-1 DR. **Trade-off:** small price premium in DR for simpler data-residency compliance.

---

## ADR-02 — DNS failover with Route 53 health checks (not manual)

- **Options:** manual DNS change · Route 53 failover routing + health checks · Route 53 Application Recovery Controller (ARC) routing controls / Region switch · Global Accelerator.
- **Decision:** Route 53 failover routing with health checks. Failover happens in the Route 53 **data plane**, which keeps working even if the Route 53 control plane or the console is impaired.
- **Trade-off:** clients that cache DNS beyond the 60 s TTL fail over later. ARC (routing controls / Region switch) is the upgrade path for operator-controlled, auditable switching; Global Accelerator avoids DNS caching but adds cost.

---

## ADR-03 — Health check depth

- **Shallow** (`/health` returns 200 if the web server is up) — stable, but misses a dead database.
- **Deep** (checks DB, cache, dependencies) — catches more, but a short DB blip can flip the whole Region → **flapping**.
- **Decision:** `/health` checks the app **and** a cached (≤10 s) DB connectivity probe; Route 53 requires **3 consecutive failures at 30 s** intervals.
- **Trade-off:** ~90 s of detection time in exchange for avoiding false failovers.

---

## ADR-04 — Database: Aurora Global Database

| Option | RPO | Notes |
|---|---|---|
| RDS cross-Region read replica | Seconds–minutes (async binlog/WAL) | Promotion is manual, replica endpoint changes |
| **Aurora Global Database** | Typically **< 1 s** | Storage-level replication, dedicated infrastructure, managed switchover/failover, **global writer endpoint** |
| DynamoDB only | ~1 s | Would require re-modelling the relational data |

**Decision:** Aurora Global Database. The app connects through the **global writer endpoint**, so after promotion it follows the new writer without config changes.

**Bonus — split-brain protection:** if DNS flips to DR because of a false alarm while the primary DB is still healthy, DR app instances still write to the *primary* writer through the global endpoint. There is never more than one writer.

---

## ADR-05 — Automate scale-out, gate database promotion

| Action | Reversible? | Blast radius | Automation |
|---|---|---|---|
| Scale DR ASG to production size | Yes (scale back in) | Cost only | **Automatic** (Lambda) |
| Notify on-call | — | None | **Automatic** (SNS) |
| Aurora `failover-global-cluster --allow-data-loss` | **No** (old primary must resync or be rebuilt) | Possible loss of last ~1 s of writes | **Human approval** (SSM Automation `aws:approve`) |

**Decision:** automate the safe steps, keep a human in the loop for the irreversible one. **Trade-off:** adds a few minutes to RTO; still within 15 min.

---

## ADR-06 — Sessions in DynamoDB global tables

Storing sessions on EC2 would log every user out on failover. DynamoDB global tables are active-active, so sessions are already in DR — **no failover action needed** for this data. On-demand capacity keeps standby cost near zero.

---

## ADR-07 — IaC: Terraform (vs CloudFormation StackSets)

| | Terraform (provider aliases) | CloudFormation StackSets |
|---|---|---|
| Multi-Region deploy | One root module, `provider "aws" { alias = "dr" }` | Native: one template → many Regions/accounts |
| Cross-Region references (e.g. Aurora global cluster, KMS replica) | Natural in one plan | Needs exports/parameters per Region |
| State | Remote state (S3 + locking) to manage | Managed by AWS |
| Portability / career value | High | AWS-only |

**Decision:** Terraform with one reusable module instantiated per Region. StackSets is the AWS-native alternative and the expected exam answer for "deploy identical stacks to many Regions/accounts".

---

## ADR-08 — Backups in addition to replication

Replication copies mistakes instantly. AWS Backup daily plans with **cross-Region copy** (and Aurora PITR) provide recovery from logical corruption and ransomware-style deletion. Optional hardening: AWS Backup Vault Lock (WORM).

---

## ADR-09 — Lab cost controls

- 1 NAT Gateway per Region in the lab (production: 1 per AZ — otherwise an AZ failure breaks outbound access for the other AZ).
- Aurora Serverless v2 at minimum ACUs in the lab (production: provisioned `db.r*` sized from load tests). Check the Aurora docs that your engine version supports Serverless v2 in a global database.
- Everything is destroyed after each demo; an AWS Budgets alert is set at a low monthly threshold.
