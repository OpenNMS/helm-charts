# OpenNMS Helm Charts -- Minion

This template can be used to bring up a minion and connect it to a OpenNMS core.

## Requirements:
* OpenNMS Core with Kafka connection configured

## How to use:
* Modify `values.yaml` file:
* (If you are using JKS) add a base64 value of Java Keystore into `content`. You can get the base64 value by running `cat jks/truststore.jks | base64`