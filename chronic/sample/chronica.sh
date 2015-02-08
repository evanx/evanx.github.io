#!/bin/bash

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
#
# see https://chronica.co/web/sample/chronica.sh

### default settings

loadWarningThreshold=4
loadCriticalThreshold=9

diskWarningThreshold=80
diskCriticalThreshold=90

packetLossWarningThreshold=20
packetLossCriticalThreshold=60

periodSeconds=60

pingCount=1
tcpTimeout=2
sslTimeout=3
httpTimeout=4
databaseTimeout=2


### default functions

c1topic() {
  echo "Topic: $1"
  echo "Subscribe: $subscribers"
}


### ensure expected environment

c0ensureBash() {
  if ! set | grep -q 'BASH=/bin/bash'
  then
    echo "ERROR: this script requires the bash shell"
    exit 1
  fi
}

c0ensureBin() {
  for prog in sha1sum stat curl
  do
    if ! which $prog >/dev/null
    then
      echo "ERROR: required program not installed: /usr/bin/$prog"
      exit 1  
    elif [ `which $prog` != "/usr/bin/$prog" ]
    then
      echo "ERROR: 'which $prog' is not /usr/bin/$prog"
      exit 1
    fi
  done
}

c0ensureBin


### init custom context

startTimestamp=`date '+%s'`

set -u 

dir=~/.chronica
mkdir -p $dir/etc

cd `dirname $0`
custom=`pwd`/custom.chronica.sh
script=`pwd`/chronica.sh
cp -f $script $dir/copy.chronica.sh

cd $dir

if ! pwd | grep -q '/.chronica$'
then 
  echo "ERROR: pwd sanity check failed:" `pwd`
  exit 1
fi


### init custom

if [ ! -f $custom ]
then
  echo "No $custom"
  exit 1
fi

if ! grep -q '^[a-zA-Z]*=' $custom
then
  echo "Invalid $custom"
  exit 1
fi

if grep '^[a-zA-Z]*=[\s"]*$' $custom
then
  echo "Please edit $custom to configure the above settings"
  exit 1
fi

. $custom

if ! set | grep -q '^commonName=.*[a-z]'
then
  commonName=$USER@`hostname -s`
fi

if ! set | grep -q '^orgDomain=.*[a-z]'
then
  custom=`dirname $0`/custom.chronica.sh
  echo "No custom orgDomain defined in $custom"
  exit 1
fi

if [ -f ~/.chronica/server ]
then
  server=`cat ~/.chronica/server`
elif ! set | grep -q '^server='
then
  server="secure.chronica.co:443"
fi

if ! set | grep -q '^webServer='
then
  webServer="chronica.co"
fi


### overridable defaults

if ! set | grep -q '^scheduledHour='
then
  scheduledHour=`date +%H`
fi

if ! set | grep -q '^scheduledMinute='
then
  scheduledMinute=`date -d '1 minute' +%M`
fi


### debug 

debug=3 # 0 no debugging, 1 log to stdout, 2 to sterr, 3 debug file only

rm -f debug

decho() {
  if [ $debug -eq 1 ]
  then
    echo "chronica: $*" 
  fi
  if [ $debug -eq 2 ]
  then
    echo "chronica: $*" >&2
  fi
  if [ $debug -ge 1 ]
  then
    echo "chronica: $*" >> debug
  fi
}

dcat() {
  if [ $debug -eq 1 ]
  then
    echo "chronica:" 
    cat "$1"
  fi
  if [ $debug -eq 2 ]
  then
    echo "chronica:" >&2
    cat "$1" >&2
  fi
  if [ $debug -ge 1 ]
  then
    echo "chronica:" >> debug
    cat "$1" >> debug
  fi
}


### pid 

previousPid=''
if [ -f pid ] 
then
  previousPid=`head -1 pid`
  decho "previousPid: $previousPid" 
fi


### util 

bcat() {
  if [ -f $1 ]
  then
    if [ `cat $1 | wc -l` -gt 0 ]
    then
      echo "(`head -1 $1 | sed 's/\s*$//'`)"
    fi
  fi
}


### tcp check functions 

