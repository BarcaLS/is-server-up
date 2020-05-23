#!/bin/bash
# is-server-up.sh
#
# Script which allows you to check if specified host is alive and send information about it to server.
# For example it can be used to check if your home server is online. It it is down you can assume that the power is down.
#
# REQUIREMENTS
# I)   Logging via keys is necessary.
# II)  Script may have to be run by root (e.g. when only root can use sockets - necessary for "ping" command).
# III) Script should be run from cron, e.g. every 1 minute. It runs constantly, can't be run in multiple instances. You
#      should add "#cron" at the end to allow detecting properly if the script is running already. Example:
#      */1 * * * * /home/barca/rozne/is-server-up/is-server-up.sh >/dev/null 2>&1 #cron

############
# Settings #
############

SSH_HOST="user@localhost -p 22" # host to connect to (format: LOGIN@HOST -p PORT)
SCRIPT_DIR="/home/user/is-server-up" # directory with this script
SENDER="User <user@host.com>" # sender of e-mail
RECIPIENT="user@host.com,user2@host.com" # recipient of e-mail (you can specify multiple recipients separating them with comma)
SENDEMAIL="/home/user/is-server-up/sendEmail" # path to sendEmail (needed to send e-mail)
SMTP_SERVER="mail.host.com" # SMTP server
SMTP_USER="user@host.com" # SMTP user
SMTP_PASS="password" # SMTP password
SUBJECT_ON="Server responds again" # subject to send when the host is on again
MSG_ON="There's electricity now." # message to send when the host is on again
SUBJECT_OFF="Server doesn't respond" # subject to send when the host is on again
MSG_OFF="There's no electricity." # message to send when the host is on again
CHECK_CMD="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q \$SSH_HOST whoami" # command to check host's status, \$SSH_HOST will be replaced by script with IP to check
PAUSE="40" # pause in seconds after checking

#############
# Main Part #
#############

CHECK_CMD=`echo $CHECK_CMD | sed -e "s/\\$SSH_HOST/\$SSH_HOST/g"` # insert content of $SSH_HOST instead of SSH_HOST string
SSH_LOGIN=`echo $SSH_HOST | cut -d@ -f1` # retrieve login from SSH_HOST
while true; do

    # check if this script is currently running
    NUMBER_OF_THIS_SCRIPTS_RUNNING=`ps aux | grep is-server-up.sh | grep -v grep | grep -v sudo | grep -v cron | wc -l`

    if [ "$NUMBER_OF_THIS_SCRIPTS_RUNNING" -gt 2 ]; then
    	echo "This script is currently running. Exiting."; exit
    fi

    # function executed when SSH_HOST appeared or disappeared
    appeared_or_disappeared () {
        echo "I'm sending e-mail to $RECIPIENT."
        $SENDEMAIL -q -f "$SENDER" -t $RECIPIENT -u "$SUBJECT - $DAY $HOUR" -m " " -s $SMTP_SERVER -o tls=no -o message-charset=utf-8 -xu $SMTP_USER -xp $SMTP_PASS
        
        # save to log and rotate logs to last 1000 lines
        echo "$DAY $HOUR $SUBJECT" >> $SCRIPT_DIR/logs/emails.log
        TMP=$(tail -n 1000 $SCRIPT_DIR/logs/emails.log)
        echo "${TMP}" > $SCRIPT_DIR/logs/emails.log
    }

    # checking if alive
    echo -n "Checking $SSH_HOST. Status: "
		
    CMD_OUTPUT=$($CHECK_CMD 2>&1)
    STATE=1
    if [ "$CMD_OUTPUT" == "$SSH_LOGIN" ]; then STATE=0; fi
    echo "$STATE"
	
    # getting and saving current data
    DAY=`date +"%Y-%m-%d"`
    HOUR=`date +"%H:%M:%S"`
    echo "$DAY $HOUR $STATE" >> $SCRIPT_DIR/logs/status.log
	
    # rotate logs to last 1000 lines
    TMP=$(tail -n 10000 $SCRIPT_DIR/logs/status.log)
    echo "${TMP}" > $SCRIPT_DIR/logs/status.log

    # reading last 12 lines of data
    tail -n 12 $SCRIPT_DIR/logs/status.log > $SCRIPT_DIR/logs/tmp.log
    LINE=1
    while read -r DAY_TMP HOUR_TMP STATE_LAST; do
        case "$LINE" in
	1)  STATE_LAST1=$STATE_LAST;
	    ;;
	2)  STATE_LAST2=$STATE_LAST
	    ;;
	3)  STATE_LAST3=$STATE_LAST
	    ;;
	4)  STATE_LAST4=$STATE_LAST
	    ;;
	5)  STATE_LAST5=$STATE_LAST
	    ;;
	6)  STATE_LAST6=$STATE_LAST
	    ;;
	7)  STATE_LAST7=$STATE_LAST
	    ;;
	8)  STATE_LAST8=$STATE_LAST
	    ;;
	9)  STATE_LAST9=$STATE_LAST
	    ;;
	10) STATE_LAST10=$STATE_LAST
	    ;;
	11) STATE_LAST11=$STATE_LAST
    	    ;;
	12) DAY=$DAY_TMP
	    HOUR=$HOUR_TMP
	    STATE_LAST12=$STATE_LAST
	    ;;
	esac
	(( LINE ++ ))
    done < $SCRIPT_DIR/logs/tmp.log
	
    # SSH_HOST has appeared or disappeared
    CHANGE=""
	
    # command results something other than 0 if host is down and 0 if host is up
    if [[ "$STATE_LAST1$STATE_LAST2$STATE_LAST3$STATE_LAST4$STATE_LAST5$STATE_LAST6$STATE_LAST7$STATE_LAST8$STATE_LAST9$STATE_LAST10$STATE_LAST11$STATE_LAST12" =~ 111111111110 ]]; then SUBJECT=$SUBJECT_ON; MSG=$MSG_ON; appeared_or_disappeared; fi
    if [[ "$STATE_LAST1$STATE_LAST2$STATE_LAST3$STATE_LAST4$STATE_LAST5$STATE_LAST6$STATE_LAST7$STATE_LAST8$STATE_LAST9$STATE_LAST10$STATE_LAST11$STATE_LAST12" =~ 011111111111 ]]; then SUBJECT=$SUBJECT_OFF; MSG=$MSG_OFF; pkill -f ":localhost:"; appeared_or_disappeared; fi

    # pause
    echo "Queue done. Sleeping $PAUSE seconds."
    sleep $PAUSE
done
