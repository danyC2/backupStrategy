#!/bin/bash

# on client side (computer where you want to sync files)
#   - this script must belong to root and be executable
#   - rsync software must have been installed (apt install rsync)
#   - msmtp must have been installed (apt install msmtp) and configuration
#     for sending mails must be active in /etc/msmtprc - msmtprc must be
#     owned by root:root and rights be chmod u=rx,g=,u=
#   - ssh host keys must have been exchanged beforehand between machines
#     (initial use in console mode allows exchange)
#   - to maintain stability of the SSH connection, add in etc/ssh/ssh_config
#     ServerAliveInterval 300 and ServerAliveCountMax 30

# on server side (remote server where original files are stored)  
#   - ssh public key used by this script must have been added to
#     /root/.ssh/authorized_keys
#   - to maintain stability of the SSH connection, add in etc/ssh/sshd_config
#     ClientAliveInterval 30 et ClientAliveCountMax 5

##### insert your own parameters in the lines ending with : # EDIT

# --- identity

SCRIPTNAME=$0
SCRIPTVERSION="1.0 rev. 051"
AUTHOR="..." # EDIT
EMAILTO="...@gmail.com" # EDIT
LOCALHOSTNAME=$(hostname)
echo ""
echo "$SCRIPTNAME version $SCRIPTVERSION"

# --- help fonctions

f_date()
  {
  date "+%Y-%m-%d"
  }
  
f_date_heure()
  {
  date "+%Y/%m/%d %H:%M:%S"
  }
  
f_date_stamp()
  {
  date "+%s"
  }
  
f_date_dayofweek()
  {
  date "+%u"
  }  
  
# --- variables, instance check, RAID1 health and needed files 

START=$(f_date_heure)
STARTSTAMP=$(f_date_stamp)
LOG="oHC4rsync.log"
HISTORY="oHC4rsynchistory.log"
SNAPSHOTLOG="oHC4rsyncsnapshot.log"
SNAPSHOTHISTORY="oHC4rsyncsnapshothistory.log"
LOCALTARGET="/media/ofirsthd/oHC4rsync" # EDIT
LOCALMODIFS="/media/ofirsthd/oHC4rsyncmodifs" # EDIT
SNAPSHOTS="/media/ofirsthd/oHC4snapshots/" # EDIT
SUJETOK="rsync OK"
SUJETKO="$LOCALHOSTNAME rsync ERROR ERROR ERROR"
EMAILFROM="...@gmail.com" # EDIT
EMAILHEADER1="To: $EMAILTO\nFrom: $EMAILFROM\nSubject: "
EMAILHEADER2="\n\n"
SLASH="/"

if [[ "`pidof -x $(basename $0) -o %PPID`" ]] # check if we are the only local instance
  then
    echo "$START - script already running"
    EMAILSUBJECT="Already running STOP STOP STOP"
    EMAILMESSAGE="Another instance of this script is still running."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
    exit 100
  else
    echo "$START - instance check OK"
fi

if [ ! -f "$LOG" ] # check if log file doesn't exists
  then
    HEURE=$(f_date_heure)
    echo "$HEURE - creating missing $LOG"
    echo "$HEURE - starting ..." > $LOG 2>&1
  else
    HEURE=$(f_date_heure)
    echo "$HEURE - starting new $LOG"
    echo "$HEURE - starting ..." > $LOG 2>&1
fi

if [ ! -f "$HISTORY" ] # check if history log file doesn't exists
  then
    HEURE=$(f_date_heure)
    echo "$HEURE - creating missing $HISTORY"
    touch $HISTORY
fi

if [ ! -f "$SNAPSHOTLOG" ] # check if snapshot log file doesn't exists
  then
    HEURE=$(f_date_heure)
    echo "$HEURE - creating missing $SNAPSHOTLOG"
    echo "$HEURE - starting ..." > $SNAPSHOTLOG 2>&1
  else
    HEURE=$(f_date_heure)
    echo "$HEURE - starting new $SNAPSHOTLOG"
    echo "$HEURE - starting ..." > $SNAPSHOTLOG 2>&1
fi

if [ ! -f "$SNAPSHOTHISTORY" ] # check if snapshot history log file doesn't exists
  then
    HEURE=$(f_date_heure)
    echo "$HEURE - creating missing $SNAPSHOTHISTORY"
    touch $SNAPSHOTHISTORY
fi

echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$START - $SCRIPTNAME version $SCRIPTVERSION" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "" >> $LOG 2>&1

# --- SSH key to use & exporting borg passphrase

SSHKEYID="/root/.ssh/ssh_oFIRST_root_ed25519_key" # EDIT

HEURE=$(f_date_heure)
if [ ! -f "$SSHKEYID" ] # check if ssh key file doesn't exists
  then
    echo "$HEURE - ssh key missing"
    EMAILSUBJECT="$LOCALHOSTNAME SSH KEY MISSING ERROR ERROR ERROR"
    EMAILMESSAGE="Unable to read the SSH key file on the hard drive."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
    exit 110
  else
    echo "$HEURE - SSH key check OK"
