#!/bin/bash

# on client side (computer where you want to restore files)
#   - this script must belong to root and be executable
#   - the borg software must have been installed (apt install borgbackup)
#   - the borg backup crypto key must exists in /root/.config/borg/keys
#   - the file /root/.borg.passphrase must exist and contain the variable
#     BORG_PASSPHRASE="...", with valid borg passphrase (chmod u=rx,g=,u=)
#   - msmtp must have been installed (apt install msmtp) and configuration
#     for sending mails must be active in /etc/msmtprc - msmtprc must be
#     owned by root:root and rights be chmod u=rx,g=,u=
#   - ssh host keys must have been exchanged beforehand between machines
#     (initial use in console mode allows exchange)
#   - to maintain stability of the SSH connection, add in etc/ssh/ssh_config
#     ServerAliveInterval 300 and ServerAliveCountMax 30

# on server side (remote backup server where files are)  
#   - ssh public key used by this script must have been added to
#     /root/.ssh/authorized_keys
#   - to maintain stability of the SSH connection, add in etc/ssh/sshd_config
#     ClientAliveInterval 30 et ClientAliveCountMax 5

##### insert your own parameters in the lines ending with : # EDIT

# --- identity

SCRIPTNAME=$0
SCRIPTVERSION="1.0 rev. 065"
AUTHOR="..." # EDIT
EMAILTO="...@gmail.com" # EDIT
LOCALHOSTNAME=$(hostname)
echo ""
echo "$SCRIPTNAME version $SCRIPTVERSION"

# --- help fonctions
  
f_date_heure()
  {
  date "+%Y/%m/%d %H:%M:%S"
  }
  
f_date_stamp()
  {
  date "+%s"
  }
  
f_unset_env()
  {
  unset BORG_RSH
  unset BORG_PASSPHRASE
  } # remove borg environment variables
  
# --- variables, instance check, RAID1 health and needed files 

START=$(f_date_heure)
STARTSTAMP=$(f_date_stamp)
LOG="oHC4extract.log"
HISTORY="oHC4extracthistory.log"
SUJETOK="Extract OK"
SUJETKO="$LOCALHOSTNAME extract ERROR ERROR ERROR"
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

echo "" >> $LOG 2>&1
echo "---------------------------------------------------------------" >> $LOG 2>&1
echo "$START - $SCRIPTNAME version $SCRIPTVERSION" >> $LOG 2>&1
echo "---------------------------------------------------------------" >> $LOG 2>&1
echo "" >> $LOG 2>&1

# --- SSH key to use & exporting borg passphrase

SSHKEYID="/root/.ssh/ssh_oC4_root_ed25519_key" # EDIT

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
export BORG_RSH # export $BORG_RSH out of script, in child processes

. /root/.borg.passphrase # publish $BORG_PASSPHRASE variable
export BORG_PASSPHRASE # export $BORG_PASSPHRASE out of script, in child processes

# --- test connection to remote backup server & get remote hostname

OHC4BACKUPUSER="root" # EDIT
OHC4BACKUPSERVER="10.0.10.236" # EDIT
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

# --- decide what to do

echo ""
echo "SCRIPT ALLWAYS WRITES EXTRACTED DATA INTO THE CURRENT WORKING DIRECTORY"
echo "MAKE SURE YOU CD THE RIGHT PLACE BEFORE STARTING RESTORE PROCESS"
echo ""
echo "Current working directory is :" $(pwd)
echo ""
echo "Menu"
echo "1) I want to change working directory, please let me exit !"
echo "2) List all existing archives in repository, I need the names !"
echo "3) I want to extract the content of an archive, I know its name."
echo ""
read -p "What do you want to do now (1, 2 or 3) ? " CHOICE
case $CHOICE in

  1) f_unset_env
     exit 130
     ;;
  2) borg list \
     ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY
     echo ""
     echo "Remember archive name and restart script."
     echo ""
     f_unset_env
     exit 130
     ;;
  3) read -p "Enter ARCHIVE name: " ARCHIVE2EXTRACT
     echo ""
     echo "By default the entire archive is extracted. A subset of files and"
     echo "directories can be selected by passing a list of PATHs as arguments."
     echo "Example entire archive     : [type just ENTER]"
     echo "Example directory structure: files/data/documentation"
     echo "Example with single file   : files/data/videos/gag/fun_chat_robinet.mp4"
     echo ""
     read -p "Enter PATH: " PATH2EXTRACT
     echo ""
     ;;
  *) echo ""
     echo "Sorry, no valid input (1, 2 or 3). Please retry - restart script."
     echo ""
     f_unset_env
     exit 130
     ;;
  
esac

# --- list content of a repository

echo "Listing repository..."
echo "Repository content" >> $LOG 2>&1
borg list \
     ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY >> $LOG 2>&1
echo "" >> $LOG 2>&1

EXITSTATUS=$?
if [ $EXITSTATUS -eq 0 ]
  then
    echo "Exit $EXITSTATUS : borg list command was successful" >> $LOG 2>&1
  else
    echo "Exit $EXITSTATUS : borg list command failed - error" >> $LOG 2>&1
    echo "Borg list command failed - exit $EXITSTATUS"
fi

# --- restore files (by default the entire archive is extracted)

echo "Extracting selected files..."
echo ""
echo "" >> $LOG 2>&1
echo "Extraction" >> $LOG 2>&1
echo "" >> $LOG 2>&1
echo "Archive selected: $ARCHIVE2EXTRACT" >> $LOG 2>&1
echo "Directory selected: $PATH2EXTRACT" >> $LOG 2>&1
echo "" >> $LOG 2>&1
borg extract --list \
ssh://$OHC4BACKUPUSER@$OHC4BACKUPSERVER:$OHC4BACKUPPORT$OHC4BACKUPREPOSITORY::$ARCHIVE2EXTRACT \
$PATH2EXTRACT >> $LOG 2>&1

EXITSTATUS=$?
if [ $EXITSTATUS -eq 0 ]
  then
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg extract command was successful" >> $LOG 2>&1
  else
    echo "" >> $LOG 2>&1
    echo "Exit $EXITSTATUS : borg extract command failed - error" >> $LOG 2>&1
    echo "Borg extract command failed - exit $EXITSTATUS"
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

echo "$HEURE - waiting 3 seconds..."
sleep 3
cat $LOG >> $HISTORY

# --- end

f_unset_env

HEURE=$(f_date_heure)
echo "$HEURE - backup ended"

exit 0