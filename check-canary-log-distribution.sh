#!/bin/bash
NAMESPACE=${1:-default}
APP_LABEL=${2:-myapp}
OUTFILE=${3:-canary-distribution.log}

POD=$(kubectl get pods -n $NAMESPACE -l app=$APP_LABEL -o jsonpath='{.items[0].metadata.name}')
echo "Analizez podul: $POD din namespace: $NAMESPACE" | tee $OUTFILE
kubectl logs $POD -n $NAMESPACE | grep 'Version' | sort | uniq -c | tee -a $OUTFILE
