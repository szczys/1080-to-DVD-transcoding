#!/bin/sh

### 1080-t-dvd.sh by Mike Szczys - mike a t nospam jumptuck deleteme dot youknowcom
###	
###	jumptuck.com
###
### Last modified: 20100202
###
### Usage: /PATH/TO/removecommercials %DIR% %FILE% %CHANID% %STARTTIME%
###		Add the line above as a user job in mythtv
###
### This script was build off of a mythtv script:
### http://www.mythtv.org/wiki/Talk:Script_-_RemoveCommercials
### removecommercials - for mythtv user job.
### $author Zack White - zwhite dash mythtv a t nospam darkstar deleteme frop dot org
### $Modified 20080330 Richard Hendershot - rshendershot a t nospam gmail deleteme dot youknowcom

#   initialize;  all except SKIP are required for this to function correctly
VIDEODIR=$1
FILENAME=$2
CHANID=$3
STARTTIME=`echo $4 | sed -e 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3-\4-\5-\6/'`

if [ -z "${VIDEODIR}" -o -z "${FILENAME}" -o -z "${CHANID}" -o -z "${STARTTIME}" ]; then
        echo "Usage: $0 <VideoDirectory> <FileName> <ChannelID> <StartTime>  [SKIP]"
        exit 5
fi
if [ ! -f "${VIDEODIR}/${FILENAME}" ]; then
        echo "File does not exist: ${VIDEODIR}/${FILENAME}"
        exit 6
fi
if [ ! -d "${VIDEODIR}" ]; then 
        echo "<VideoDirectory> must be a directory"
        exit 7
fi
if [ ! -d "${VIDEODIR}/originals" ]; then 
        cd "${VIDEODIR}"
        mkdir originals
fi
if [ ! -d "${VIDEODIR}/originals" ]; then 
        echo "you must have write access to <VideoDirectory>"
        exit 8
fi

#   Transcode to DVD quality using FFMPEG
echo "FFMPEG: Transcoding ${FILENAME} down to DVD quality" 
ffmpeg -i "${VIDEODIR}/${FILENAME}" -y -target ntsc-dvd -aspect 16:9 -ac 2 -async 24 -sameq -copyts "${VIDEODIR}/${FILENAME}.mpeg"
ERROR=$?
if [ $ERROR -ne 0 ]; then
        echo "FFMPEG: Transcoding failed for ${FILENAME} with error $ERROR"
        exit $ERROR
else
        echo "FFMPEG: Transcoding successful for ${FILENAME}"
fi

#   moving original file as a backup
echo "Moving ${VIDEODIR}/${FILENAME}  to  ${VIDEODIR}/originals/${FILENAME}"
mv "${VIDEODIR}/${FILENAME}" "${VIDEODIR}/originals"
ERROR=$?
if [ $ERROR -ne 0 ]; then
        echo "file: Moving failed with error $ERROR"
        exit $ERROR
else
        echo "file: Moving successful"
fi

#    move the transcoded file to the original filename
echo "Moving ${VIDEODIR}/${FILENAME}.mpeg  to  ${VIDEODIR}/${FILENAME}"
if [ ! -f "${VIDEODIR}/${FILENAME}" ]; then
        mv "${VIDEODIR}/${FILENAME}.mpeg" "${VIDEODIR}/${FILENAME}"
        ERROR=$?
        if [ $ERROR -ne 0 ]; then
                echo "file: Moving failed with error $ERROR"
                exit $ERROR
        else
                echo "file: Moving successful"
        fi
else
        echo "file: cannot replace original.  skipping file move. (${VIDEODIR}/${FILENAME})"
fi

#echo "file: removing map file: ${VIDEODIR}/${FILENAME}.mpeg.map"
#if [ -f "${VIDEODIR}/${FILENAME}.mpeg.map" ]; then
#        rm "${VIDEODIR}/${FILENAME}.mpeg.map"
#        ERROR=$?
#        if [ $ERROR -ne 0 ]; then
#                echo "file: unable to remove map file: ${VIDEODIR}/${FILENAME}.mpeg.map"
#        else
#                echo "file:  removed map file successfully"
#        fi
#fi    

#   file has changed, rebuild index
mythcommflag -c ${CHANID} -s ${STARTTIME} --quiet --rebuild
ERROR=$?
if [ $ERROR -ne 0 ]; then
        echo "mythcommflag: Rebuilding seek list failed for ${FILENAME} with error $ERROR"
        exit $ERROR
else
        echo "mythcommflag: Rebuilding seek list successful for ${FILENAME}"
fi

mythcommflag -c ${CHANID} -s ${STARTTIME} --quiet --clearcutlist
ERROR=$?
if [ $ERROR -eq 0 ]; then
        echo "mythcommflag: Clearing cutlist successful for ${FILENAME}"
        
        # Fix the database entry for the file
        cat << EOF | mysql -u mythtv -pmythtv mythconverg
UPDATE 
        recorded
SET
        cutlist = 0,
        filesize = $(ls -l ${VIDEODIR}/${FILENAME} | awk '{print $5}') 
WHERE
        basename = '${FILENAME}';
EOF
        exit 0
else
        echo "mythcommflag: Clearing cutlist failed for ${FILENAME} with error $ERROR"
        exit $ERROR
fi

