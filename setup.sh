#!/bin/bash

# Generate SSH key for hdfs
if [ ! -f /home/hdfs/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N "" -f /home/hdfs/.ssh/id_rsa
fi

# Copy SSH key to secondary containers
ssh-copy-id hdfs@datanode1
ssh-copy-id hdfs@datanode2