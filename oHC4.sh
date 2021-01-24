#!/bin/bash

# on client side (DATA server on LAN)
#   - this script must belong to root and be executable
#   - the borg software must have been installed (apt install borgbackup)
#   - the file /root/.borg.passphrase must exist and contain the variable
#     BORG_PASSPHRASE="...", with valid borg passphrase (chmod u=rx,g=,u=)
#   - msmtp must have been installed (apt install msmtp) the configuration
#     for sending mails must be available in /etc/msmtprc, wich must be
#     owned by root:root and where rights chmod u=rx,g=,u=
#   - ssh host keys must have been exchanged beforehand between machines
#     (initial use in console mode allows exchange)
#   - to maintain stability of the SSH connection, add in etc/ssh/ssh_config
#     ServerAliveInterval 300 and ServerAliveCountMax 30

# on server side (remote backup server on WAN)  
#   - ssh public key used by this script must have been added to
#     /root/.ssh/authorized_keys
#   - to maintain stability of the SSH connection, add in etc/ssh/sshd_config
#     ClientAliveInterval 30 et ClientAliveCountMax 5

##### insert your own parameters in the lines ending with : # EDIT

# --- identity

SCRIPTNAME=$0
SCRIPTVERSION="1.0 rev 051"
AUTHOR="..." # EDIT
EMAILTO="...@gmail.com" # EDIT
LOCALHOSTNAME=$(hostname)
echo ""
echo "$SCRIPTNAME version $SCRIPTVERSION"

# --- fonctions

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

f_archive_stamp()
  {
   date "+%Y%m%d_%H%M"
  }
  
f_unset_env()
  {
  unset BORG_RSH
  unset BORG_PASSPHRASE
  } # remove borg environment variables
  
# --- variables, instance check, RAID1 health and needed files 

START=$(f_date_heure)
STARTSTAMP=$(f_date_stamp)
LOG="oHC4.log"
HISTORY="oHC4history.log"
SNAPSHOTLOG="oHC4snapshot.log"
SNAPSHOTHISTORY="oHC4snapshothistory.log"
SOURCE="/files/data" # EDIT
SNAPSHOTS="/files/snapshots/" # EDIT
SUJETOK="Backup OK"
SUJETKO="$LOCALHOSTNAME backup ERROR ERROR ERROR"
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

if [ ! -f "$HISTORY" ] # # check if history log file doesn't exists
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

LINE=""
cat /proc/mdstat | while read LINE # check if RAID1 works as expected on DATA server
do
  if [[ "$LINE" == *"[UU]"* ]]; then
    HEURE=$(f_date_heure)
    echo "$HEURE - RAID1 seems to work as expected"
    echo "$HEURE - RAID1 seems to work as expected" >> $LOG 2>&1
    echo "$HEURE - $LINE" >> $LOG 2>&1
  elif [[ "$LINE" == *"[_U]"* ]]; then
    HEURE=$(f_date_heure)
    echo "$HEURE - RAID1 ERROR ERROR ERROR DISK 1"
    echo "$HEURE - RAID1 ERROR ERROR ERROR DISK 1" >> $LOG 2>&1
    echo "$HEURE - $LINE" >> $LOG 2>&1
    EMAILSUBJECT="$LOCALHOSTNAME ERROR ERROR ERROR"
    EMAILMESSAGE="One of the two disks (disk 1) seems to be missing in RAID1."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
  elif [[ "$LINE" == *"[U_]"* ]]; then
    echo "$HEURE - RAID1 ERROR ERROR ERROR DISK 2"
    echo "$HEURE - RAID1 ERROR ERROR ERROR DISK 2" >> $LOG 2>&1
    echo "$HEURE - $LINE" >> $LOG 2>&1
    EMAILSUBJECT="$LOCALHOSTNAME ERROR ERROR ERROR"
    EMAILMESSAGE="One of the two disks (disk 2) seems to be missing in RAID1."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
  fi
done

# --- SSH key to use & borg passphrase

SSHKEYID="/root/.ssh/ssh_oHC4_root_ed25519_key" # EDIT

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

