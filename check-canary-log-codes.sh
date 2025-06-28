#!/bin/bash
NAMESPACE=${1:-default}
APP_LABEL=${2:-myapp}
OUTFILE=${3:-canary-codes.log}

POD=$(kubectl get pods -n $NAMESPACE -l app=$APP_LABEL -o jsonpath='{.items[0].metadata.name}')
echo "Analizez codurile de răspuns pentru podul: $POD" | tee $OUTFILE
kubectl logs $POD -n $NAMESPACE | grep HTTP | awk '{print $3}' | sort | uniq -c | tee -a $OUTFILE
