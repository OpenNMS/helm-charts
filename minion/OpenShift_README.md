# OpenNMS Helm Charts with OpenShift: Documentation (1.1.0)

OpenNMS Helm Charts makes it easier for users to run OpenNMS Minion on a Red Hat OpenShift or Kubernetes environment. It provides a package that includes all the resources needed to deploy Minion.
This documentation provides basic information on how to install Minion on Red Hat OpenShift. For information on how to use Red Hat OpenShift, refer to the [product documentation](https://access.redhat.com/documentation/en-us/openshift_container_platform/).

## Limitations and Known Issues

* Removing `CAP_NET_RAW` capability or setting allowPrivilegeEscalation to false will impact ICMP and auto discovery features.
  * **WORKAROUND:** Use a Minion that is located outside of the OpenShift cluster.

## Install OpenNMS Minion on OpenShift
> **NOTE:** By default, OpenNMS will create a ClusterRole, ClusterRoleBinding, Route, SecurityContextConstraints, and ServiceAccount. The user used to install OpenNMS must have the required permissions to make these modifications the OpenShift Cluster, including admin access. There are options to disable the creation of these elements, but if you do so, you will need to figure out a way to get the pods to work.

1. Log in to OpenShift and switch to Developer view.
2. Create a project with a unique name.
3. Go to the Helm section.
4. In the Create drop-down menu, select Repository.
    * In the Create Repository page,
    * Add a unique name and display name.
    * Use https://opennms.github.io/helm-charts/ for the URL.
    * Save the changes.
5. In the Create drop-down menu, select Helm Release.
6. Under Repository, select the newly created repository entry.
7. Click on Minion.
8.	Make sure that the project name matches the name you set in step 2.
    * Skip this step if you are setting “CreateNamespace” option to true.
9.	Make the required modifications (for example, set the PostgreSQL information).
10.	Click Create.
11.	Wait for the pods to come up. This may take a few minutes.

**NOTE:** The process to install the Minion is similar.