BORG_RSH="ssh -i $SSHKEYID"
export BORG_RSH # export $BORG_RSH available out of script, in child processes

. /root/.borg.passphrase # publish $BORG_PASSPHRASE variable
export BORG_PASSPHRASE # export $BORG_PASSPHRASE available out of script, in child processes


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

# --- test backup server connection, RAID1, hostname and maximum network speed

OHC4BACKUPUSER="root" # EDIT
OHC4BACKUPSERVER="10.0.10.220" # EDIT
OHC4BACKUPPORT="2222" # EDIT
OHC4BACKUPIPERFPORT="2223" # EDIT
OHC4BACKUPREMOTEFILE="/files/oHC4backup.txt" # EDIT
OHC4BACKUPREPOSITORY="/files/borgbackups/oHC4" # EDIT
OHC4BACKUPREPOSITORYCHECK="$OHC4BACKUPREPOSITORY/README" # EDIT

REMOTEHOSTNAME=$(ssh -p $OHC4BACKUPPORT -i $SSHKEYID $OHC4BACKUPUSER@$OHC4BACKUPSERVER \
                "hostname")  # get remote server hostname

HEURE=$(f_date_heure)
if ssh -p $OHC4BACKUPPORT -i $SSHKEYID $OHC4BACKUPUSER@$OHC4BACKUPSERVER \
    "[ ! -f $OHC4BACKUPREMOTEFILE ]"
  then
    echo "$HEURE - $REMOTEHOSTNAME HD error"
    EMAILSUBJECT="$REMOTEHOSTNAME HD ERROR ERROR ERROR"
    EMAILMESSAGE="Unable to read the test file from the hard drive $REMOTEHOSTNAME."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
    exit 120
  else
    echo "$HEURE - $REMOTEHOSTNAME HD check OK"
fi

LINE=""
ssh -p $OHC4BACKUPPORT -i $SSHKEYID $OHC4BACKUPUSER@$OHC4BACKUPSERVER \
"cat /proc/mdstat" | while read LINE # check if RAID1 works as expected on remote server
do
  if [[ "$LINE" == *"[UU]"* ]]; then
    HEURE=$(f_date_heure)
    echo "$HEURE - RAID1 on $REMOTEHOSTNAME works as expected"
    echo "$HEURE - RAID1 on $REMOTEHOSTNAME works as expected" >> $LOG 2>&1
    echo "$HEURE - $LINE" >> $LOG 2>&1
  elif [[ "$LINE" == *"[_U]"* ]]; then
    HEURE=$(f_date_heure)
    echo "$HEURE - RAID1 on $REMOTEHOSTNAME ERROR DISK 1"
    echo "$HEURE - RAID1 on $REMOTEHOSTNAME ERROR DISK 1" >> $LOG 2>&1
    echo "$HEURE - $LINE" >> $LOG 2>&1
    EMAILSUBJECT="$REMOTEHOSTNAME ERROR ERROR ERROR"
    EMAILMESSAGE="One of the two disks (disk 1) seems to be missing in RAID1."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
  elif [[ "$LINE" == *"[U_]"* ]]; then
    echo "$HEURE - RAID1 on $REMOTEHOSTNAME ERROR DISK 2"
    echo "$HEURE - RAID1 on $REMOTEHOSTNAME ERROR DISK 2" >> $LOG 2>&1
    echo "$HEURE - $LINE" >> $LOG 2>&1
    EMAILSUBJECT="$REMOTEHOSTNAME ERROR ERROR ERROR"
    EMAILMESSAGE="One of the two disks (disk 2) seems to be missing in RAID1."
    printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
  fi
done

echo "" >> $LOG 2>&1
HEURE=$(f_date_heure)
echo "$HEURE - iPerf starting $OHC4BACKUPSERVER server"
echo "iPerf starting $OHC4BACKUPSERVER server" >> $LOG 2>&1
ssh -p $OHC4BACKUPPORT -i $SSHKEYID $OHC4BACKUPUSER@$OHC4BACKUPSERVER \
       "iperf -s -p $OHC4BACKUPIPERFPORT" >> $LOG 2>&1 &