c1ping() {
  decho "ping -qc$pingCount $1"
  packetLoss=`ping -qc2 $1 | grep 'packet loss' | sed 's/.* \([0-9]*\)% packet loss.*/\1/'`
  if [ $packetLoss -lt $packetLossWarningThreshold ]
  then
    echo "OK: $1 pingable ($packetLoss% packet loss)"
  elif [ $packetLoss -lt $packetLossCriticalThreshold ]
  then
    echo "WARNING: $1: $packetLoss% packet loss"
  else
    echo "CRITICAL: $1: $packetLoss% packet loss"
  fi
}

c1noping() {
  decho "ping -qc$pingCount $1"
  packetLoss=`ping -qc2 $1 | grep 'packet loss' | sed 's/.* \([0-9]*\)% packet loss.*/\1/'`
  if [ $packetLoss -lt 100 ]
  then
    echo "CRITICAL: $1: $packetLoss% packet loss"
  else
    echo "OK: $1: $packetLoss% packet loss"
  fi
}

c2tcp() {
  decho "nc -w$tcpTimeout $1 $2"
  if nc -w$tcpTimeout $1 $2
  then
    echo "OK: $1 port $2 is open"
  else
    echo "CRITICAL: $1 port $2 is not open"
  fi
}

c2notcp() {
  decho "nc -w$tcpTimeout $1 $2"
  if nc -w$tcpTimeout $1 $2
  then
    echo "CRITICAL: $1 port $2 is not closed"
  else
    echo "OK: $1 port $2 is closed"
  fi
}

c2ssl() {
  decho "timeout $sslTimeout openssl s_client -connect $1:$2"
  if timeout $sslTimeout openssl s_client -connect $1:$2 2> /dev/null < /dev/null | grep '^subject=' 
  then
    echo "OK: $1 port $2 has SSL"
  else
    echo "CRITICAL: $1 port $2 does not have SSL"
  fi
}

c2nossl() {
  decho "timeout $sslTimeout openssl s_client -connect $1:$2"
  if timeout $sslTimeout openssl s_client -connect $1:$2 2> /dev/null < /dev/null | grep '^subject=' 
  then
    echo "CRITICAL: $1 port $2 has SSL"
  else
    echo "OK: $1 port $2 is not SSL"
  fi
}

c2https() {
  decho "curl -1 --connect-timeout $httpTimeout -k -s -I https://$1:$2"
  if curl -1 --connect-timeout $httpTimeout -k -s -I https://$1:$2 | grep '^HTTP' | tee https | grep -q OK 
  then
    echo "OK: $1 port $2 has HTTPS" `bcat https`
  else 
    echo "CRITICAL: $1 port $2 HTTPS is unavailable" `bcat https`
  fi
}

c2nohttps() {
  decho "curl -1 --connect-timeout $httpTimeout -k -s -I https://$1:$2"
  if curl -1 --connect-timeout $httpTimeout -k -s -I https://$1:$2 | grep '^HTTP' | tee https | grep -q OK 
  then
    echo "CRITICAL: $1 port $2 has HTTPS available" `bcat https`
  else 
    echo "OK: $1 port $2 HTTPS is unavailable" `bcat https`
  fi
}

c2httpsa() { # client-authenticated HTTPS
  decho "curl -1 --connect-timeout $httpTimeout -s -I https://$1:$2"
  if curl -1 --connect-timeout $httpTimeout -s -I https://$1:$2 | grep '^HTTP' | tee https | grep -q OK 
  then
    echo "CRITICAL: $1 port $2 does not require HTTPS client auth" `bcat https`
  else 
    echo "OK: $1 port $2 unavailable for HTTPS without client auth" `bcat https`
  fi
}

c2nohttpsa() {
  decho "curl -1 --connect-timeout $httpTimeout -s -I https://$1:$2"
  if curl -1 --connect-timeout $httpTimeout -s -I https://$1:$2 | grep '^HTTP' | tee https | grep -q OK 
  then
    echo "OK: $1 port $2 is available for HTTPS without client auth" `bcat https`
  else 
    echo "CRITICAL: $1 port $2 is unavailable for HTTPS without client auth" `bcat https`
  fi
}

