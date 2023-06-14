# KAR Docker Images

The idea is to use this container within the `initContainers` section of the OpenNMS `StatefulSet` to copy the KAR file to the `$OPENNMS_HOME/deploy` directory at runtime.

## Building and Publishing
* Create a `build` folder
* Download the KAR file(s) into the `build` folder
* Run Docker build command
* Push the newly created image to a repository which can be accessed by the Helm Charts.


## Usage

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: onms-core
...
      initContainers:
      - name: alec
        image: opennms/alec:v1.1.1
        imagePullPolicy: IfNotPresent
        command: [ cp, /plugins/opennms-alec-plugin.kar, /opennms-deploy ]
        volumeMounts:
        - name: deploy
          mountPath: /opennms-deploy
...
      containers:
      - name: onms
      ...
        volumeMounts:
        - name: deploy
          mountPath: /opt/opennms/deploy
...
      volumes:
      - name: deploy
        emptyDir: {}
```
