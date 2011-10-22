#! /bin/sh
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

USER=nekls-koha
GROUP=nekls-koha
SITE=nekls
BINDIR=/usr/share/koha/lib/C4/SIP
LOGDIR=/var/log/koha/$SITE
SIP_CONF=/etc/koha/sites/$SITE/SIPconfig.xml

SIP_STOP=$BINDIR/sip_shutdown.sh
SIP_START=$BINDIR/sip_run.sh

case "$1" in
  start)
    echo "Starting SIP Server"
    if [[ $EUID eq 0 ]]
    then
       su - $USER -c '$SIP_START $KOHA_CONF $LOGDIR/sip_out.log $LOGDIR/sip_log.err'
    else
       $SIP_START $SIP_CONF $LOGDIR/sip_out.log $LOGDIR/sip_log.err
    fi
    ;;
  stop)
    echo "Stopping SIP Server"
    if [[ $EUID eq 0 ]]
    then
       su - $USER -c '$SIP_STOP'
    else
       $SIP_STOP
    fi
    ;;
  *)
    echo "Usage: /etc/init.d/koha-SIP-daemon {start|stop}"
    exit 1
    ;;
esac

exit 0

