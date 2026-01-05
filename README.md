
**1️. Install CloudNativePG Operator**


#kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml


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
*** Note the timestamp — this is your PITR target reference.

**5. Take Base Backup**

kubectl get backups -n database


Example:

NAME               CLUSTER      METHOD              PHASE
pitr-base-backup   pg-ha-pitr   barmanObjectStore   completed

**6. Verify in S3:**

#aws s3 ls s3://k8s-kops-kalyan/


**7. Create PITR Restore Cluster**

Yaml file: 
pg-ha-pitr-restore.yaml

--> Apply restore cluster YAML.

#kubectl apply -f pg-ha-pitr-restore.yaml


**8. Observe Restore Pods****

#kubectl get pods -n database -w

Validate: Automation Monitor Script for PITR:

Bash script : verify-pitr.sh

#kubectl exec -n database <new-pod> -- psql -U postgres -d pitr_lab

SELECT * FROM orders;

ubuntu@DESKTOP-7M24H1S:~/pg-pitr$ ./verify-pitr.sh

🔍 Validating PITR Restore: pg-ha-pitr-restore in database

⏳ Waiting for cluster ready...

cluster.postgresql.cnpg.io/pg-ha-pitr-restore condition met

🔍 Finding primary pod...

✅ Primary: pg-ha-pitr-restore-1

📊 PITR DATA VERIFICATION:

Defaulted container "postgres" out of: postgres, bootstrap-controller (init)

     status      | total_rows |   earliest_transaction    |    latest_transaction     |    latest_unix
-----------------+------------+---------------------------+---------------------------+-------------------
 ✅ PITR SUCCESS |         16 | 2026-01-05 05:51:34.90521 | 2026-01-05 06:26:07.99149 | 1767594367.991490
(1 row)


🔍 POSTGRESQL RECOVERY STATUS:

Defaulted container "postgres" out of: postgres, bootstrap-controller (init)

   mode   | in_recovery | last_receive_lsn | last_replay_lsn | last_xact_timestamp
----------+-------------+------------------+-----------------+---------------------
 Recovery | f           |                  |                 |
 
(1 row)


🎉 PITR Validation Complete!
💡 Expected: max(created_at) matches your targetTime
💾 S3 Backup: s3://k8s-kops-kalyan/pg-ha-pitr/
ubuntu@DESKTOP-7M24H1S:~/pg-pitr$


** Rows inserted after the recovery timestamp are not present

** Database is restored exactly to the desired point in time


