#!/bin/sh

set -eux

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
echo_e=""

NEXUS_HOSTNAME=${nx_host:-nexus.isb}
NEXUS_USERNAME=${nx_user:-docker-nexus-user}
NEXUS_PASSWORD=${nx_pass:-`echo VGgxc1BTc3N3b3JkSXNOMHRWZXJ5U2VjdXJl | base64 --decode`}
BUILD_SKIP_CRT=${nx_skip_crt:-false}

OTP_ROOT_CRT="# OTP Root Certificate\n\
-----BEGIN CERTIFICATE-----\n\
MIIC/TCCAeWgAwIBAgIQG8lW5X1f76xL4IE7JJj2JjANBgkqhkiG9w0BAQsFADAR\n\
MQ8wDQYDVQQDEwZSb290Q0EwHhcNMTkwMzA2MTEzOTA1WhcNMzQwMzA2MTE0OTA1\n\
WjARMQ8wDQYDVQQDEwZSb290Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\n\
AoIBAQCgLiuqbcPZT694JkaMIF+wodlMz9K3w0bOZh5RCJJw5xi7+osGNK63dxQy\n\
87qXieE3rheZKOgHjS2bao2RJ60f78JQwUPV9tg4zB6g2pYP+oQ8OARuhEczr5YG\n\
H/mmGpAteeBaWLWMDRmFJqKwjmiwmitzqjEkxHjB5J4SGlD9FFziFn9shClC66c0\n\
FmawdHo70Rx5GsVamFDNgrdC08i4UXrz8wNapi1Qwn/lmVY58G4TpuyjmRTij2De\n\
PUcEXUevrqNqSdFh71HSXKD7L/BcUZp1Ya3ZBCTZDCl1WiW8QX/fU3tnhTwJrdqH\n\
E3poPY0kP89+PnR0EPrZsVASSiFvAgMBAAGjUTBPMAsGA1UdDwQEAwIBhjAPBgNV\n\
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBSNXRtvBaLmUA+vYeOskxycKqWd5jAQBgkr\n\
BgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQsFAAOCAQEAEtkMcv1/n/WNIgVwgSfs\n\
A/2ibDplnQyvzxeLb/OcE5U5YdJIeNZETy7XjLGQhPK8i2/VeYD4w4kdhjIjHO4L\n\
CRheWdtDmEsAMhB+uqtQMW/fswhqMf89MOjoc6zdQLWs1CsicqhseepLp+1UoxEE\n\
NWSo2rBftK5BYHDxY0by55JfhlcbDFHht/DhJhD/TKKMVwOxWa36GSinx4VMvtdI\n\
UGlP0SOewVXSOvKBtCZf/MioPKCiV5Ut1SmzLPsx40wUmdIajLk0Kf5Csfyhf1wL\n\
DrkFZEFmk31lAL7Uyv6C3I88R79pqsEKt26YWEIrVT+IlsxK+Hh8Fxgi/muPrFfD\n\
AQ==\n\
-----END CERTIFICATE-----
"

OTP_ROOT_CRT_PATH=

if [ -e /etc/os-release ] ; then
  os_id=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release | tr -d '"' )
fi

if [ ! -z $os_id ] ; then
  echo $echo_e "OS Id: $os_id"
else 
  echo $echo_e "Can't detect OS name. Exit"
  exit 1
fi

