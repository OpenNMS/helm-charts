# OpenNMS Helm Charts

If your organization uses Kubernetes or Red Hat OpenShift, OpenNMS makes a Helm chart available to simplify deployment of Horizon and Meridian.

Each deployment through OpenNMS Helm Charts has a single Core server, Grafana, and a custom Ingress that shares the RRD files and some configuration files, and multiple Sentinels for flow processing.

Note that this is one way to approach the solution.
We recommend that you study the content of the Helm chart and tune it for your needs.

## Charts
* [Horizon](horizon/README.md)
* [Minion](minion/README.md); This is an experimental chart.
