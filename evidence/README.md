# Game-Day Evidence

Proof that each test in [`docs/test-plan.md`](../docs/test-plan.md) was **actually run** against a deployed stack. Nothing in this folder is simulated: if a test has not been run yet, its row in the result log says `Not run`.

> **Status:** ⏳ Not run yet — the stack has not been deployed. RTO/RPO in the README are **design targets** until T13 is filled in.

## Naming convention

```
evidence/
├── T01-app-primary.png
├── T05-waf-block.png
├── T10-route53-healthcheck.png
├── T10-dig-before.txt / T10-dig-after.txt
├── T13-probe.csv          ← output of scripts/probe.sh
├── T13-rpo-markers.txt    ← last marker in primary vs DR
└── ...
```

`T<nn>-<short-name>.<png|txt|csv>` — one file per piece of proof, `<nn>` matching the test ID.

## What a good screenshot shows

- The **Region** selector (top-right of the console) — proves where it happened.
- A **timestamp** (CloudWatch graph time axis, ASG activity time, terminal `date -u`).
- The **result itself** (e.g. `403` from WAF, `COMPLETED` replication status, `writer` role on the DR cluster).

## Redact before committing ⚠️

This repo is public. Before `git add evidence/`:

| Redact | Where it appears |
|---|---|
| AWS account ID (12 digits) | Console account menu, every ARN |
| IAM user / role names, SSO email | Console top-right, CloudTrail |
| Public IPs of your home/office network | WAF sampled requests, VPC flow logs, `curl -v` |
| Access keys, session tokens, secrets | Terminal output — should never be on screen |

Quick check before committing:

```bash
grep -rnE "[0-9]{12}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}" evidence/ docs/ README.md
```

For screenshots, crop or blur in Preview (**Tools → Annotate → Rectangle**, filled). Blur is reversible-ish at low radius; a filled box is not.

## Measuring RTO (T13)

Run the probe from **outside AWS** (your laptop) before starting T10 and stop it after T12 succeeds:

```bash
./scripts/probe.sh https://app.example.com/health 5 | tee evidence/T13-probe.csv
```

**RTO** = time of the first non-`200` row → time of the first `200` row whose `region_header` is `eu-central-1` **and** a write succeeds (T12).

## Measuring RPO (T13)

1. Create a marker table in the primary database:
   ```sql
   CREATE TABLE dr_marker (seq BIGINT PRIMARY KEY, written_at TIMESTAMP(3));
   ```
2. From an app instance (via Session Manager), insert one row per second during T10:
   ```bash
   i=0; while true; do i=$((i+1))
     mysql --defaults-extra-file=~/.dr.cnf -h "$DB_WRITER" app \
       -e "INSERT INTO dr_marker VALUES ($i, NOW(3));"
     sleep 1; done
   ```
   `~/.dr.cnf` (mode `600`) holds `[client] user=… password=…` pulled from Secrets Manager, so the password never appears on screen or in the process list (`-p<password>` would). PostgreSQL: use `psql` with a `~/.pgpass` file and `now()`. Delete the file after the test.
3. After promotion, compare:
   ```sql
   SELECT MAX(seq), MAX(written_at) FROM dr_marker;   -- run on old primary (if reachable) and on new DR writer
   ```

**RPO** = `written_at` of the last row in primary − `written_at` of the last row in DR. Save both outputs to `T13-rpo-markers.txt`.

> When you simulate failure with a `503` on `/health` (T10), the primary database is still healthy, so a planned **switchover** shows RPO = 0. To measure a realistic RPO, use the unplanned `failover-global-cluster --allow-data-loss` path in T12 and note which one you used.
