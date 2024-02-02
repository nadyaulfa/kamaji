#!/bin/bash
echo ""

export rand=$(openssl rand -hex 3)

##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=jkt2-tenant-${rand} #Tenant Name must be unique
export TENANT_VERSION=1.27.0 #Version Available/Recomended = 1.27.0, 1.26.7, 1.25.12  (on develop image for version= 1.29.0, 1.28.6, 1.27.10, 1.26.13)

#worker Tenant parameters
export WORKER_FLAVOR=GP.1C2G
export AVAILABILITY_ZONE=AZ_Public01_DC2
export NETWORK=Public_Subnet02_DC2
export COUNT=1

echo "Deploy Cluster Kubernetes"
echo "Cluster Name: ${TENANT_NAME}"
echo "Version: ${TENANT_VERSION}"
echo ""
echo ""
echo "Create Tenant Control Plane"
echo "Waiting..."

kubectl create -f - <<EOF > /dev/null 2>&1
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: ${TENANT_NAME}
  namespace: ${TENANT_NAMESPACE}
spec:
  dataStore: default
  controlPlane:
    deployment:
      replicas: 3
    service:
      serviceType: LoadBalancer
  kubernetes:
    version: v${TENANT_VERSION}
    kubelet:
      cgroupfs: systemd
  networkProfile:
    port: 6443
  addons:
    coreDNS: {}
    kubeProxy: {}
    konnectivity:
      server:
        port: 8132
        resources: {}
      agent: {}
EOF

while true; do
  STATUS=$(kubectl get tcp | grep ${TENANT_NAME} | awk '{print $3}')

case "$STATUS" in
    "Ready")
      echo "Create Tenant Control Plane SUCCESS"
      break
      ;;
    *)
  esac
done

kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig
kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command