c2http() {
  decho "curl -1 --connect-timeout $httpTimeout -s -I http://$1:$2"
  if curl -1 --connect-timeout $httpTimeout -s -I http://$1:$2 | grep '^HTTP' | tee http | grep -q OK 
  then
    echo "OK: $1 port $2 has HTTP available" `bcat http`
  else 
    echo "CRITICAL: $1 port $2 HTTP is unavailable" `bcat http`
  fi
}

c2nohttp() {
  decho "curl -1 --connect-timeout $httpTimeout -s -I http://$1:$2"
  if curl -1 --connect-timeout $httpTimeout -s -I http://$1:$2 | grep '^HTTP' | tee http | grep -q OK 
  then
    echo "CRITICAL: $1 port $2 has HTTP available" `bcat http`
  else 
    echo "OK: $1 port $2 HTTP is unavailable" `bcat http`
  fi
}

c2certExpiry() {
  expiryDate=`openssl s_client -connect $1:$2 2> /dev/null < /dev/null | openssl x509 -text |
    grep '^ *Not After :' | sed 's/^ *Not After : \(\S*\) \(\S*\) \S* \(20[0-9]*\) \(.*\)/\1 \2 \3/'`
  expiryMonth=`echo "$expiryDate" | cut -f1`
  if date -d '1 month' | grep -q "$expiryMonth"
  then
    echo "WARNING: $1 cert expires next month: $expiryDate"  
  elif date | grep -q "$expiryMonth"
  then
    echo "WARNING: $1 cert expires this month: $expiryDate"  
  else 
    echo "OK: $1 cert expires: $expiryDate"  
  fi
}



### ssh password or key checks

c2nosshpass() {
  if ! which sshpass > /dev/null
  then
    echo "INFO no sshpass installed so unable to perform nosshpass check"
  else
    if sshpass -p "" ssh $1 -p $2 date 2>&1 | head -1 | tee sshpass |
        grep -q "Permission denied, please try again."
    then
      echo "CRITICAL: $1 port $2 ssh is prompting for an ssh password"
    else
      echo "OK: $1 port $2 ssh is not prompting for an ssh password"
    fi
  fi
}

c2sshkey() {
  if ! which sshpass > /dev/null
  then
    echo "INFO no sshpass installed so unable to perform sshkey check"
  else
    if sshpass -p "" ssh $1 -p $2 date 2>&1 | grep -q "Permission denied (publickey)."
    then
      echo "OK: $1 port $2 requires an ssh key"
    else
      echo "CRITICAL: $1 port $2 ssh is not permission denied"
    fi
  fi
}


### convenience with default ports

c1http() {
  c2http $1 80
}

c1nohttp() {
  c2nohttp $1 80
}

c1https() {
  c2https $1 443
}

c1nohttps() {
  c2nohttps $1 443
}

c1httpsa() {
  c2httpsa $1 443
}

c1nohttpsa() {
  c2nohttpsa $1 443
}


### database checks 

c2postgres() {
  if timeout $databaseTimeout psql -h $1 -p $2 -c 'select 1' 2>&1 | grep -q '^psql: FATAL:  role\| 1 \|^$' 
  then
    echo "OK: PostgreSQL server is running on $1, port $2"
  else
    echo "CRITICAL: PostgreSQL server not running on $1, port $2"
  fi
}

c2mysql() {
  if timeout $databaseTimeout mysql -h $1 -P $2 -B -e 'select 1' 2>&1 | grep -q 'Access denied for user\|^1$' 
  then
    echo "OK: MySQL server is running on $1, port $2"
  else
    echo "CRITICAL: MySQL server not running on $1, port $2"
  fi
}


### reverse checks

c2rhttp() {
  echo "Check-http: $1 $2"
}

c2rhttps() {
  echo "Check-https: $1 $2"
}

c2rtcp() {
  echo "Check-tcp: $1 $2"
}

c2rssl() {
  echo "Check-ssl: $1 $2"
}


### log file checks

if set | grep -q 'BASH=/bin/bash'
then
  declare -A fileSizes
  declare -A fileHashes
fi

