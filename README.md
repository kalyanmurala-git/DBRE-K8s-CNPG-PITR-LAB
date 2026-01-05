<img width="940" height="47" alt="image" src="https://github.com/user-attachments/assets/24f4203b-9e95-4617-91b7-8aa1c4d5806f" /># DBRE-K8s-CNPG-PITR-LAB
PostgreSQL Point-in-Time Recovery (PITR) using CloudNativePG on Kubernetes

🔍 Objective
**To practice and validate PostgreSQL Point-in-Time Recovery (PITR) using:**
•	Kubernetes (Minikube – single node lab)
•	CloudNativePG (CNPG) operator
•	Amazon S3 as backup + WAL archive destination
Instead of restoring in-place, a new PostgreSQL cluster was created and restored to a specific timestamp, which is the recommended and safest PITR approach.


🧠 Why CloudNativePG for PITR?
**CloudNativePG is purpose-built for PostgreSQL on Kubernetes and offers:**
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

1️. Install CloudNativePG Operator
# kubectl apply --server-side --force-conflicts \
-f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml


**Verify:**

kubectl get pods -n cnpg-system

 <img width="940" height="47" alt="image" src="https://github.com/user-attachments/assets/2519a580-a898-44b0-9a0b-ca0c42126804" />

 <img width="940" height="115" alt="image" src="https://github.com/user-attachments/assets/a5a05a24-1888-43d9-93a8-092609831ca8" />

2. Create PostgreSQL Cluster with S3 Backup + WAL Archiving
Key configuration:
•	barmanObjectStore → S3 bucket
•	WAL compression enabled
•	AWS credentials stored as Kubernetes secret

Apply:

kubectl apply -f pg-ha-pitr.yaml

3️ Verify Cluster & Primary
kubectl get cluster -n database
kubectl get pods -n database
<img width="940" height="609" alt="image" src="https://github.com/user-attachments/assets/419ff3b0-5b6f-4282-ae50-28cfe8e25862" />

<img width="940" height="48" alt="image" src="https://github.com/user-attachments/assets/a9f0c081-d685-4944-bba4-bf820b519e80" />

<img width="940" height="220" alt="image" src="https://github.com/user-attachments/assets/f335722d-85ea-4f81-925e-c3c0a527690e" />

4. Check primary:

kubectl exec -n database pg-ha-pitr-1 -- \
psql -U postgres -c "SELECT pg_is_in_recovery();"
5. Create Database and Test Data
kubectl exec -n database pg-ha-pitr-1 -- psql -U postgres

<img width="940" height="313" alt="image" src="https://github.com/user-attachments/assets/0df640b9-dbe4-48ee-9e9b-999276abc2cd" />

<img width="938" height="133" alt="image" src="https://github.com/user-attachments/assets/15739d5f-526f-4706-9bf5-1398e1813067" />

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
 
<img width="940" height="483" alt="image" src="https://github.com/user-attachments/assets/da278f2c-4a75-4275-9ec0-33a1ef6c723e" />

📌 Note the timestamp — this is your PITR target reference.

5. Take Base Backup
kubectl get backups -n database


Example:

NAME               CLUSTER      METHOD              PHASE
pitr-base-backup   pg-ha-pitr   barmanObjectStore   completed
<img width="940" height="247" alt="image" src="https://github.com/user-attachments/assets/f95d08c7-9d5e-424e-aaec-580167c250fa" />

6. Verify in S3:

aws s3 ls s3://k8s-kops-kalyan/
<img width="940" height="64" alt="image" src="https://github.com/user-attachments/assets/d6900a2b-55d6-40d4-9edf-be62fc11cdac" />

We can also delete the cluster but, I have created new cluster using based backup and recovered in point in time.

7. Create PITR Restore Cluster
Key PITR config:
•	source: s3-backup
•	recoveryTarget.time → timestamp before failure
bootstrap:
  recovery:
    source: s3-backup
    recoveryTarget:
      time: "2026-01-04 16:16:30+00"
Apply restore cluster YAML.
<img width="940" height="46" alt="image" src="https://github.com/user-attachments/assets/44a46d0d-83ec-4b32-be7a-799002738163" />

8. Observe Restore Pods
kubectl get pods -n database -w
<img width="940" height="228" alt="image" src="https://github.com/user-attachments/assets/e756d7df-f747-4609-a832-62765f52633c" />

Validate PITR Success
kubectl exec -n database <new-pod> -- \
psql -U postgres -d pitr_lab
SELECT * FROM orders;
<img width="940" height="118" alt="image" src="https://github.com/user-attachments/assets/05e56450-987b-4623-9aad-7fb27ffce860" />

<img width="875" height="389" alt="image" src="https://github.com/user-attachments/assets/74af9d6f-b27e-43cf-9c50-0d7372079723" />

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

🚀 What This Demonstrates for DBRE Roles
✔ Kubernetes-native PostgreSQL
✔ Backup & disaster recovery design
✔ WAL mechanics & PITR
✔ Object storage integration (S3)
✔ Operator-driven automation
✔ Production-style recovery workflows







 







 

 


