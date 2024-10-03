FROM ubuntu:24.04

# Set environment variables
ENV HADOOP_VERSION=3.3.6
ENV SPARK_VERSION=3.5.3
ENV HIVE_VERSION=4.0.0

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    wget \
    ssh \
    pdsh \
    && rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Create hadoopuser and set up SSH
RUN useradd -ms /bin/bash hadoopuser && \
    echo "hadoopuser:hadoopuser" | chpasswd && \
    adduser hadoopuser sudo

# Set up SSH
RUN ssh-keygen -t rsa -P '' -f /home/hadoopuser/.ssh/id_rsa && \
    cat /home/hadoopuser/.ssh/id_rsa.pub >> /home/hadoopuser/.ssh/authorized_keys && \
    chmod 0600 /home/hadoopuser/.ssh/authorized_keys && \
    chown -R hadoopuser:hadoopuser /home/hadoopuser/.ssh

# Download and install Hadoop
RUN wget https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    && tar -xzf hadoop-${HADOOP_VERSION}.tar.gz \
    && mv hadoop-${HADOOP_VERSION} /opt/hadoop \
    && rm hadoop-${HADOOP_VERSION}.tar.gz

# Download and install Spark
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz \
    && tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz \
    && mv spark-${SPARK_VERSION}-bin-hadoop3 /opt/spark \
    && rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Download and install Hive
RUN wget https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz \
    && tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz \
    && mv apache-hive-${HIVE_VERSION}-bin /opt/hive \
    && rm apache-hive-${HIVE_VERSION}-bin.tar.gz

# Set environment variables
ENV HADOOP_HOME=/opt/hadoop
ENV SPARK_HOME=/opt/spark
ENV HIVE_HOME=/opt/hive
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$HIVE_HOME/bin

# Copy configuration files
COPY config/* $HADOOP_HOME/etc/hadoop/

# Set up SSH
RUN mkdir -p /hadoop/dfs/name /hadoop/dfs/data && \
    chown -R hadoopuser:hadoopuser /hadoop

# Switch back to root for final commands
USER root

# Create bootstrap.sh
RUN echo '#!/bin/bash\n\
service ssh start\n\
export HDFS_NAMENODE_USER=hadoopuser\n\
export HDFS_DATANODE_USER=hadoopuser\n\
export HDFS_SECONDARYNAMENODE_USER=hadoopuser\n\
export YARN_RESOURCEMANAGER_USER=hadoopuser\n\
export YARN_NODEMANAGER_USER=hadoopuser\n\
\n\
if [ "$HOSTNAME" = "namenode" ]; then\n\
    su - hadoopuser -c "$HADOOP_HOME/bin/hdfs namenode -format -force"\n\
    su - hadoopuser -c "$HADOOP_HOME/sbin/start-dfs.sh"\n\
    su - hadoopuser -c "$HADOOP_HOME/sbin/start-yarn.sh"\n\
elif [[ "$HOSTNAME" == "datanode"* ]]; then\n\
    su - hadoopuser -c "$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode"\n\
    su - hadoopuser -c "$HADOOP_HOME/sbin/yarn-daemon.sh start nodemanager"\n\
fi\n\
\n\
tail -f /dev/null' > /bootstrap.sh \
    && chmod +x /bootstrap.sh

CMD ["/bootstrap.sh"]