fi

# --- today's date and day of week

TODAY=$(f_date)
DAYOFWEEK=$(f_date_dayofweek)

# --- create snapshot directory, once a day only

HEURE=$(f_date_heure)
if [ ! -d "$SNAPSHOTS$TODAY" ]
  then
    echo "$HEURE - $LOCALHOSTNAME making snapshot directory ..."
    mkdir -p $SNAPSHOTS$TODAY$SLASH >> $LOG 2>&1
  else
    echo "$HEURE - $LOCALHOSTNAME snapshot directory exists"
    SNAPSHOTALLREADYDONE=true
fi

# --- test link to remote server & get remote hostname

OHC4USER="databackup" # EDIT
OHC4SERVER="10.0.1.220" # EDIT
OHC4PORT="2222" # EDIT
OHC4REMOTEFILE="/files/oHC4.txt" # EDIT
OHC4REMOTESOURCE="/files/data" # EDIT

REMOTEHOSTNAME=$(ssh -p $OHC4PORT -i $SSHKEYID $OHC4USER@$OHC4SERVER \
                "hostname")  # get remote server hostname

HEURE=$(f_date_heure)
if ssh -p $OHC4PORT -i $SSHKEYID $OHC4USER@$OHC4SERVER \
    "[ ! -f $OHC4REMOTEFILE ]"
  then
    echo "$HEURE - $REMOTEHOSTNAME HD error"
    EMAILSUBJECT="$REMOTEHOSTNAME HD ERROR ERROR ERROR"
    EMAILMESSAGE="Unable to read the test file from the hard drive $REMOTEHOSTNAME."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
    exit 120
  else
    echo "$HEURE - $REMOTEHOSTNAME HD check OK"
fi

# --- snapshot actual state on client side

HEURE=$(f_date_heure)
if [ ! "$SNAPSHOTALLREADYDONE" ] 
  then
    echo "" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1  
    echo "$HEURE - $LOCALHOSTNAME snapshot" >> $LOG 2>&1
    echo "$LOCALTARGET$SLASH to" >> $LOG 2>&1
    echo "$SNAPSHOTS$TODAY$SLASH" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "$HEURE - snapshot, on $LOCALHOSTNAME"  
    cp -al $LOCALTARGET$SLASH $SNAPSHOTS$TODAY$SLASH >> $LOG 2>&1  
    ls -la -R $SNAPSHOTS$TODAY$SLASH >> $SNAPSHOTLOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "$HEURE - snapshot already done" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "nothing to do right now" >> $LOG 2>&1
    echo "$HEURE - snapshot already done"
fi

# --- rsync

OPTIONSRSYNC="--stats --recursive --times --verbose --links --perms --group --owner --checksum --bwlimit=750000 --timeout=3600 --delete --delete-during"

HEURE=$(f_date_heure)
echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1  
echo "$HEURE - rsync from oHC4" >> $LOG 2>&1
echo "$OHC4SERVER$OHC4REMOTESOURCE$SLASH to" >> $LOG 2>&1
echo "$LOCALTARGET$SLASH" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$HEURE - $LOCALTARGET$SLASH to oFIRST, using rsync ..."
    
rsync -e "ssh -p $OHC4PORT -i $SSHKEYID" --log-format="%t %i %n (%l bytes)" \
$OPTIONSRSYNC \
$OHC4USER@$OHC4SERVER:$OHC4REMOTESOURCE$SLASH --backup \
$LOCALTARGET$SLASH \
--backup-dir=$LOCALMODIFS$SLASH$TODAY$SLASH >> $LOG 2>&1

# --- duration

END=$(f_date_heure)
ENDSTAMP=$(f_date_stamp)
ELAPSEDTIME=$(($ENDSTAMP-$STARTSTAMP))
echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$END - elapsed time: $ELAPSEDTIME second(s)" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "" >> $LOG 2>&1

# --- log analysis and sending email (with log in case of error)

if grep -i -E "error|cannot|BackendException" $LOG
  then
    EMAILSUBJECT=$SUJETKO
    EMAILMESSAGE="$(<$LOG)"
  else
    EMAILSUBJECT=$SUJETOK
    EMAILMESSAGE="Everything seems OK. See also file $LOG"
fi
HEURE=$(f_date_heure)
echo "$HEURE - $EMAILSUBJECT"
HEURE=$(f_date_heure)
echo "$HEURE - sending mail..." >> $LOG 2>&1
printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO # /var/log/msmtp
HEURE=$(f_date_heure)
echo "$HEURE - mail sended" >> $LOG 2>&1

# --- log archiving

echo "$HEURE - waiting 3 seconds ..."
sleep 3
cat $LOG >> $HISTORY
cat $SNAPSHOTLOG >> $SNAPSHOTHISTORY

# --- end

HEURE=$(f_date_heure)
echo "$HEURE - backup ended"

exit 0