sleep 5

HEURE=$(f_date_heure)
echo "$HEURE - iPerf uploading data to $OHC4BACKUPSERVER"
echo "iPerf uploading data to $OHC4BACKUPSERVER" >> $LOG 2>&1
iperf -p $OHC4BACKUPIPERFPORT -c $OHC4BACKUPSERVER -t 12 -i 3 >> $LOG 2>&1

HEURE=$(f_date_heure)
echo "$HEURE - iPerf killing $OHC4BACKUPSERVER server"
echo "iPerf killing $OHC4BACKUPSERVER server" >> $LOG 2>&1
ssh -p $OHC4BACKUPPORT -i $SSHKEYID $OHC4BACKUPUSER@$OHC4BACKUPSERVER "killall -w iperf" >> $LOG 2>&1

# --- if needed, initialize an empty repository, containing future deduplicated data

HEURE=$(f_date_heure)
if ssh -p $OHC4BACKUPPORT -i $SSHKEYID $OHC4BACKUPUSER@$OHC4BACKUPSERVER \
    "[ ! -f $OHC4BACKUPREPOSITORYCHECK ]"
  then
    echo "$HEURE - $LOCALHOSTNAME repository NOT FOUND on $REMOTEHOSTNAME"
    echo "$HEURE - creating missing repository..."

    borg -v init --encryption=keyfile \
    ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY

    EXITSTATUS=$?
    if [ $EXITSTATUS -eq 0 ]
      then
        echo "" >> $LOG 2>&1
        echo "Exit $EXITSTATUS : borg init command was successful" >> $LOG 2>&1
        HEURE=$(f_date_heure)
        echo "$HEURE - $LOCALHOSTNAME borg repository created on $REMOTEHOSTNAME"
        echo ""
        echo "ENCRYPTION KEY IS STORED IN /root/.config/borg/keys"
        echo "MAKE A COPY OF THE KEY FILE AND KEEP IT SAFE"
        echo ""
        echo "ALSO KEEP THE PASSPHRASE SAFE"
        echo ""
        echo "Restart script to begin with backup !"
        echo ""
        EMAILSUBJECT=" $LOCALHOSTNAME borg repository on $REMOTEHOSTNAME"
        EMAILMESSAGE="New borg repository created, URGENT, please backup KEYS!"
        printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
      else
        echo "" >> $LOG 2>&1
        echo "Exit $EXITSTATUS : borg init command failed - error" >> $LOG 2>&1
        HEURE=$(f_date_heure)
        echo "$HEURE - Borg init command failed - exit $EXITSTATUS"
        echo ""
        EMAILSUBJECT=" $LOCALHOSTNAME borg init ERROR on $REMOTEHOSTNAME"
        EMAILMESSAGE="Borg init command failed !"
        printf "$EMAILHEADER1$EMAILSUBJECT$EMAILHEADER2$EMAILMESSAGE" | msmtp $EMAILTO
    fi
    exit 130
  else
    echo "$HEURE - $LOCALHOSTNAME borg repository exists on $REMOTEHOSTNAME"
fi

# --- backup deduplicated data to remote backup server (archive name needs to be unique)

HEURE=$(f_date_heure)
echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1  
echo "$HEURE - borg from" >> $LOG 2>&1
echo "$SOURCE$SLASH to $REMOTEHOSTNAME" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$HEURE - $SOURCE$SLASH to $REMOTEHOSTNAME, using borg ..."

ARCHIVE=$(f_archive_stamp)

borg create -v --list --filter=AME --stats --compression lz4 \
ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY::$ARCHIVE \
$SOURCE >> $LOG 2>&1

EXITSTATUS=$?
if [ $EXITSTATUS -eq 0 ]
  then
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg create command was successful" >> $LOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg create command failed - error" >> $LOG 2>&1
    echo "Borg create command failed - exit $EXITSTATUS"
fi

# --- verifies the consistency of repository

