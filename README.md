# Centreon.20.04.Collaboration
Centreon.20.04.Collaboration

Basic steps Host:
  - Deploy Centreon 20.10 host server from ISO following the instructions in the Centreon knowledge base: https://docs.centreon.com/current/en/installation/installation-of-a-central-server/using-centreon-iso.html

  - Add the pollers using the wizard and replace 
    - service centengine start
    - service centengine stop
    - service centengine restart
    - service centengine reload
    - service cbd reload
  with
    - systemctl start centengine
    - systemctl stop centengine
    - systemctl restart centengine
    - systemctl reload centengine
    - systemctl reload cbd

  - Install wireguard on the server using Nyr's script: https://github.com/Nyr/wireguard-install
  - Create client configurations using Nyr's script
  - Modify the AllowedIPs for the client configurations to be only subnet/24 (example: 10.7.0.0/24) instead of 0.0.0.0/0
  - Enable debug logging in Parameters -> Debug

Basic steps buildserver/register:
  - Deploy docker register
    - docker run -d  -p 5000:5000  --restart=always  --name registry  -v /root/registry:/var/lib/registry  registry:2
  - Install wireguard using Nyr's script. Configuration is irrelevant
    - wg-quick down wg0
    - rm -f /etc/wireguard/wg0.conf
    - nano or vi /etc/wireguard/wg0.conf and paste the config created beforehand on host
    - wg-quick up wg0
    - git pull, build from folder 1_Build and then push to register

Basic steps pollers:
  - Double click on StartImport.bat to install the basic requirements. Check logfile to make sure everything is correctly installed
  - From folder 2_Deploy modify the deploymentvariables.env and add the necessary information
  - docker-compose up -d
  - Push configuration from Central to this poller and tail -f /var/lib/centreon-gorgone/gorgoned.log to make sure everything is being deployed correctly