# ITA-Docker-Centreon-Poller-20-10
ITA-Docker-Centreon-Poller-20-10

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

Basic steps pollers:
  - Double click on StartImport.bat to install the basic requirements. Check logfile to make sure everything is correctly installed
  - From folder 2_Deploy modify the deploymentvariables.env and add the necessary information
  - docker-compose up -d
  - Push configuration from Central to this poller and tail -f /var/lib/centreon-gorgone/gorgoned.log to make sure everything is being deployed correctly
