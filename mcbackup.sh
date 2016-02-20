#!/bin/bash
# Minecraft backup script designed to run on a nightly cron
# The assumed environment is a recent Red Hat release with a
# Systemd Unit to start/stop the server
# Justin Guarino

INSTALLDIR="/opt/minecraft"
WORLDNAME="survival"
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

#Remove log files older than 2 weeks (specific to my needs, omit or edit as needed)
find /opt/minecraft/server/logs/*.gz -maxdepth 1 -mtime 14 -exec rm {} \;

#Start server
systemctl start minecraft.service