c1verifyHead() {
  c0ensureBash
  if echo " ${!fileSizes[@]} " | grep -q " $1 " 
  then
    if [ ! -f $1 ]
    then
      echo "WARNING: $1: no longer readable"
    elif [ `stat -c %s $1` -lt "${fileSizes[$1]}" ]
    then
      echo "WARNING: $1: size decreased from ${fileSizes[$1]} to" `stat -c %s $1` 
    elif head -c "${fileSizes[$1]}" $1 | sha1sum | cut -d' ' -f1 | grep -q "${fileHashes[$1]}"
    then
      echo "OK: $1: head ${fileSizes[$1]} bytes unchanged: ${fileHashes[$1]}"
    else
      echo "WARNING: $1: first ${fileSizes[$1]} bytes changed: ${fileHashes[$1]}" `
        head -c "${fileSizes[$1]}" $1 | sha1sum | cut -d' ' -f1` 
    fi
  fi
  if [ -f $1 ]
  then
    fileSizes[$1]=`stat -c %s $1`
    fileHashes[$1]=`head -c "${fileSizes[$1]}" $1 | sha1sum | cut -d' ' -f1`
  fi
}


### test log monitoring 

c1verifyHeadTest() {
  while [ 1 ]
  do
    c1verifyHead $1
    sleep 5
  done
}


### ubuntu logs

c0verifyAuthLog() {
  c1verifyHead /var/log/auth.log
}


### rh logs 

c0verifySecureAuthLog() {
  c1verifyHead /var/log/secure
}


### auth checks

c0login() {
  echo "<br><b>login</b>"
  last | head | grep '^[a-z]' | sed 's/\(^reboot .*\) - *[0-9].*/\1/'
}

c1logPeriod() {
  day=`date -d "$2" +'%e'`
  cat $1 | cut -b5-99 | grep "^$day"
}

c2logAcceptedKeyCount() {
  c1logPeriod $@ | grep sshd |
    grep ' Accepted publickey for ' |
    sed 's/.* Accepted publickey for \(.*\) from \(.*\) port .*/\1/' |
    uniq -c | sort -nr
}

c2logFailedPasswordCount() {
  c1logPeriod $@ | grep sshd |
    grep ' Failed password for ' |
    sed 's/.* Failed password for \(.*\) from \(.*\) port .*/\1/' |
    uniq -c | sort -nr
}

c0authLogAcceptedKeyCount() {
  c2logAcceptedKeyCount /var/log/auth.log yesterday
}

c0authLogFailedPasswordCount() {
  c2logFailedPasswordCount /var/log/auth.log yesterday
}


### clock checks

c1ntp() {
  echo "NtpOffsetSec:" `ntpdate -q $1 | tail -1 | sed 's/.* offset \(.*\) sec$/\1/'`
}

c0ntp() {
  c1ntp pool.ntp.org
}

c0clock() {
  echo "Timestamp:" `date +'%Y-%m-%d %T %Z'`
  [ -f /etc/timezone ] && echo "Timezone:" `cat /etc/timezone` 
  echo "Clock:" `date +%s`
}


### metrics

c1metric() {
  echo "Metric: $1"
}


### mega raid 

c0megaRaid() {
  echo "<br><b>megaRaid</b>"
  /usr/sbin/MegaCli -ldinfo -lall -aall | grep '^State'
  /usr/sbin/MegaCli -pdlist -aall | grep '^Firmware'
}


### linux software raid 

c0mdstat() {
  echo "<br><b>mdstat</b>"
  cat /proc/mdstat 2>/dev/null | grep ^md -A1 | sed 's/.*\[\([U_]*\)\]/\1/' |
    sed '/^\s*$/d' | grep 'U\|^md'
}


### other common checks

c0load() {
  loadStatus=OK
  load=`cat /proc/loadavg | cut -d. -f1`
  [ $load -gt $loadWarningThreshold ] && loadStatus=WARNING
  [ $load -gt $loadCriticalThreshold ] && loadStatus=CRITICAL
  echo "Load $loadStatus - `cat /proc/loadavg`"
}

