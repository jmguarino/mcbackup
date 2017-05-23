#!/bin/bash
# Minecraft backup script
# Justin Guarino

INSTALLDIR="/opt/minecraft" 
WORLDNAME="minecraft" 
BACKUPDIR="backups"
SERVERDIR="server"
BACKUPLOG="backups/backup.log"

DAY=$(date +%a)

cd $INSTALLDIR

#Stop the minecraft service if running
if [ "`systemctl is-active minecraft.service`" == "active" ]
then
	systemctl stop minecraft.service
fi

#Back up world directory
if [ -e $BACKUPDIR/$WORLDNAME.$DAY.tgz ]
then
	mv $BACKUPDIR/$WORLDNAME.$DAY.tgz $BACKUPDIR/$WORLDNAME.$DAY.tgz.backup
fi

tar cfz $BACKUPDIR/$WORLDNAME.$DAY.tgz $SERVERDIR/$WORLDNAME
       
if [ -e $BACKUPDIR/$WORLDNAME.$DAY.tgz ]
then
	echo -e "Backup completed-$(date)" >> $BACKUPLOG
        rm -f $BACKUPDIR/$WORLDNAME.$DAY.tgz.backup
else
        echo -e "Backup FAILED-$(date)" >> $BACKUPLOG
fi

#Remove log files older than 2 weeks
find /opt/minecraft/server/logs/*.gz -maxdepth 1 -mtime 14 -exec rm {} \;

#Run update script which should take care of updating the jar and deleting old ones.
#It should also restart the server jar if an update is done.
/opt/minecraft/cron/minecraft_update.pl

#Start server if it isn't already running (most of the time unless there was an update)
if [ "`systemctl is-active minecraft.service`" != "active" ]
then
        systemctl start minecraft.service
fi
