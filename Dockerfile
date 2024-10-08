FROM ubuntu:20.04

ENV HADOOP_VERSION=3.3.6
ENV SPARK_VERSION=3.5.3
ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Install sudo first
RUN apt-get update && apt-get install -y sudo

# Create hdfs and yarn users and set home directories
RUN useradd -m -d /home/hdfs hdfs && \
    useradd -m -d /home/yarn yarn && \
    useradd -m -d /home/developer developer && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

USER developer
WORKDIR /home/developer

# install ssh and pdsh
RUN sudo apt-get update && \
    sudo apt-get install -y ssh

# Add environment variable to .bashrc
RUN echo 'export PDSH_RCMD_TYPE=ssh' >> ~/.bashrc

# Generate SSH key and configure SSH
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

# install jdk
RUN sudo apt-get install -y openjdk-8-jdk

# install hadoop
RUN wget https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz && \
    sudo mv hadoop-${HADOOP_VERSION} /opt/hadoop

# Set Java environment in hadoop-env.sh
RUN sed -i 's|export JAVA_HOME=.*|export JAVA_HOME=${JAVA_HOME}/|' $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Add PATH and JAVA_HOME to /etc/environment
RUN echo 'PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> /etc/environment && \
    echo 'JAVA_HOME=${JAVA_HOME}' >> /etc/environment

# Change Permission and group of user hdfs
RUN sudo usermod -aG hadoopuser hdfs && \
    sudo chown hdfs:root -R /opt/hadoop/ && \
    sudo chmod g+rwx -R /opt/hadoop/ && \
    sudo adduser hdfs sudo

USER hdfs

# Generate SSH key for user hdfs
RUN ssh-keygen -t rsa -N "" -f /home/hdfs/.ssh/id_rsa && \
    cat /home/hdfs/.ssh/id_rsa.pub >> /home/hdfs/.ssh/authorized_keys

# Set permissions for the .ssh directory
RUN chmod 700 /home/hdfs/.ssh && \
    chmod 600 /home/hdfs/.ssh/authorized_keys

CMD ["tail", "-f", "/dev/null"]