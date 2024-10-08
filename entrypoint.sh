#!/bin/bash
set -e

# Function to wait for a service to be ready
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3

    echo "Waiting for $service to be ready..."
    while ! nc -z $host $port; do
        sleep 1
    done
    echo "$service is ready!"
}

# Copy config files
cp /opt/hadoop_config/* $HADOOP_HOME/etc/hadoop/
cp /opt/spark_config/* $SPARK_HOME/conf/

# Set up SSH keys
mkdir -p ~/.ssh
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

# Ensure correct ownership of SSH files
if [ $(id -u) -eq 0 ]; then
    chown -R hdfs:hdfs ~/.ssh
else
    echo "Running as non-root user, skipping chown"
fi

# Start SSH service
service ssh start || echo "SSH service failed to start"

# Node-specific operations
case "$NODE_TYPE" in
    "namenode")
        if [ ! -d "/hadoop/dfs/name/current" ]; then
            echo "Formatting NameNode..."
            $HADOOP_HOME/bin/hdfs namenode -format
        fi
        echo "Starting NameNode..."
        $HADOOP_HOME/sbin/start-dfs.sh
        echo "Starting YARN..."
        $HADOOP_HOME/sbin/start-yarn.sh
        echo "Starting Spark Master..."
        $SPARK_HOME/sbin/start-master.sh
        ;;
    "datanode")
        echo "Waiting for NameNode to be ready..."
        wait_for_service namenode 9000 "NameNode"
        echo "Starting DataNode..."
        $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode
        echo "Starting NodeManager..."
        $HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager
        echo "Starting Spark Worker..."
        $SPARK_HOME/sbin/start-worker.sh spark://namenode:7077
        ;;
    *)
        echo "Unknown NODE_TYPE: $NODE_TYPE"
        exit 1
        ;;
esac

# Health check
if [ "$NODE_TYPE" = "namenode" ]; then
    echo "Performing health check..."
    timeout 300 bash -c 'until curl -f http://localhost:9870; do echo "Waiting for NameNode UI..."; sleep 10; done'
fi

echo "Startup complete. Keeping container running..."
tail -f /dev/null