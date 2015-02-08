# Source https://github.com/evanx by @evanxsummers
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file to
# you under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the
# License. You may obtain a copy of the License at:
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.  


### mininum required custom config 

orgDomain='' # internet domain of your organisation 
admins='' # emails of chronica admins for this organisation (comma/space separated)


### optional custom config

# Notes: 
#   The generated client cert will have: commonName, orgUnit, orgDomain.
#   Additionally you can specify: locality, region, country.
#   Admins can approve certs via the site: https://chronica.co.
#   Designated subscribers subscribe to alerts via the site.

commonName=$USER@`hostname -s` # name of this publisher
orgUnit='default' # network or group
subscribers="$admins" # emails of default subscribers

locality='none'
region='none'
country='none'

# Notes: 
#   When running chronica.sh script, the hourly and daily checks can be scheduled
#   to occur at a given minute past the hour, and hour of day. 

#scheduledHour=''
#scheduledMinute=''

### customizable jobs

c0minutely() {
  c1topic 'Minutely'
  c1metric 'Load'
  c0load
  #echo 'OK: Test'
  #c0login
  #c2tcp chronica.co 443
  #c2nossl chronica.co 80
  #c2nohttps chronica.co 80
  #c2notcp chronica.co 21
  #c2notcp chronica.co 25
  #c2notcp chronica.co 5432
  #c2https chronica.co 443 
  #c2httpsa secure.chronica.co 443
  #c2postgres localhost 5432
  #c2mysql localhost 5432
}

c0hourly() {
  c1topic 'Hourly'
  c1diskspace /var
  #c0megaRaid # LSI megaraid cards
  #c0mdstat # linux software raid
}

c0daily() {
  c1topic 'Daily'
  c0ntp
  c0clock
  #c0checkChronicaPubKey
  #c2certExpiry chronica.co 443
}

# Notes:
#   We implement auth and log checks required for PCI DSS compliance. 
#   However some such checks require priviledged access: 
#   - Read auth logs to ensure that they are not modified.
#   - Monitoring auth config files e.g. /etc/ssh/sshd_config
#   - file integrity monitoring for installed packages e.g. yum verify. 

#c0minutelyPriviledged() {
#  c1verifyHead /var/log/secure # rhel, centos, amazon linux
#  c1verifyHead /var/log/auth.log # ubuntu
#}

#c0hourlyPriviledged() {
#  c0shaAuth
#}

#c0dailyPriviledged() {
#  #c0yumVerify
#  c0rpmVerify
#}

# Notes:
#   Some auth checks required for PCI DSS compliance must be run as an
#   unpriviledged user, e.g. to check that auth config and logs are inaccessible.

#c0dailyNonPriviledged() {
#  echo "INFO: daily nonpriviledged"
#  c1nowrite /etc/ssh/sshd_config
#  c1noread /var/log/secure
#}
