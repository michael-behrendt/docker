#!/bin/bash

# script was inspired by 
# https://community.hortonworks.com/articles/47170/automate-hdp-installation-using-ambari-blueprints.html

if [ -f /etc/yum.repos.d/ambari.repo ]; then
  echo "$0 skipped, because files already exists"
  exit 1
fi

if [ "$(id -u)" != "0" ]; then
  echo "$0 has to be run as root, probably sudo missing?"
  exit 1
fi

# hack to avoid forwarding local requests to t-sys proxy
cat - >> /etc/profile.d/proxy.sh << EOF 
export NO_PROXY="localhost,127.0.0.1,faslabdev"
export no_proxy="localhost,127.0.0.1,faslabdev"
EOF
. /etc/profile.d/proxy.sh

(cd /etc/yum.repos.d/; curl -O --silent http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.5.2.0/ambari.repo)

yum install ambari-agent -y
ambari-agent start

yum install ambari-server -y
ambari-server setup --silent --verbose

echo 'export AMBARI_JVM_ARGS="$AMBARI_JVM_ARGS -Dhttp.proxyHost=10.175.249.97:8080"' >> /var/lib/ambari-server/ambari-env.sh

ambari-server start

# update ambari repository and link 2.6 to 2.6.2.0 Version
# use curl -u admin:admin http://localhost:8080/api/v1/stacks/HDP/versions/2.6/operating_systems/redhat7/repositories/HDP-2.6
# to read previous settings

curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://localhost:8080/api/v1/stacks/HDP/versions/2.6/operating_systems/redhat7/repositories/HDP-2.6 -d @- << EOF
{
  "Repositories" : {
    "base_url" : "http://public-repo-1.hortonworks.com/HDP/centos7/2.x/updates/2.6.2.0",
    "verify_base_url" : false
  }
}
EOF

# create blueprint using 2.6
# for list of possible components names go to 
# https://github.com/apache/ambari/tree/branch-2.5/ambari-server/src/main/resources/common-services
# and have a look into metainfo.xml of each subfolder

curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://localhost:8080/api/v1/blueprints/bluetest1 -d @- << EOF
    {
      "configurations" : [ ],
      "host_groups" : [
        {
          "name" : "host_group_1",
          "components" : [
            {
              "name" : "NAMENODE"
            },
            {
              "name" : "SECONDARY_NAMENODE"
            },
            {
              "name" : "DATANODE"
            },
            {
              "name" : "HDFS_CLIENT"
            },
            {
              "name" : "RESOURCEMANAGER"
            },
            {
              "name" : "NODEMANAGER"
            },
            {
              "name" : "YARN_CLIENT"
            },
            {
              "name" : "HISTORYSERVER"
            },
            {
              "name" : "APP_TIMELINE_SERVER"
            },
            {
              "name" : "MAPREDUCE2_CLIENT"
            },
            {
              "name" : "ZOOKEEPER_SERVER"
            },
            {
              "name" : "ZOOKEEPER_CLIENT"
            },
            { "name" : "MYSQL_SERVER" },
            { "name" : "WEBHCAT_SERVER" },
            { "name" : "HIVE_CLIENT" },
            { "name" : "HIVE_SERVER" },
            { "name" : "HIVE_METASTORE" },
            { "name" : "SPARK2_CLIENT" },
			{ "name" : "SPARK2_THRIFTSERVER" },
            { "name" : "SPARK2_JOBHISTORYSERVER" }
          ],
          "cardinality" : "1"
        }
      ],
      "Blueprints" : {
        "blueprint_name" : "single-node-hdp-cluster",
        "stack_name" : "HDP",
        "stack_version" : "2.6"
      }
    }
EOF

# commit blueprint installation

curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://localhost:8080/api/v1/clusters/cluster1 -d @- << EOF
    {
      "blueprint" : "single-node-hdp-cluster",
      "default_password" : "admin",
      "host_groups" :[
        {
          "name" : "host_group_1",
          "hosts" : [
            {
              "fqdn" : "faslabdev"
            }
          ]
        }
      ]
    }
EOF

echo "http://localhost:8080 User: admin Pass: admin"