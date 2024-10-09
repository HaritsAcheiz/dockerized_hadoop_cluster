#!/bin/bash

# Ensure the /run/sshd directory exists and has the correct permissions
sudo mkdir -p /run/sshd
sudo chmod 755 /run/sshd

# Start SSH service
sudo service ssh start

# Ensure proper permissions for HDFS directories
chown -R hdfs:hdfs /hadoop
chmod 755 /hadoop

# Function to set up SSH
setup_ssh() {
    echo "Setting up SSH..."
    ssh-keyscan localhost >> /home/hdfs/.ssh/known_hosts
    ssh-keyscan namenode >> /home/hdfs/.ssh/known_hosts
    ssh-keyscan datanode1 >> /home/hdfs/.ssh/known_hosts
    ssh-keyscan datanode2 >> /home/hdfs/.ssh/known_hosts
    chmod 644 /home/hdfs/.ssh/known_hosts
}

# Function to distribute SSH keys
distribute_ssh_keys() {
    if [ "$HOSTNAME" = "namenode" ]; then
        echo "Distributing SSH keys..."
        sshpass -p "hdfs" ssh-copy-id -o StrictHostKeyChecking=no hdfs@datanode1
        sshpass -p "hdfs" ssh-copy-id -o StrictHostKeyChecking=no hdfs@datanode2
    fi
}

# Function to start NameNode
start_namenode() {
    echo "Starting NameNode..."
    if [ ! -d "/hadoop/dfs/name/current" ]; then
        echo "Formatting HDFS..."
        hdfs namenode -format -force
    fi
    setup_ssh
    distribute_ssh_keys
    start-dfs.sh
    start-yarn.sh
    hdfs dfs -mkdir -p /user/hdfs
    tail -f ${HADOOP_HOME}/logs/*
}

# Function to start DataNode
start_datanode() {
    echo "Starting DataNode..."
    setup_ssh
    hdfs datanode &
    yarn nodemanager &
    tail -f ${HADOOP_HOME}/logs/*
}

# Main logic
case "$1" in
    namenode)
        start_namenode
        ;;
    datanode)
        start_datanode
        ;;
    *)
        echo "Usage: $0 {namenode|datanode}"
        exit 1
esac
