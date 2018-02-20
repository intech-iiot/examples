#!/bin/bash

set -e
set -x

PROJECT=$1 # Existing Google Cloud account name.
CLUSTER_NAME=$2 # Desired Kubernetes cluster name.

# Create Kubernetes Cluster in Google Cloud.
gcloud container --project "${PROJECT}" clusters create "${CLUSTER_NAME}" --zone "us-central1-c" --username "admin" --cluster-version "1.9.2-gke.1" --machine-type "n1-standard-2" --image-type "UBUNTU" --disk-size "100" --scopes "https://www.googleapis.com/auth/cloud-platform" --num-nodes "6" --network "default" --enable-cloud-logging --enable-cloud-monitoring --subnetwork "default"

# Install Kubernetes client.
gcloud components install kubectl

# Get credentials for the newly created Kubernetes cluster.
gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone us-central1-c --project "${PROJECT}"
export PASSWORD=`gcloud container clusters describe ${CLUSTER_NAME} | grep password | sed 's/  password: //g'`

# Install helm client. Note: for mac.
#brew install kubernetes-helm

# Install Tiller on the Kubernetes cluster.
helm init
kubectl --username=admin --password="$PASSWORD" create serviceaccount --namespace kube-system tiller
kubectl --username=admin --password="$PASSWORD" create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl --username=admin --password="$PASSWORD" patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade

# Deploy Zookeeper in Kubernetes.
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm install --set storage=10Gi,storageClass=standard --name myzk incubator/zookeeper

sleep 60

# Deploy Flink with HA in Kubernetes.
git clone https://github.com/intech-iiot/helm-flink.git
cd helm-flink
helm package helm/flink/
helm install --name ha --values helm/flink/values.yaml flink-1.3.2.tgz

sleep 60

kubectl get pods -o wide

# Run the proxy.
kubectl proxy &

# Mac command to open url for the Flink JobManager.
# open http://localhost:8001/api/v1/proxy/namespaces/default/services/flinkha-flink-jobmanager:8081
