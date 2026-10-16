# Failover & Failback Runbook

> **Scope:** unplanned loss of eu-west-1 for the application. **Owner:** on-call engineer. **Decision authority for database promotion:** incident commander (in a real organisation, follow the change/incident process — promotion with possible data loss is a business decision, not only a technical one).

## 0. Detection (automatic)

| Time | Event |
|---|---|
| T+0 | Primary ALB `/health` starts failing |
| T+~90 s | Route 53 marks primary unhealthy (3 × 30 s) → DNS answers **SECONDARY** |
| T+~90 s | `HealthCheckStatus` alarm (us-east-1) → EventBridge → DR bus |
| T+~2 min | Lambda sets DR ASG `desired = 2` (prod size), SNS pages on-call |

## 1. Confirm the incident (≤ 5 min)

- [ ] Check the [AWS Health Dashboard](https://health.aws.amazon.com/health/status) and the account's Personal Health Dashboard.
- [ ] Confirm from **outside AWS** (e.g. a laptop on mobile data): `curl -I https://app.example.com/health`.
- [ ] Check Aurora replication lag in eu-central-1: CloudWatch metric `AuroraGlobalDBReplicationLag`.
- [ ] Decide: **transient** (wait, do not promote) or **Regional impairment** (continue).

## 2. Promote the database (approval required)

The SSM Automation document `DR-PromoteAuroraGlobal` pauses at `aws:approve`. Approve it in the SSM console (DR Region) or:

```bash
aws ssm send-automation-signal \
  --region eu-central-1 \
  --automation-execution-id <execution-id> \
  --signal-type Approve
```

The document then runs the equivalent of:

```bash
aws rds failover-global-cluster \
  --region eu-central-1 \
  --global-cluster-identifier app-global \
  --target-db-cluster-identifier arn:aws:rds:eu-central-1:<acct>:cluster:app-dr \
  --allow-data-loss
```

- [ ] Wait for the DR cluster to report **writer**.
- [ ] App keeps using the **global writer endpoint** — no config change.

## 3. Verify service (≤ 15 min total)

- [ ] `dig app.example.com` returns the DR ALB.
- [ ] Log in, create a record, read it back (proves DB writes work in DR).
- [ ] Existing session still valid (proves DynamoDB global table).
- [ ] Static assets load (proves S3 replica).
- [ ] Record the incident timeline → actual RTO and RPO.

## 4. Communicate

- [ ] Status update to stakeholders: impact window, current state (running in DR), next update time.

---

## Failback (planned, after eu-west-1 recovers)

1. **Re-establish** eu-west-1 as a *secondary*. After an unplanned failover Aurora tries to re-add the old primary cluster as a secondary once the Region recovers; if it cannot, re-create it with Terraform and add it to the global cluster.
2. **Wait** until `AuroraGlobalDBReplicationLag` is stable and near zero.
3. **Switchover** in a maintenance window (no data loss):
   ```bash
   aws rds switchover-global-cluster \
     --global-cluster-identifier app-global \
     --target-db-cluster-identifier arn:aws:rds:eu-west-1:<acct>:cluster:app-primary
   ```
4. Restore Route 53 health check on the primary; confirm DNS returns PRIMARY.
5. Scale the DR ASG back to `min 1 / desired 1`.
6. Hold a blameless post-incident review and update this runbook.