c0diskspace() {
  diskStatus=OK
  diskUsage=`df -h 2>/dev/null | grep '[0-9]%' | sed 's/.* \([0-9]*\)% .*/\1/' | sort -nr | head -1`
  [ $diskUsage -gt $diskWarningThreshold ] && diskStatus=WARNING
  [ $diskUsage -gt $diskCriticalThreshold ] && diskStatus=CRITICAL
  echo "Diskspace $diskStatus - $diskUsage%"
}

c1diskspace() {
  diskStatus=OK
  diskUsage=`df -h $1 | grep '[0-9]%' | sed 's/.* \([0-9]*\)% .*/\1/' | sort -nr | head -1`
  [ $diskUsage -gt $diskWarningThreshold ] && diskStatus=WARNING
  [ $diskUsage -gt $diskCriticalThreshold ] && diskStatus=CRITICAL
  echo "Diskspace $diskStatus - $diskUsage%"
}

c0processes() {
  echo 'Metric: processes'
  echo -n 'Value: '
  cat /proc/stat | grep ^processes
}

### rpm and yum installed package integrity checks

c0yumVerify() {
  sha1sum /usr/bin/yum
  /usr/bin/yum verify
}

c0rpmVerify() {
  sha1sum /bin/rpm
  /bin/rpm -Va
}


### auth checks

c0shaAuth() {
  echo "<br><b>shaAuth</b>"
  sha1sum /etc/group
  sha1sum /etc/passwd
  [ -f /etc/ssh/sshd_config ] && sha1sum /etc/ssh/sshd_config
  [ -f /root/.ssh/authorized_keys ] && sha1sum /root/.ssh/authorized_keys
  for file in `locate authorized_keys | grep '^/home/[a-z]*/\.*ssh/authorized_keys$'` 
  do
    [ -f $file ] && sha1sum $file | sed 's/\/home\/\([a-z]\{3\}\).*/\1/'
  done
}


### crypto 

c0ensurePubKey() {
  if [ ! -f etc/chronica.pub.pem ]
  then
    curl -1 -s https://chronica.co/sample/chronica.pub.pem -o etc/chronica.pub.pem
    echo 'Fetched public key: https://chronica.co/sample/chronica.pub.pem'
    cat etc/chronica.pub.pem
    chmod 600 etc/chronica.pub.pem
    ls etc/chronica.pub.pem
  fi 
}

c0ensureKey() {
  if [ ! -f etc/key.pem ] 
  then
    rm -f etc/cert.pem
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout etc/key.pem -out etc/cert.pem \
      -subj "/CN=$commonName/O=$orgDomain/OU=$orgUnit"
    echo 'Generated client certficate:'
    openssl x509 -text -in etc/cert.pem | grep CN
    chmod 600 etc/cert.pem
    ls etc/cert.pem
  fi
}

c0ensureCert() {
  if [ ! -f etc/server.pem ]
  then
    if openssl s_client -connect $server 2>/dev/null </dev/null | grep -q 'BEGIN CERT'
    then
      openssl s_client -connect $server 2>/dev/null |
        sed -n -e '/BEGIN CERT/,/END CERT/p' > etc/server.pem
      echo "Fetched server certificate:"
      openssl x509 -text -in etc/server.pem | grep 'CN='
      chmod 600 etc/server.pem
      ls etc/server.pem
    fi
  fi
}

c0ensurePubKey
c0ensureKey
c0ensureCert


### resolve server

c0resolve() {
  echo $orgDomain | curl -1 -s -k --cacert etc/server.pem --data-binary @- \
    -H 'Content-Type: text/plain' -H "Subscribe: $subscribers" -H "Admin: $admins" https://$webServer/resolve
}

c0ensureResolve() {
  while [ 1 ]
  do
    decho "INFO: resolving secure server for $orgDomain from $webServer"
    resolvedServer=`c0resolve`
    if echo "$resolvedServer" | grep -q "ERROR:"
    then
      echo "$resolvedServer"
    elif [ -z "$resolvedServer" ]
    then
      echo "ERROR: no response from resolve server query"
    else
      echo "OK: resolved server: $resolvedServer"
      server="$resolvedServer"
      echo $resolvedServer > ~/.chronica/server
      break
    fi
    sleep 5
  done
}