case "$os_id" in
  ## Debian & Ubuntu #########################
  debian*|ubuntu*)
    export DEBIAN_FRONTEND="noninteractive"
    echo $echo_e "${GREEN}$os_id: Debian family${NC}"
    OTP_ROOT_CRT_PATH=/usr/local/share/ca-certificates/RootOTP.crt
    CA_CERT_INSTALL_CMD="apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*"
    UPDATE_CA_CMD="update-ca-certificates"

    echo $echo_e "${GREEN}Setup APT repositories${NC}"
    if [ -d "/etc/apt/auth.conf.d" ] ; then
        OTP_APT_AUTHCONF_PATH=/etc/apt/auth.conf.d/00nexus.conf
    else
        OTP_APT_AUTHCONF_PATH=/etc/apt/auth.conf
    fi

    apt_proto=$(dpkg -s apt | grep -q "Version:\s2" && echo "http://" || echo "")
    echo $echo_e "machine $apt_proto$NEXUS_HOSTNAME" > $OTP_APT_AUTHCONF_PATH
    echo $echo_e "login $NEXUS_USERNAME" >> $OTP_APT_AUTHCONF_PATH
    echo $echo_e "password $NEXUS_PASSWORD" >> $OTP_APT_AUTHCONF_PATH

    sed -i '/#.*/d' /etc/apt/sources.list
    sed -i 's/[a-z]\+.\(debian.org\|ubuntu.com\)/'$NEXUS_HOSTNAME'/g' /etc/apt/sources.list
    echo $echo_e "${GREEN}Done${NC}"
    ;;
  ## Centos & Fedora & Rhel? #########################
  centos*|fedora*)
    echo_e="-e"
    echo $echo_e "${GREEN}$os_id: RHEL family${NC}" 
    if [ -d "/etc/dnf" ] ; then pm=dnf; else pm=yum;fi
    OTP_ROOT_CRT_PATH=/etc/pki/ca-trust/source/anchors/RootOTP.crt
    CA_CERT_INSTALL_CMD="$pm install -y ca-certificates && $pm clean all && rm -rf /var/cache/yum/*"
    UPDATE_CA_CMD="update-ca-trust"

    echo $echo_e "${GREEN}Setup YUM/DNF repositories${NC}"
    mkdir -p /etc/$pm/vars
    echo $NEXUS_USERNAME > /etc/$pm/vars/username
    echo $NEXUS_PASSWORD > /etc/$pm/vars/password

    # disable fastest mirror plugin
    if [ -f "/etc/yum/pluginconf.d/fastestmirror.conf" ] ; then
      sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf
    fi
    if [ $os_id == "centos" ]; then
      # comment mirrorlists
      sed -i 's/^mirrorlist=http:\/\/mirrorlist.centos.org/#&/' /etc/yum.repos.d/*.repo
      # add user/pass for each repo id pointing to mirror.centos.org
      sed -i '/^#\?baseurl=http:\/\/mirror.centos.org.*/ a username=\$username\npassword=\$password' /etc/yum.repos.d/*.repo
      # change all baseurl pointing to mirror.centos.org
      sed -i 's|^#\?baseurl=http://mirror.centos.org|'baseurl=http://$NEXUS_HOSTNAME'|g' /etc/yum.repos.d/*.repo
    fi
    if [ $os_id == "fedora" ]; then
      # comment mirrorlists
      sed -i 's/^metalink=https:\/\/mirrors.fedoraproject.org/#&/' /etc/yum.repos.d/*.repo
      # add user/pass for each repo id pointing to mirror.centos.org
      sed -i '/^#\?baseurl=http:\/\/download.*/ a username=\$username\npassword=\$password' /etc/yum.repos.d/*.repo
      # change all baseurl pointing to mirror.centos.org
      sed -i 's|^#\?baseurl=http://download.[^/]*/pub|'baseurl=http://$NEXUS_HOSTNAME'|g' /etc/yum.repos.d/*.repo
      # disable fedora-cisco-openh264 repo
      sed -i 's|^enabled=1|enabled=0|g' /etc/yum.repos.d/fedora-cisco-openh264.repo*
    fi 
  ;;
  alpine*)
    echo_e="-e"
    echo $echo_e "${GREEN}$os_id: Alpine disto${NC}"
    OTP_ROOT_CRT_PATH=/usr/local/share/ca-certificates/RootOTP.crt
    CA_CERT_INSTALL_CMD="apk add --no-cache ca-certificates && rm -rf /var/cache/apk/*"
    UPDATE_CA_CMD="update-ca-certificates"
    
    # For Java Images
    # Set Java trusted store use to system-wide store
    if [ ! -z ${JAVA_HOME+x} ]; then
      cacertsFile=;
      for f in "$JAVA_HOME/lib/security/cacerts" "$JAVA_HOME/jre/lib/security/cacerts"; 
        do if [ -e "$f" ]; then cacertsFile="$f"; break; fi; done
      if [ -z "$cacertsFile" ] || ! [ -f "$cacertsFile" ]; then
        echo >&2 "error: failed to find cacerts file in $JAVA_HOME";
      else 
        CA_CERT_INSTALL_CMD="apk add --no-cache ca-certificates java-cacerts && rm -rf /var/cache/apk/*"
        UPDATE_CA_CMD="
          if [ ! -L \"$cacertsFile\" ]; then
            echo \"Create 'cacerts' symlink\"
            rm -f $cacertsFile
            ln -s /etc/ssl/certs/java/cacerts $cacertsFile
          fi
          update-ca-certificates
        "
      fi
    fi

    echo $echo_e "${GREEN}Setup APK repositories${NC}"
    sed -i 's|dl-cdn.alpinelinux.org|'$NEXUS_HOSTNAME'|g' /etc/apk/repositories 
    echo "HTTP_AUTH=basic:*:$NEXUS_USERNAME:$NEXUS_PASSWORD /sbin/apk \$@" > /usr/bin/apk
    chmod +x  /usr/bin/apk
  ;;
  rhel*)
    echo_e="-e"
    echo $echo_e "${RED}Temporary unsupported OS: '$os_id'${NC}" ; exit 1
  ;;
  *)
    echo $echo_e "${RED}Unknown OS: '$os_id'${NC}" ; exit 1
  ;;
esac

if [ $BUILD_SKIP_CRT = false  ] ; then 
  echo $echo_e "${GREEN}Install 'ca-certificates' package...${NC}"
  eval "$CA_CERT_INSTALL_CMD" && echo $echo_e "${GREEN}Success!${NC}"

  echo $echo_e "${GREEN}Copy RootOTP.crt to $OTP_ROOT_CRT_PATH${NC}"
  echo $echo_e $OTP_ROOT_CRT > $OTP_ROOT_CRT_PATH

  echo $echo_e "${GREEN}Running $UPDATE_CA_CMD...${NC}"
  eval "$UPDATE_CA_CMD" && echo $echo_e "${GREEN}Success!${NC}"
fi

exit 0
