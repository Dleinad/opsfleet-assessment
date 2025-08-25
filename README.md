# Innovate Inc Proposed Cloud Architecture

1) The front door: users → DNS → WAF/Edge → Public ALB

A customer types app.yourco.com.
Route 53 answers with where to go. (Optionally) CloudFront + WAF sit in front to cache static bits and swat away junk traffic and obvious attacks.

Traffic lands on a public ALB in the target environment (dev/test/stage/prod). The ALB terminates TLS with ACM certs and routes by host/path to the right app.

Why this exists: a clean, global entry that’s secure, fast, and easy to route per environment and per service.

2) Inside the fence: per-environment VPCs

Each environment has its own VPC with public subnets (for ALBs/NAT) and private subnets (for EKS nodes, databases, etc.). An Internet Gateway handles inbound for public things; NAT Gateways allow private workloads to fetch images or talk to SaaS without being exposed.

Why this exists: hard isolation (blast radius control) and predictable networking/Security Groups per env.

3) The app neighborhood: EKS cluster

In each VPC sits an EKS cluster:
A tiny managed node group (on-demand x86) runs the “plumbing”: the AWS Load Balancer Controller, CSI drivers, Argo CD/Flux, Kyverno, metrics agents, etc. Karpenter is your “smart landlord” for app capacity. When pods can’t schedule, it spins up the best-fit EC2 nodes on the fly:

You’ve got NodePools for amd64 (x86) and arm64 (Graviton). You can use Spot for price/perf or On-Demand for critical workloads.

It listens to EventBridge → SQS for spot interruption warnings and gracefully replaces nodes. Consolidation and expiration keep nodes right-sized and fresh.

Why this exists: fast scale, cheaper nodes (hello Graviton + Spot), and zero YAML fiddling for developers.

4) Traffic inside the cluster: Ingress → Service → Pods

The AWS Load Balancer Controller creates ALBs from Kubernetes Ingress objects. Requests go ALB → Ingress → Service → your pods. If you also run an internal ALB, that’s for backstage UIs or service-to-service traffic that shouldn’t be public.

Why this exists: simple L7 routing and TLS offload with native AWS bits your team already knows.

5) State and messages: the data cul-de-sac

Your apps talk to:
- RDS/Aurora (Postgres in private subnets for transactional data.
- ElastiCache/Redis for hot keys, sessions, rate limits, low-latency reads.
- S3 buckets for uploads, artifacts, and backups (with lifecycle rules).
- OpenSearch (or Loki/CloudWatch Logs) for log search and ops forensics.

Access from pods is granted via IRSA/Pod Identity (role per service account), not static keys.

Why this exists: clean separation of concerns—fast reads in cache, durable data in RDS, cheap storage in S3, resilient async with queues.

6) How code and Infra gets here: CI/CD & GitOps

Infra is done with Terraform running through a github actions pipeline.

Your CI (GitHub Actions) builds, tests, scans, and pushes images to ECR.

Argo CD Git (Helm) and syncs clusters. Rollbacks are just “git revert.”

Why this exists: predictable, auditable releases; no humans hand-applying manifests on Fridays.

7) Seeing and knowing: observability

Logs: agents (Loki) ship to Grafana.

Metrics: Prometheus scrapes; Grafana dashboards; autoscaling signals come from metrics or Karpenter’s bin-packing view.

Traces: OTEL/X-Ray/Tempo/Datadog (depending on your stack).

Alarms: CloudWatch + SNS (or PagerDuty) wake the right humans.

Why this exists: you can’t run what you can’t see. This is your early-warning system and your root-cause flashlight.

8) Guardrails: security & access

- Palo Alto Firewall serves as the main gatekeeper, scrutinizing all incoming traffic
- Security Groups fence off who can talk to whom.
- IAM + IRSA scope AWS permissions to each workload.
- Secrets Manager/SSM store secrets; no secrets in images or Git.
- SSM Session Manager replaces old SSH bastions—auditable, ephemeral access.

Why this exists: default-deny posture without crushing developer velocity.

9) Insurance: backups & Disaster Recover

- Automated DB snapshots and/or AWS Backup policies for RDS.
- Real time replication of database to secondary region
- Cross-AZ by default; cross-region where RTO/RPO demand it.
- S3 versioning/lifecycle to keep costs sane and recovery reliable.
- Disaster Recovery Account and Cluster for Failover Scenarios

Why this exists: stuff happens. You want restore buttons that actually work.