c0checkServer() {
  if ! echo | openssl s_client -connect $server 2>/dev/null | grep -q '^subject='
  then
    echo "INFO: $server is offline, resolving"
    c0ensureResolve
  else 
    decho "INFO: $server is online"
  fi
}

c0ensureServer() {
  if [ ! -f ~/.chronica/server ]
  then
    c0ensureResolve
  else 
    decho "INFO: previously resolved server: $server"
  fi
}

c0resetServer() {
  rm -f ~/.chronica/server
  c0ensureServer
}

#c0ensureServer
#c0checkServer


### java keystore for chronica log4j appender connection

c0printKeyStore() {
  if [ ! -f etc/keystore.jks ]
  then
    echo "no keystore"
  else 
    keytool -keystore etc/keystore.jks -storepass chronica -keypass chronica -alias chronica4j -exportcert -rfc |
      openssl x509 -text | grep 'CN='
  fi
}

c0ensureKeyStore() {
  if [ ! -f etc/keystore.jks ]
  then
    keytool -keystore etc/keystore.jks -storepass chronica -alias chronica4j -keypass chronica -genkeypair -keyalg rsa -validity 999 \
          -dname "CN=$commonName, O=$orgDomain, OU=$orgUnit"
    echo "Generated keystore:"
    keytool -keystore etc/keystore.jks -storepass chronica -keypass chronica -alias chronica4j -exportcert -rfc |
      openssl x509 -text | grep 'CN='
    chmod 600 etc/keystore.jks
  fi
  if [ ! -f etc/truststore.jks ]
  then
    keytool -keystore etc/truststore.jks -storepass chronica -alias chronica -importcert -file etc/server.pem -noprompt
    echo "Created truststore:"
    keytool -keystore etc/truststore.jks -storepass chronica -alias chronica -exportcert -rfc | openssl x509 -text | grep 'CN='
    chmod 600 etc/truststore.jks
  fi
}

c0resetKeyStore() {
  rm -f etc/keystore.jks
  rm -f etc/truststore.jks
  c0ensureKeyStore
}

c0genKeyStore() {
  c0resetKeyStore
}


### standard functionality

c1curl() {
  tee curl.txt | curl -1 -s -k --cacert etc/server.pem --key etc/key.pem --cert etc/cert.pem \
    --data-binary @- -H 'Content-Type: text/plain' https://$server/$1 -H "orgDomain: $orgDomain" # > curl.out 2> curl.err
}

c0enroll() {
  echo "$admins" | c1curl enroll 
}

c0poll() {
  echo "" | c1curl poll 
}

c1push() {
  echo "$1" | c1curl push
}

c0reset() {
  rm -f etc/cert.pem etc/key.pem etc/server.pem
  c0ensureKey
  c0ensureCert
  c0ensureServer
  chmod 600 etc/cert.pem etc/key.pem etc/server.pem
}

c0post() {
  c1curl post
}

c0hourlyPost() {
  c0hourly 2>&1 | tee hourly | c0post
  dcat hourly
}

c0minutelyPost() {
  c0minutely 2>&1 | tee minutely | c0post
  dcat minutely
  c0enroll
}

c0minutelySim() { # invoke minutely many times in succession to test charting
  for i in $(seq 150) 
  do
    c0minutely | c0post
  done
}

c0dailyPost() {
  c0daily 2>&1 | tee daily | c0post
  dcat daily
}

c0hourlyCron() {
  c0hourlyPost
  if [ `date +%H` -eq $scheduledHour ] 
  then
    c0dailyPost
  fi
}

c0minutelyCron() {
  c0minutelyPost
  c0stopped
  if [ `date +%M` -eq $scheduledMinute ]
  then
    if [ -f hourly ]
    then
      if [ `stat -c %Z hourly` -gt `date -d '55 minutes ago' '+%s'` ]
      then
        decho "too soon for hourly" `stat -c %Z hourly` vs `date -d '55 minutes ago' '+%s'` 
        return
      fi
    fi
    c0hourlyCron
  else
    if [ -f hourly ]
    then
      if [ `stat -c %Z hourly` -lt `date -d '59 minutes ago' '+%s'` ]
      then
        c0hourlyCron
      fi
    fi
  fi
}


