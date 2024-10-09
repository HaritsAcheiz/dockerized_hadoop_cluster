FROM ubuntu:20.04

ENV HADOOP_VERSION=3.3.6
ENV SPARK_VERSION=3.5.3
ENV HADOOP_HOME=/opt/hadoop
ENV SPARK_HOME=/opt/spark
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin
ENV YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

# Set timezone non-interactively
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install sudo and other necessary tools
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    openssh-server \
    openssh-client \
    pdsh \
    wget \
    curl \
    openjdk-8-jdk \
    sshpass

# Install JDK
RUN sudo apt-get install -y openjdk-8-jdk

# Install Hadoop
RUN wget https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz && \
    sudo mv hadoop-${HADOOP_VERSION} ${HADOOP_HOME} && \
    rm hadoop-${HADOOP_VERSION}.tar.gz

# Install Spark
RUN wget https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    tar -xzf spark-${SPARK_VERSION}-bin-hadoop3.tgz && \
    sudo mv spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME} && \
    rm spark-${SPARK_VERSION}-bin-hadoop3.tgz

# Create hdfs user and set up SSH
RUN useradd -m -d /home/hdfs hdfs && \
    echo "hdfs ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER hdfs
WORKDIR /home/hdfs

# Set up SSH for hdfs user
RUN mkdir -p /home/hdfs/.ssh && \
    ssh-keygen -t rsa -P '' -f /home/hdfs/.ssh/id_rsa && \
    cat /home/hdfs/.ssh/id_rsa.pub >> /home/hdfs/.ssh/authorized_keys && \
    chmod 700 /home/hdfs/.ssh && \
    chmod 600 /home/hdfs/.ssh/authorized_keys && \
    chown -R hdfs:hdfs /home/hdfs/.ssh

# Add environment variable to .bashrc
RUN echo 'export PDSH_RCMD_TYPE=ssh' >> ~/.bashrc

# Set Java environment in hadoop-env.sh
RUN sed -i 's|export JAVA_HOME=.*|export JAVA_HOME=${JAVA_HOME}|' ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

# Add PATH and environment variables to /etc/environment
RUN echo "PATH=$PATH" | sudo tee -a /etc/environment && \
    echo "JAVA_HOME=${JAVA_HOME}" | sudo tee -a /etc/environment && \
    echo "HADOOP_HOME=${HADOOP_HOME}" | sudo tee -a /etc/environment && \
    echo "SPARK_HOME=${SPARK_HOME}" | sudo tee -a /etc/environment

# Set up Spark configuration
RUN cp ${SPARK_HOME}/conf/spark-env.sh.template ${SPARK_HOME}/conf/spark-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${SPARK_HOME}/conf/spark-env.sh && \
    echo "export SPARK_DIST_CLASSPATH=$(${HADOOP_HOME}/bin/hadoop classpath)" >> ${SPARK_HOME}/conf/spark-env.sh

# Expose necessary ports
EXPOSE 9000 9870 9864 9866 8088 8042 4040 22

# Copy Hadoop configuration files
COPY /hadoop_config/core-site.xml $HADOOP_HOME/etc/hadoop/
COPY /hadoop_config/hdfs-site.xml $HADOOP_HOME/etc/hadoop/
COPY /hadoop_config/mapred-site.xml $HADOOP_HOME/etc/hadoop/
COPY /hadoop_config/yarn-site.xml $HADOOP_HOME/etc/hadoop/

# Create necessary directories for HDFS
RUN sudo mkdir -p /hadoop/dfs/name /hadoop/dfs/data && \
    sudo chown -R hdfs:hdfs /hadoop && \
    sudo chmod 755 /hadoop

# Create a directory for scripts
RUN sudo mkdir -p /opt/hadoop-scripts

# Copy the entrypoint script
COPY entrypoint.sh /opt/hadoop-scripts/entrypoint.sh
RUN sudo chmod +x /opt/hadoop-scripts/entrypoint.sh

RUN curl -o wait-for-it.sh https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh && \
    chmod +x wait-for-it.sh

# Set the entrypoint
ENTRYPOINT ["/opt/hadoop-scripts/entrypoint.sh"]

# Default command (can be overridden in docker-compose.yml)
CMD ["namenode"]