if [ $DAYOFWEEK -eq 7 ]
  then
    HEURE=$(f_date_heure)
    echo "" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1  
    echo "$HEURE - check consistency of repository" >> $LOG 2>&1
    echo "$REMOTEHOSTNAME $OHC4BACKUPREPOSITORY" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "$HEURE - check consistency of repository ..."

    borg -v check \
    ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY \
    >> $LOG 2>&1

    EXITSTATUS=$?
    if [ $EXITSTATUS -eq 0 ]
      then
        echo "" >> $LOG 2>&1
        echo "Exit $EXITSTATUS : borg check command was successful" >> $LOG 2>&1
      else
        echo "" >> $LOG 2>&1
        echo "Exit $EXITSTATUS : borg check command failed - error" >> $LOG 2>&1
        echo "Borg check command failed - exit $EXITSTATUS"
    fi
  else
    echo "" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "$HEURE - consistency check only on day 7 (today = $DAYOFWEEK)" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "nothing to do today" >> $LOG 2>&1
    echo "$HEURE - consistency check not today"
fi

# --- list content of repository, before prune

HEURE=$(f_date_heure)
echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1  
echo "$HEURE - list of archives before borg prune command" >> $LOG 2>&1
echo "$REMOTEHOSTNAME $OHC4BACKUPREPOSITORY" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$HEURE - actual archives list"

borg list \
ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY \
>> $LOG 2>&1

EXITSTATUS=$?
if [ $EXITSTATUS -eq 0 ]
  then
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg list command was successful" >> $LOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg list command failed - error" >> $LOG 2>&1
    echo "Borg list command failed - exit $EXITSTATUS"
fi

# --- deleting all archives not matching specified retention options

HEURE=$(f_date_heure)
echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1  
echo "$HEURE - delete obsolete archives in repository" >> $LOG 2>&1
echo "$REMOTEHOSTNAME $OHC4BACKUPREPOSITORY" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$HEURE - delete obsolete archives"

borg prune -v --list \
--keep-within=2d --keep-daily=7 --keep-weekly=5 --keep-monthly=-1 \
ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY \
>> $LOG 2>&1

EXITSTATUS=$?
if [ $EXITSTATUS -eq 0 ]
  then
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg prune command was successful" >> $LOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg prune command failed - error" >> $LOG 2>&1
    echo "Borg prune command failed - exit $EXITSTATUS"
fi

# --- list content of repository, after prune

HEURE=$(f_date_heure)
echo "" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1  
echo "$HEURE - list of archives after borg prune command" >> $LOG 2>&1
echo "$REMOTEHOSTNAME $OHC4BACKUPREPOSITORY" >> $LOG 2>&1
echo "------------------------------------------------------------" >> $LOG 2>&1
echo "$HEURE - newest archives list"

borg list \
ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY \
>> $LOG 2>&1

EXITSTATUS=$?
if [ $EXITSTATUS -eq 0 ]
  then
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg list command was successful" >> $LOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg list command failed - error" >> $LOG 2>&1
    echo "Borg list command failed - exit $EXITSTATUS"
fi

# --- snapshot actual state on client side

HEURE=$(f_date_heure)
if [ ! "$SNAPSHOTALLREADYDONE" ] 
  then
    echo "" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1  
    echo "$HEURE - $LOCALHOSTNAME snapshot" >> $LOG 2>&1
    echo "$SOURCE$SLASH to" >> $LOG 2>&1
    echo "$SNAPSHOTS$TODAY$SLASH" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "$HEURE - snapshot, on $LOCALHOSTNAME"  
    cp -al $SOURCE$SLASH $SNAPSHOTS$TODAY$SLASH >> $LOG 2>&1  
    ls -la -R $SNAPSHOTS$TODAY$SLASH >> $SNAPSHOTLOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "$HEURE - snapshot already done" >> $LOG 2>&1
    echo "------------------------------------------------------------" >> $LOG 2>&1
    echo "nothing to do right now" >> $LOG 2>&1
    echo "$HEURE - snapshot already done"
fi

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

f_unset_env

HEURE=$(f_date_heure)
echo "$HEURE - backup ended"
exit 0