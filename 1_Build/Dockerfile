# Based on https://github.com/M4rotte/docker-centreon
#Written by Sergio Padure for IT-Anywhere

FROM centos:7
USER root
WORKDIR /root

LABEL   maintainer="IT-Anywhere - Sergio Padure" \
        name="Centreon 20.10 Docker Poller" \
        version="0.18"

#Installing required packages
RUN yum install -y epel-release centos-release-scl &&\
    yum install -y http://yum.centreon.com/standard/20.10/el7/stable/noarch/RPMS/centreon-release-20.10-2.el7.centos.noarch.rpm &&\
    yum update -y &&\
    yum install -y centreon-poller-centreon-engine openssh-server openssh-server-sysvinit sudo centreon-nrpe-plugin &&\
    yum install -y yum install centreon-plugin-\* &&\
    yum install -y wget nano &&\
    yum clean all &&\
    rm -rf /var/cache/yum

#Installing systemctl replacement in both paths to account for sudo
RUN wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl &&\
    \cp -rf /usr/local/bin/systemctl /usr/bin/systemctl &&\
    chmod 755 /usr/local/bin/systemctl /usr/bin/systemctl

#Enabling required services
RUN systemctl enable centengine centreontrapd snmptrapd gorgoned

# Entrypoint
COPY entrypoint.sh entrypoint.sh

## Files & perms
RUN chmod +x entrypoint.sh

ENTRYPOINT ["sh", "/root/entrypoint.sh"]

