#!/bin/sh

# Based on https://github.com/M4rotte/docker-centreon
# Written by Sergio Padure for IT-Anywhere

#Function for graceful exit if closed
graceful_exit() {
    echo -e "\nWas asked to terminate myself…" >&2
    /etc/init.d/sshd stop
    kill -15 $(cat /var/run/snmpd.pid) && rm -f /var/run/snmpd.pid
    /etc/init.d/centengine stop
    kill -15 $(cat /run/nrpe/nrpe.pid) && echo "NRPE server has been stopped."
    kill -15 $DUMMY_PROCESS_PID
    exit 0
}

trap graceful_exit 2 3 15 19

#Setting IP address variable
while [ -z "${IP_ADDR}" ]; do IP_ADDR="$(hostname -i)"; done

#Not sure what this does, it seems that it just prints the data to the terminal?

cat <<EOF
##########  Centreon poller   ##########
ADDRESS         : $IP_ADDR
HOSTNAME        : $HOSTNAME
TIMEZONE        : $(cat /etc/timezone)
CENTREON ENGINE : $(/centreon/bin/centengine -V |awk '{if (NR<2) {print $3,$4,$5}}')
CENTREON BROKER : $(/centreon/bin/cbd -v |awk '{print $3,$4,$5}')
SNMP DAEMON     : $(/usr/sbin/snmpd -v |awk '/^NET-SNMP version.*/ {print $3}')
NRPE DAEMON     : $(/usr/sbin/nrpe -V |awk '{if (NR>1) print $2}')
########################################
EOF

#Adding basic configuration for central to be able to connect
cat <<EOF > /etc/centreon-gorgone/config.d/40-gorgoned.yaml
name:  gorgoned-$HOSTNAME
description: Configuration for poller $HOSTNAME
gorgone:
  gorgonecore:
    id: $(printenv POLLERID)
    external_com_type: tcp
    external_com_path: "*:5556"
    authorized_clients: 
      - key: $(printenv PRIVKEY)
    privkey: "/var/lib/centreon-gorgone/.keys/rsakey.priv.pem"
    pubkey: "/var/lib/centreon-gorgone/.keys/rsakey.pub.pem"
  modules:
    - name: action
      package: gorgone::modules::core::action::hooks
      enable: true

    - name: engine
      package: gorgone::modules::centreon::engine::hooks
      enable: true
      command_file: "/var/lib/centreon-engine/rw/centengine.cmd"
EOF

#Starting ad enabling the service
systemctl start gorgoned
systemctl enable gorgoned

# Get the SSH public key of the Central server to authorize user “centreon” to connect from the central to the poller
# First, we need the central server to be ready before downloading the key
echo " * Waiting for the central server to be ready…\n"
until [ "$(curl --silent --location --output /dev/null --write-out '%{http_code}' --fail --noproxy '*'  $(printenv PUBKEYURL))" = "200" ]; do printf '.'; sleep 1; done
# Server responded, actually download the key and add it to the authorized_keys file.
echo -e "\n * Authorizing user “centreon” to connect from the central server…"
curl --silent --location --noproxy "*" $(printenv PUBKEYURL) >> /var/lib/centreon/.ssh/authorized_keys &&\
     chown -R centreon:centreon /var/lib/centreon/.ssh &&\
     chmod 0600 /var/lib/centreon/.ssh/authorized_keys
# Adding ssh key to root user as well
curl --silent --location --noproxy "*" $(printenv PUBKEYURL) >> /root/.ssh/authorized_keys &&\
     chown -R centreon:centreon /root/.ssh/authorized_keys &&\
     chmod 0600 /root/.ssh/authorized_keys

## !!!! It is still required to log once manually with this key. TODO: Push poller host key onto central’s known_hosts file for user centreon

#Disabling password authentication
sed -re 's/^(PasswordAuthentication)([[:space:]]+)yes/\1\2no/' -i.`date -I` /etc/ssh/sshd_config

# Setting timezone
sed -i -e "s/\;date.timezone =/date.timezone = $(printenv TIMEZONE)/" /etc/php.ini

## Starting SSH server.
echo -e " * Starting SSH server… \n"
/etc/init.d/sshd start

#Disabling password authentication
sed -re 's/^(PasswordAuthentication)([[:space:]]+)yes/\1\2no/' -i.`date -I` /etc/ssh/sshd_config
systemctl restart sshd

echo -e " * Starting Centreon Engine… \n"
/etc/init.d/centengine start
systemctl start centengine
systemctl enable centengine
systemctl start centreon
systemctl enable centreon

# Starting all services that can be started by the systemctl script
/usr/local/bin/systemctl

# Start a dummy process which never terminates, to prevent the entrypoint to terminate itself if all its children have restarted…
tail -f /dev/null &
DUMMY_PROCESS_PID=$!

wait