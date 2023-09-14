#!/bin/bash

checkRC(){
    return_code=$?
    if [ $return_code -ne 0 ]; then
        printf "\033[31m%s\n\033[0m" "An error occured as the return code is not 0!"
        exit $return_code
    fi 
}


if ! command -v crc   >/dev/null 2>&1; then
 echo "Unable to find CRC command! Exiting.."
 exit 1
fi

if ! command -v oc   >/dev/null 2>&1; then
  eval $(crc oc-env)                                                                                                    
fi

export WhoAmI=$(oc whoami)
export HelmChartURL="https://opennms.github.io/helm-charts"

if [ "$WhoAmI" != "kubeadmin" ];then 
 echo "You need to be logged in as kubeadmin! Exiting..."
fi

export OpenNMS_Namespace=$(oc projects |grep "opennms")

if [ -z "$OpenNMS_Namespace" ];then 
 echo "Creating OpenNMS project"
 oc new-project opennms
 checkRC
fi 

oc project opennms

export OpenNMS_HelmChart=$(oc get --no-headers=true HelmChartRepository opennms-internal)

if [ -z "$OpenNMS_HelmChart" ];then 
echo "Adding Helm Chart repo"
cat <<EOF | oc apply -f -
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
  name: opennms-internal
spec:
  name: OpenNMS Helm Charts (Internal)
  connectionConfig:
    url: ${HelmChartURL}
EOF
checkRC
fi

export Postgres=$(oc get pods |grep "postgres")

if [[ -z $Postgres ]];then
 # Install Postgres
 echo "LS0tCmFwaVZlcnNpb246IHYxCmtpbmQ6IFNlcnZpY2UKbWV0YWRhdGE6CiAgbmFtZTogcG9zdGdyZXNxbAogIG5hbWVzcGFjZTogb3Blbm5tcwogIGxhYmVsczoKICAgIGFwcDogcG9zdGdyZXMKc3BlYzoKICBjbHVzdGVySVA6IE5vbmUKICBwb3J0czoKICAtIG5hbWU6IHBvc3RncmVzCiAgICBwb3J0OiA1NDMyCiAgc2VsZWN0b3I6CiAgICBhcHA6IHBvc3RncmVzCgotLS0KYXBpVmVyc2lvbjogYXBwcy92MQpraW5kOiBTdGF0ZWZ1bFNldAptZXRhZGF0YToKICBuYW1lOiBwb3N0Z3JlcwogIG5hbWVzcGFjZTogb3Blbm5tcwogIGxhYmVsczoKICAgIGFwcDogcG9zdGdyZXMKICAgIHJvbGU6IG1hc3RlcgpzcGVjOgogIHNlcnZpY2VOYW1lOiBwb3N0Z3Jlc3FsCiAgcmVwbGljYXM6IDEgIyBUaGUgc29sdXRpb24gb25seSBhbGxvd3MgMSBpbnN0YW5jZQogIHNlbGVjdG9yOgogICAgbWF0Y2hMYWJlbHM6CiAgICAgIGFwcDogcG9zdGdyZXMKICB0ZW1wbGF0ZToKICAgIG1ldGFkYXRhOgogICAgICBsYWJlbHM6CiAgICAgICAgYXBwOiBwb3N0Z3JlcwogICAgICAgIHJvbGU6IG1hc3RlcgogICAgc3BlYzogICAKICAgICAgY29udGFpbmVyczoKICAgICAgLSBuYW1lOiBwb3N0Z3JlcwogICAgICAgIGltYWdlOiBwb3N0Z3JlczoxNAogICAgICAgIGltYWdlUHVsbFBvbGljeTogSWZOb3RQcmVzZW50CiAgICAgICAgc2VjdXJpdHlDb250ZXh0OgogICAgICAgICAgcnVuQXNOb25Sb290OiB0cnVlCiAgICAgICAgICBzZWNjb21wUHJvZmlsZToKICAgICAgICAgICAgdHlwZTogUnVudGltZURlZmF1bHQKICAgICAgICAgIGFsbG93UHJpdmlsZWdlRXNjYWxhdGlvbjogZmFsc2UKICAgICAgICAgIGNhcGFiaWxpdGllczoKICAgICAgICAgICAgZHJvcDogWyJBTEwiXQogICAgICAgIGVudjoKICAgICAgICAtIG5hbWU6IFRaCiAgICAgICAgICB2YWx1ZTogQW1lcmljYS9OZXdfWW9yawogICAgICAgIC0gbmFtZTogUE9TVEdSRVNfVVNFUgogICAgICAgICAgdmFsdWU6IHBvc3RncmVzCiAgICAgICAgLSBuYW1lOiBQT1NUR1JFU19QQVNTV09SRAogICAgICAgICAgdmFsdWU6IHBvc3RncmVzCiAgICAgICAgLSBuYW1lOiBQR0RBVEEKICAgICAgICAgIHZhbHVlOiAvdmFyL2xpYi9wb3N0Z3Jlc3FsL2RhdGEvcGdkYXRhCiAgICAgICAgcG9ydHM6CiAgICAgICAgLSBjb250YWluZXJQb3J0OiA1NDMyCiAgICAgICAgICBuYW1lOiBwb3N0Z3JlcwogICAgICAgIHZvbHVtZU1vdW50czoKICAgICAgICAtIG5hbWU6IGRhdGEKICAgICAgICAgIG1vdW50UGF0aDogL3Zhci9saWIvcG9zdGdyZXNxbC9kYXRhCiAgICAgICAgdXNlcnM6CiAgICAgICAgICAgIG9wZW5ubXM6CiAgICAgICAgICAgICAtIHN1cGVydXNlcgogICAgICAgICAgICAgLSBjcmVhdGVkYgogICAgICAgIHJlYWRpbmVzc1Byb2JlOgogICAgICAgICAgZXhlYzoKICAgICAgICAgICAgY29tbWFuZDoKICAgICAgICAgICAgLSBzaAogICAgICAgICAgICAtIC1jCiAgICAgICAgICAgIC0gZXhlYyBwZ19pc3JlYWR5IC0taG9zdCAkSE9TVE5BTUUKICAgICAgICAgIGluaXRpYWxEZWxheVNlY29uZHM6IDEwCiAgICAgICAgICBwZXJpb2RTZWNvbmRzOiAxMAogICAgICAgIGxpdmVuZXNzUHJvYmU6CiAgICAgICAgICBleGVjOgogICAgICAgICAgICBjb21tYW5kOgogICAgICAgICAgICAtIHNoCiAgICAgICAgICAgIC0gLWMKICAgICAgICAgICAgLSBleGVjIHBnX2lzcmVhZHkgLS1ob3N0ICRIT1NUTkFNRQogICAgICAgICAgaW5pdGlhbERlbGF5U2Vjb25kczogMzAKICAgICAgICAgIHBlcmlvZFNlY29uZHM6IDYwCiAgdm9sdW1lQ2xhaW1UZW1wbGF0ZXM6CiAgLSBtZXRhZGF0YToKICAgICAgbmFtZTogZGF0YQogICAgc3BlYzoKICAgICAgYWNjZXNzTW9kZXM6CiAgICAgIC0gUmVhZFdyaXRlT25jZQogICAgICByZXNvdXJjZXM6CiAgICAgICAgcmVxdWVzdHM6CiAgICAgICAgICBzdG9yYWdlOiAxR2kK" | base64 --decode | oc apply -f -
 checkRC
else
 oc exec postgres-0 -- dropdb opennms_openms -U postgres
 checkRC
fi

##helm upgrade --install  --set core.image.tag='develop' opennms ./horizon