### update script

c0checkChronicaPubKey() {
  ( curl -1 s https://chronica.co/sample/chronica.pub.pem | sha1sum | cut -f1 -d' ' |
    grep -v `cat  ~/.chronica/etc/chronica.pub.pem | sha1sum | cut -f1 -d' '` &&
    echo 'CRITICAL: chronica.pub.key' ) || echo 'OK: chronica.pub.key'
}

c0updateInfo() {
  c0ensurePubKey
  echo 'Run the following commands to verify the digest and signature:'
  echo '('
  echo 'curl -1 -s https://raw.github.com/evanx/chronic/master/src/chronic/web/sample/chronica.sh | sha1sum'
  echo 'curl -1 -s https://chronica.co/sample/chronica.sh | sha1sum'
  echo 'curl -1 -s https://chronica.co/sample/chronica.sh.sha1.txt'
  echo 'curl -1 -s https://chronica.co/sample/chronica.sh.sha1.sig.txt |'
  echo '  openssl base64 -d | openssl rsautl -verify -pubin -inkey ~/.chronica/etc/chronica.pub.pem'
  echo ')'
  echo "Then run the following command to update your script:"
  echo '('
  echo "curl -1 -s https://chronica.co/sample/chronica.sh -o $script"
  echo ')'
}

c0updateCheck() {
  c0updateInfo
  c0checkChronicaPubKey
  echo 'Verifying https://chronica.co/sample/chronica.sh.sha1.sig.txt using ~/.chronica/etc/chronica.pub.pem:'
  if curl -1 -s https://chronica.co/sample/chronica.sh.sha1.sig.txt |
    openssl base64 -d | openssl rsautl -verify -pubin -inkey ~/.chronica/etc/chronica.pub.pem
  then
    echo 'OK: signature verified: https://chronica.co/sample/chronica.sh.sha1.sig.txt'
  else
    echo 'CRITICAL: verification failed: https://chronica.co/sample/chronica.sh.sha1.sig.txt'
  fi
  echo -n `curl -1 -s https://chronica.co/sample/chronica.sh | sha1sum` 
  echo ' sha1sum https://chronica.co/sample/chronica.sh' 
  echo -n `curl -1 -s https://chronica.co/sample/chronica.sh.sha1.txt` 
  echo ' - https://chronica.co/sample/chronica.sh.sha1.txt'
  echo -n `curl -1 -s https://raw.github.com/evanx/chronic/master/src/chronic/web/sample/chronica.sh.sha1.txt` 
  echo ' - chronica.sh.sha1.txt on github'
  echo -n `curl -1 -s https://raw.github.com/evanx/chronic/master/src/chronic/web/sample/chronica.sh | sha1sum` 
  echo ' - chronica.sh on github'
}

c0update() {
  c0updateInfo
  echo 'Verifying https://chronica.co/sample/chronica.sh.sha1.sig.txt using ~/.chronica/etc/chronica.pub.pem'
  if ! curl -1 -s https://chronica.co/sample/chronica.sh.sha1.sig.txt |
    openssl base64 -d | openssl rsautl -verify -pubin -inkey ~/.chronica/etc/chronica.pub.pem |
    grep `curl -1 -s https://chronica.co/sample/chronica.sh.sha1.txt | head -1`
  then
      echo "ERROR: failed check: https://chronica.co/sample/chronica.sh.sha1.sig.txt"
  else 
      echo "OK: verified: https://chronica.co/sample/chronica.sh.sha1.sig.txt"
    if ! curl -1 -s https://chronica.co/sample/chronica.sh | sha1sum |
      grep `curl -1 -s https://chronica.co/sample/chronica.sh.sha1.txt | head -1`
    then
      echo "ERROR: failed check: https://chronica.co/sample/chronica.sh.sha1.txt"
    else 
      echo "OK: matches: https://chronica.co/sample/chronica.sh.sha1.txt"
      echo "Running the following command to update your script:"
      echo "curl -1 -s https://chronica.co/sample/chronica.sh -o $script"
      curl -1 -s https://chronica.co/sample/chronica.sh -o $script
      exit $?
    fi
  fi
}


