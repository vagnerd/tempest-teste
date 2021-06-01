#!/bin/bash
# http://blog.marcnuri.com/prometheus-grafana-setup-minikube/

# Install and expose prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus
kubectl expose service prometheus-server --type=NodePort --target-port=9090 --name=prometheus-server-np
minikube service prometheus-server-np

# Install and expose grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana
kubectl expose service grafana --type=NodePort --target-port=3000 --name=grafana-np
echo "GRAFANA TOKEN:"
kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
minikube service grafana-np

# Install ES/KIBANA
helm repo add elastic https://helm.elastic.co
curl -O https://raw.githubusercontent.com/elastic/helm-charts/master/elasticsearch/examples/minikube/values.yaml
helm install elasticsearch elastic/elasticsearch -f ./values.yaml
kubectl expose service elasticsearch-master --type=NodePort --target-port=9200 --name=elasticsearch
helm install kibana elastic/kibana
kubectl expose service kibana-kibana --type=NodePort --target-port=5601 --name=kibana

# Install FLUENTD
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit
