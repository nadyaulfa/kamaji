#!/bin/bash
echo ""
#kamaji parameters
export KAMAJI_NAMESPACE=default

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=kube-auto
export TENANT_VERSION=v1.26.1

#Worker Tenant parameters
export WORKER_VERSION=1.26.1
export WORKER_FLAVOR=GP.2C4G
export AVAILABILITY_ZONE=AZ_Public01_DC1
export NETWORK=Public_Subnet02_DC1

echo "Deploy Cluster Kubernetes"
echo "Cluster Name: ${TENANT_NAME}"
echo "Version: ${TENANT_VERSION}"
echo ""
echo "Create Tenant Control Plane"

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
    version: ${TENANT_VERSION}
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

sleep 2m 10s

echo "Create Tenant Control Plane SUCCESS"


kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig
  
sleep 5  

echo "Create WORKER"

JOIN_CMD=$(kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command)

sleep 2

cat << EOF | tee script.sh > /dev/null 2>&1
#cloud-config
debug: True
runcmd:
 - echo "overlay" >> containerd.conf
 - echo "br_netfilter" >> containerd.conf
 - echo "net.bridge.bridge-nf-call-iptables = 1" >> 99-kubernetes-cri.conf
 - echo "net.ipv4.ip_forward = 1" >> 99-kubernetes-cri.conf
 - echo "net.bridge.bridge-nf-call-ip6tables = 1" >> 99-kubernetes-cri.conf
 - sudo apt update && sudo apt install -y containerd
 - sudo mkdir -p /etc/containerd
 - containerd config default | sed -e "s#SystemdCgroup = false#SystemdCgroup = true#g" | sudo tee -a /etc/containerd/config.toml
 - sudo systemctl restart containerd && sudo systemctl enable containerd
 - sudo chown -R root:root containerd.conf && sudo mv containerd.conf /etc/modules-load.d/containerd.conf
 - sudo modprobe overlay && sudo modprobe br_netfilter
 - sudo chown -R root:root 99-kubernetes-cri.conf && sudo mv 99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf
 - sudo sysctl --system
 - echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
 - curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
 - sudo apt-get update
 - sudo apt install -y kubeadm=${WORKER_VERSION}-00 kubelet=${WORKER_VERSION}-00 kubectl=${WORKER_VERSION}-00 --allow-downgrades --allow-change-held-packages
 - sudo apt-mark hold kubelet kubeadm kubectl
 - $JOIN_CMD
EOF

sleep 2

export OS_AUTH_URL=https://jktosp-horizon.dcloud.co.id/identity/v3/
export OS_PROJECT_ID=55e36960719f41159aca054a14d2ba03
export OS_PROJECT_NAME="Infra Kamaji"
export OS_USER_DOMAIN_NAME="Default"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="default"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi
unset OS_TENANT_ID
unset OS_TENANT_NAME
export OS_USERNAME="teguh.imanto"
export OS_PASSWORD=D4t4c0mm@2023!!!
export OS_REGION_NAME="RegionOne"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

sleep 2

openstack server create --flavor ${WORKER_FLAVOR} --image "Ubuntu 22.04 LTS" --network ${NETWORK} --security-group kamaji-rules --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --min 3 --max 3 --user-data script.sh "${TENANT_NAME}-${TENANT_VERSION}-worker" > /dev/null 2>&1

kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml > /dev/null 2>&1

sleep 2m 15s

echo "Create WORKER SUCCESS"

echo ""
echo ""

sleep 1

kubectl --kubeconfig=${TENANT_NAME}.kubeconfig cluster-info

echo ""
echo ""

echo "Node Cluster"
echo ""
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get nodes
echo ""
echo ""

echo "Your Cluster is Ready !!!"
echo ""
echo "Your Kubeconfig is = ${TENANT_NAME}.kubeconfig"

rm -rf script.sh > /dev/null 2>&1
rm -rf kamaji-script.sh > /dev/null 2>&1