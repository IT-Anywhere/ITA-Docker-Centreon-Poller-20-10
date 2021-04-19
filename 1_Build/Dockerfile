# Based on https://github.com/M4rotte/docker-centreon
#Written by Sergio Padure for IT-Anywhere

#Container to build wmic
FROM centos:7 AS build-env
USER root
WORKDIR /root

#Installing required dependencies
RUN yum install -y wget tar sudo autoconf make gcc libdatetime-perl build-essential g++ python-dev

#Building wmic 1.4.0
RUN wget https://centreonevopublic.blob.core.windows.net/wmic/wmi-1.4.0.tar &&\
    tar -xzvf wmi-1.4.0.tar &&\
    cd wmi-1.4.0 &&\
    sudo make "CPP=gcc -E -ffreestanding" &&\
    sudo cp Samba/source/bin/wmic /usr/local/bin/

#Container to prepare all the required components for the deployment
FROM centos:7
USER root
WORKDIR /root

LABEL   maintainer="IT-Anywhere - Sergio Padure" \
        name="Centreon 20.10 Docker Poller" \
        version="0.32"

#Installing required packages
RUN yum install -y epel-release centos-release-scl &&\
    yum install -y http://yum.centreon.com/standard/20.10/el7/stable/noarch/RPMS/centreon-release-20.10-2.el7.centos.noarch.rpm &&\
    yum update -y &&\
    yum install -y centreon-poller-centreon-engine sudo centreon-nrpe-plugin centreon-plugin-\* wget time nano php php-curl php-common net-snmp-utils openssl098e.x86_64 nagios-plugins-perl perl-Config-IniFiles perl-DateTime perl-Scalar-List-Utils perl-Number-Format perl-Net-SNMP* 'perl(Net::SNMP)' &&\
    yum clean all &&\
    rm -rf /var/cache/yum &&\
    ln -s /usr/lib/nagios/plugins/check_centreon_nrpe /usr/lib64/nagios/plugins/check_centreon_nrpe

#Installing WMI support for queries
ADD nagiosplugins /usr/lib/nagios/plugins/
RUN chmod 755 -R /usr/lib/nagios/plugins/

#Copying additional files
COPY checkwmiplus/bin/release.sh /bin/release.sh
COPY ./checkwmiplus/etc/check_wmi_plus/. /etc/check_wmi_plus/
RUN ls -la /etc/check_wmi_plus/*

#Copying wmic 1.4.0 executable from the build-env stage
COPY --from=build-env /root/wmi-1.4.0/Samba/source/bin/wmic /usr/local/bin/
COPY --from=build-env /bin/winexe /bin
COPY --from=build-env /bin/wmic /bin

#Installing systemctl replacement in both paths to account for sudo
RUN wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl &&\
    cp -rf /usr/local/bin/systemctl /usr/bin/systemctl &&\
    chmod 755 /usr/local/bin/systemctl /usr/bin/systemctl

#Enabling required services
RUN systemctl enable centengine centreontrapd snmptrapd gorgoned

# timezone env with default
ENV TZ Europe/Brussels

# Entrypoint
COPY entrypoint.sh entrypoint.sh

## Files & perms
RUN chmod +x entrypoint.sh

ENTRYPOINT ["sh", "/root/entrypoint.sh"]