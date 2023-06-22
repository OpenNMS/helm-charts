# OpenNMS Helm Charts

The objective of this project is to serve as a reference to implement [OpenNMS](https://www.opennms.com/) running in [Kubernetes](https://kubernetes.io/), deployed via [Helm](https://helm.sh/).

Each deployment would have a single Core Server plus Grafana and a custom Ingress, sharing the RRD files and some configuration files, and Sentinels for flow processing.

Keep in mind that we expect Kafka, Elasticsearch, and PostgreSQL to run externally (and maintained separately from the solution), all with SSL enabled.

> *This is one way to approach the solution, without saying this is the only one or the best one. You should carefully study the content of this Helm Chart and tune it for your needs*.

## Version compatability

Note: The Helm chart version is independent of the Horizon/Meridian version.

| Helm chart version | Horizon version(s) | Meridian version(s) |
| ----------- | ----------- | ----------- |
| 1.x | Horizon 32.x | Meridian 2023.x |
