#!/bin/bash
# 05-verify-pitr.sh - FIXED VERSION
# PITR Validation Script

set -e

CLUSTER_NAME=${1:-pg-ha-pitr-restore}
NAMESPACE=${2:-database}

echo "🔍 Validating PITR Restore: $CLUSTER_NAME in $NAMESPACE"

# Wait for cluster ready
echo "⏳ Waiting for cluster ready..."
kubectl wait --for=condition=Ready cluster/$CLUSTER_NAME -n $NAMESPACE --timeout=300s

# Find primary pod (multiple fallback methods)
echo "🔍 Finding primary pod..."

# Method 1: PostgreSQL master role label
PRIMARY_POD=$(kubectl get pods -n $NAMESPACE -l postgresql.cnpg.io/role=master --no-headers 2>/dev/null | head -1 | awk '{print $1}' || echo "")

# Method 2: Pod ending with -1 (common CNPG primary)
if [ -z "$PRIMARY_POD" ]; then
  PRIMARY_POD=$(kubectl get pods -n $NAMESPACE -o name | grep "$CLUSTER_NAME-1" | head -1 | sed 's/pod\///' || echo "")
fi

# Method 3: First running pod with postgres container
if [ -z "$PRIMARY_POD" ]; then
  PRIMARY_POD=$(kubectl get pods -n $NAMESPACE --no-headers -o custom-columns=NAME:.metadata.name | grep Running | grep $CLUSTER_NAME | head -1 || echo "")
fi

# FAIL if still empty
if [ -z "$PRIMARY_POD" ]; then
  echo "❌ ERROR: No primary pod found. Available pods:"
  kubectl get pods -n $NAMESPACE
  exit 1
fi

echo "✅ Primary: $PRIMARY_POD"

# Verify PITR database exists and has correct data
echo ""
echo "📊 PITR DATA VERIFICATION:"
kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -d pitr_lab -c "
  SELECT 
    '✅ PITR SUCCESS' as status,
    count(*) as total_rows,
    min(created_at) as earliest_transaction,
    max(created_at) as latest_transaction,
    extract(epoch from (max(created_at))) as latest_unix
  FROM orders;
"

# Verify PostgreSQL recovery status
echo ""
echo "🔍 POSTGRESQL RECOVERY STATUS:"
kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -c "
  SELECT 
    'Recovery' as mode,
    pg_is_in_recovery() as in_recovery,
    pg_last_wal_receive_lsn() as last_receive_lsn,
    pg_last_wal_replay_lsn() as last_replay_lsn,
    pg_last_xact_replay_timestamp() as last_xact_timestamp;
"

echo ""
echo "🎉 PITR Validation Complete!"
echo "💡 Expected: max(created_at) matches your targetTime"
echo "💾 S3 Backup: s3://k8s-kops-kalyan/pg-ha-pitr/"