### post with headers 

c1postheaders() {
  tee curl.txt | curl -1 -s -k --cacert etc/server.pem --key etc/key.pem --cert etc/cert.pem \
    --data-binary @- -H 'Content-Type: text/plain' -H "$1" https://$server/post 
}

c2postheaders() {
  tee curl.txt | curl -1 -s -k --cacert etc/server.pem --key etc/key.pem --cert etc/cert.pem \
    --data-binary @- -H 'Content-Type: text/plain' -H "$1" -H "$2" https://$server/post 
}

c3postheaders() {
  tee curl.txt | curl -1 -s -k --cacert etc/server.pem --key etc/key.pem --cert etc/cert.pem \
    --data-binary @- -H 'Content-Type: text/plain' -H "$1" -H "$2" -H "$3" https://$server/post 
}

c2postTopicSub() {
  tee curl.txt | curl -1 -s -k --cacert etc/server.pem --key etc/key.pem --cert etc/cert.pem \
    --data-binary @- -H 'Content-Type: text/plain' -H "Topic: $1" -H "Subscribe: $2" https://$server/post 
}


### logging

c0log() {
  pwd
  ls -l
  cat run.out
}


### lifecycle

c0ps() {
  [ -n "$previousPid" ] && echo "pid file: $previousPid"
  echo "this pid: $$"
  echo "ps aux:"
  ps aux | grep -v grep | grep "chronica"
  echo "pgrep -f chronica.sh:"
  pgrep -f chronica.sh
}

c0killall() {
  c0ps
  pids=`pgrep -f chronica.sh | grep -v $$`
  for pid in $pids 
  do
    if ps x | grep $pid | grep -v grep | grep '[0-9]' 
    then
      kill "$pid"
      echo "killed $pid"
    fi
  done
}

c0kill() {
  if [ -n "$previousPid" ] 
  then
    if ps -p "$previousPid" >/dev/null
    then
      kill "$previousPid"
    fi
  fi
}

c0stop() {
  rm -f pid
}

c0stopped() {
  if [ ! -f pid ]
  then
    decho 'cancelled (pid file removed)'
    exit 1
  elif [ `head -1 pid` -ne $$ ]
  then
    decho 'cancelled (pid file changed)'
    exit 1
  fi
}

c0run() {
  trap 'rm -f pid' EXIT
  echo $$ > pid
  debug=2
  c0ensureResolve
  c0checkServer
  c0enroll
  rm -f hourly minutely
  c0hourlyCron
  while [ 1 ]
  do
    time=`date +%s`
    periodTime=`date -d "$periodSeconds seconds" +%s`
    decho "periodTime $periodTime (current $time, period $periodSeconds seconds, pid $$)"
    c0minutelyCron
    c0stopped
    decho "periodTime $periodTime vs stat `stat -c %Z minutely`"
    decho "minute `date +%M` vs scheduledMinute $scheduledMinute"
    decho "`date '+%H:%M:%S'` time `date +%s` finish $periodTime for $periodSeconds seconds"
    time=`date +%s`
    if [ $periodTime -gt $time ]
    then
      sleepSeconds=`expr $periodTime - $time`
      decho "sleep $sleepSeconds seconds until periodTime $periodTime from time $time"
      sleep $sleepSeconds
    else
      periodSeconds=`expr $periodSeconds + 30`
      decho "extending periodSeconds to $periodSeconds"
    fi
  done
}

c0restart() {    
  debug=0  
  c0kill
  c0run 2> run.err > run.out < /dev/null & 
  sleep 1
  c0ps
}

c0start() {
  c0restart
}

c0help() {
  echo "commands and their required number of arguments:"
  cat $script | grep '^c[0-9]\S*() {\S*$' | sed 's/^c\([0-9]\)\(\S*\)() {/\1: \2/'
}

if [ $# -gt 0 ]
then
  command=$1
  shift
  c$#$command "$@"
else 
  c0minutely
  c0hourly
  c0daily
fi

