# Game-Day Test Plan

Each test lists the method, expected result and the evidence to capture (save screenshots under `evidence/` as `T<nn>-<name>.png`).

| # | Test | Method | Expected result | Evidence |
|---|---|---|---|---|
| T01 | App reachable through primary | `curl -I https://app.example.com` | `200`, response header shows `region: eu-west-1` | curl output |
| T02 | Instances not reachable from the internet | Try to connect to an EC2 private IP / no public IP assigned | Connection impossible; instances have no public IP | EC2 console networking tab |
| T03 | Database not reachable from the internet | Aurora `PubliclyAccessible = false`; SG allows 3306/5432 **only** from app SG | Connection refused from laptop | SG rules + `nc` timeout |
| T04 | Session Manager access works, SSH closed | Start session via SSM; port 22 absent from SGs | Shell opens; no inbound 22 | SSM session screenshot |
| T05 | WAF blocks malicious request | `curl "https://app.example.com/?id=1' OR '1'='1"` | `403` from WAF | WAF sampled requests |
| T06 | Primary Multi-AZ resilience | Terminate one EC2 instance | ASG replaces it; no user-visible outage | ASG activity history |
| T07 | Aurora replication lag | Write a row in primary, read it in DR reader | Row visible in DR within ~1 s | `AuroraGlobalDBReplicationLag` graph |
| T08 | S3 replication | Upload object to primary bucket | Object appears in DR bucket, replication status `COMPLETED` | `aws s3api head-object` output |
| T09 | DynamoDB global table | Create session in eu-west-1, read in eu-central-1 | Item present in DR | Console / CLI output |
| T10 | **Regional failover (simulated)** | Block health-check path: set primary ALB listener rule `/health` → fixed `503` | Route 53 flips to SECONDARY in ~90 s; `dig` shows DR ALB | Route 53 health-check graph + `dig` |
| T11 | Automated scale-out | Observe after T10 | Lambda invoked; DR ASG desired = prod size; SNS email received | Lambda logs, ASG history, email |
| T12 | Approval-gated DB promotion | Approve SSM Automation | DR cluster becomes writer; writes succeed in DR | SSM execution + RDS console |
| T13 | Measured RTO / RPO | Timestamp T10 start → T12 writes OK; compare last primary row vs DR | RTO ≤ 15 min, RPO ≤ 1 min | Timeline table |
| T14 | Failback (switchover) | Rebuild primary, run `switchover-global-cluster` | Primary is writer again, no data loss | RDS console + row count check |
| T15 | Backup restore | Restore latest cross-Region Aurora backup to a new cluster | Restore succeeds in DR Region | AWS Backup restore job |
| T16 | Clean-up verified | `terraform destroy` both Regions | No NAT GWs, EIPs, Aurora clusters left | Cost Explorer / console |

## Result log

| Test | Date | Pass/Fail | Notes |
|---|---|---|---|
| T01 | | | |
| T10 | | | |
| T13 | | | RTO = __ min, RPO = __ s |
