# Prequisites
  ### To Running The script for Create a clusters, Workstation must be:
   - Installed Kubeadm & Kubectl Package
   - Installed jq Package
   - Installed Openstack client Package
   - Have to comunicate to Public API URL Openstack Cluster
   - have a Kubeconfig Admin Kamaji Cluster and store to ~/.kube/config
   - have a Keystone Tenant Project Openstack store to ~/
   
# Create Cluster
  ### Edit the parameters on the script
    export TENANT_NAMESPACE=default
    export TENANT_NAME=kube-${rand} #Tenant Name must be unique
    export TENANT_VERSION=1.26.7  #Version Available / Recomended = 1.27.0, 1.26.7, 1.25.12

    #worker Tenant parameters
    export WORKER_FLAVOR=GP.1C2G
    export AVAILABILITY_ZONE=AZ_Public01_DC2
    export NETWORK=Public_Subnet02_DC2
    export COUNT=3

    #Proejct Tenant Parameters
    . ~/cloud_development-openrc.sh
  
  ### execute
    bash <(curl -s https://raw.githubusercontent.com/teghitsugaya/kamaji/main/createcluster.sh)

  ### execute tcp temp
    bash <(curl -s https://raw.githubusercontent.com/nadyaulfa/kamaji/main/createcluster.sh)

# Add Worker
  ### To Add the Worker, cluster name and version must same form exsiting cluster
  ### To see exsiting cluster, exceute this command:
    kubectl get tcp -n default  | awk 'BEGIN { print "NAME VERSION" } NR > 1 { print $1, $2 }'
  
  ### Edit the parameters
    export TENANT_NAME=kube-0974
    export TENANT_VERSION=v1.26.7

    #worker Tenant parameters
    export WORKER_VERSION=1.26.7 #version must same form exsiting cluster version, #Version Available / Recomended = 1.27.0, 1.26.7, 1.25.12
    export WORKER_FLAVOR=GP.1C2G
    export AVAILABILITY_ZONE=AZ_Public01_DC2
    export NETWORK=Public_Subnet02_DC2
    export COUNT=3

    #Proejct Tenant Parameters
    . ~/cloud_development-openrc.sh
  
  ### execute  
    bash <(curl -s https://raw.githubusercontent.com/teghitsugaya/kamaji/main/addworker.sh)
               
# Delete Worker
  ### to delete a worker, this step by step:
  - drain node
  - cordon node
  - kubectl delete nodes $(node_worker)
  - openstack server delete $(node_worker)
