# Based on https://github.com/M4rotte/docker-centreon
#Written by Sergio Padure for IT-Anywhere

FROM centos:7
USER root
WORKDIR /root

LABEL   maintainer="IT-Anywhere - Sergio Padure" \
        name="Centreon 20.10 Docker Poller" \
        version="0.31"

#Installing required packages
RUN yum install -y epel-release centos-release-scl &&\
    yum install -y http://yum.centreon.com/standard/20.10/el7/stable/noarch/RPMS/centreon-release-20.10-2.el7.centos.noarch.rpm &&\
    yum update -y &&\
    yum install -y centreon-poller-centreon-engine sudo centreon-nrpe-plugin &&\
    yum install -y centreon-plugin-\* &&\
    yum install -y wget nano php php-curl php-common perl-Net-SNMP* net-snmp-utils 'perl(Net::SNMP)' openssl098e.x86_64 &&\
    yum install -y time make gcc autoconf nagios-plugins-perl perl-Config-IniFiles perl-DateTime perl-Scalar-List-Utils perl-Number-Format &&\
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

#Installing wmic 1.4.0
RUN wget https://centreonevopublic.blob.core.windows.net/wmic/wmi-1.4.0.tar &&\
    tar -xzvf wmi-1.4.0.tar &&\
    cd wmi-1.4.0 &&\
    sudo make "CPP=gcc -E -ffreestanding" &&\
    sudo cp Samba/source/bin/wmic /usr/local/bin/ &&\
    cd .. &&\
    rm -rf wmi*

#Installing systemctl replacement in both paths to account for sudo
RUN wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl &&\
    \cp -rf /usr/local/bin/systemctl /usr/bin/systemctl &&\
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