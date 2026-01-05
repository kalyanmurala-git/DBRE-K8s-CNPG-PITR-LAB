**PostgreSQL Point-in-Time Recovery (PITR) using CloudNativePG on Kubernetes**

🔍 Objective
To practice and validate PostgreSQL Point-in-Time Recovery (PITR) using:
•	Kubernetes (Minikube – single node lab)
•	CloudNativePG (CNPG) operator
•	Amazon S3 as backup + WAL archive destination
Instead of restoring in-place, a new PostgreSQL cluster was created and restored to a specific timestamp, which is the recommended and safest PITR approach.


🧠 Why CloudNativePG for PITR?
CloudNativePG is purpose-built for PostgreSQL on Kubernetes and offers:
•	Native PostgreSQL streaming replication
•	Built-in Barman-based backups
•	WAL archiving to object storage (S3)
•	Declarative recovery (PITR) using Kubernetes CRDs
•	No external backup tooling or cron jobs required
👉 Important:
We did not use Helm for the operator — CNPG was installed directly via YAML manifests, which is fully supported and production-grade.

🏗 Architecture (Lab Setup)
⚠️ Note: This is a single-node Minikube lab, used only to learn concepts.
•	Kubernetes: Minikube (1 node)
•	PostgreSQL version: 16.x
•	CNPG instances:
           PITR source cluster → 1 primary
           PITR restored cluster → new cluster
•	Backups:
           Base backup → S3
           WAL files → S3
•	Storage:
           PVC for live data
           S3 for recovery data



🧩 Step-by-Step: What Was Achieved


**1️ Install CloudNativePG Operator**
#kubectl apply --server-side --force-conflicts \
-f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml


**Verify:**

#kubectl get pods -n cnpg-system

**2. Create PostgreSQL Cluster with S3 Backup + WAL Archiving**

Key configuration:
•	barmanObjectStore → S3 bucket
•	WAL compression enabled
•	AWS credentials stored as Kubernetes secret

Apply:
#kubectl apply -f pg-ha-pitr.yaml


**3️.  Verify Cluster & Primary**
kubectl get cluster -n database
kubectl get pods -n database


       Check primary:
         kubectl exec -n database pg-ha-pitr-1 -- \
         psql -U postgres -c "SELECT pg_is_in_recovery();"

**4. Check primary:**

kubectl exec -n database pg-ha-pitr-1 -- \
psql -U postgres -c "SELECT pg_is_in_recovery();"


Create Database and Test Data
kubectl exec -n database pg-ha-pitr-1 -- psql -U postgres

CREATE DATABASE pitr_lab;
\c pitr_lab

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  amount INT,
  created_at TIMESTAMP DEFAULT now()
);

INSERT INTO orders (amount) VALUES
(100),(200),(300),(400),(500),(600),(700),(800);

SELECT * FROM orders;
SELECT now();
📌 Note the timestamp — this is your PITR target reference.

**5. Take Base Backup**
kubectl get backups -n database


Example:

NAME               CLUSTER      METHOD              PHASE
pitr-base-backup   pg-ha-pitr   barmanObjectStore   completed

**6. Verify in S3:**

#aws s3 ls s3://k8s-kops-kalyan/


**7. Create PITR Restore Cluster**
Key PITR config:
source: s3-backup
recoveryTarget.time → timestamp before failure
bootstrap:
  recovery:
    source: s3-backup
    recoveryTarget:
      time: "2026-01-04 16:16:30+00"
Apply restore cluster YAML.
#kubectl apply -f pg-ha-pitr-restore.yaml


**8. Observe Restore Pods****
#kubectl get pods -n database -w

Validate PITR Success
#kubectl exec -n database <new-pod> -- \
psql -U postgres -d pitr_lab
SELECT * FROM orders;


✅ Rows inserted after the recovery timestamp are not present
✅ Database is restored exactly to the desired point in time

🔑 Key Learnings (DBRE Perspective)
•	PITR is not just backups — WAL continuity is critical
•	CNPG automates:
             WAL archiving
             Backup retention
             Recovery orchestration
•	Best practice:
             Restore into a new cluster
             Never overwrite production blindly
•	Even on single-node Minikube:
             You can fully simulate enterprise-grade DR

**🚀 What This Demonstrates for DBRE Roles**
✔ Kubernetes-native PostgreSQL
✔ Backup & disaster recovery design
✔ WAL mechanics & PITR
✔ Object storage integration (S3)
✔ Operator-driven automation
✔ Production-style recovery workflows







