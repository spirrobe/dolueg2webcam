#!/bin/bash

#GENERAL DIRECTORY STRUCTURE
TMPDIR=/home/pi/webcam
WEBDAV=ENTERYOURWEBDAV

# CREDENTIALS TO STORE THINGS LATER
FTPUSER=ENTERYOURUSERHERE
FTPPASSWORD=ENTERYOURPASSWORDHERE
FTPSERVER=ENTERYOURFRPSERVER

# SET THESE TO DECIDE PICTUREWIDTH AND HEIGHT
picwidth=1600
picheight=1200

# PERCENTAGE OF BOTTOMBOX, EVERYTHING ELSE IS ADJUSTED TO THIS
bottompercentage=3

# REMOVE ALL OLD PICTURE IN CASE SOMETHING WENT WRONG BEFORE, THAT IS SPACE BELOW < 1G
space=$(df -hl --output=avail /)
space=(${space[0]})
space=${space[1]}

if [[ $space == *[G]* ]];
then

  wput -q -m 770 -T 10 -t 3 -R --waitretry=1 $TMPDIR/*.jpg ftp://$FTPUSER:$FTPPASSWORD@$FTPSERVER/ 2> /dev/null
  #echo 'Nothing to remove, still enough space'

else

  wput -q -m 770 -T 10 -t 3 -R --waitretry=1 $TMPDIR/*.jpg ftp://$FTPUSER:$FTPPASSWORD@$FTPSERVER/ 2> /dev/null
  rm $TMPDUIR/*.jpg 2> /dev/null
  hostname=$(hostname)
  space=$(df -hl)
  echo -e "FROM: root\nTO: pi\nSubject: Space on $hostname running low\n\nHello operator\n\nBe advised, that all jpegs of webcam have been removed since your space was running low on $hostname:\n\n$space\n\nBest regards\n$hostname" | sendmail -t

fi;

# CALCULATE THE BOTTOM TEXT BOX HEIGHT IN PIXELS
bottomtextboxsize=$(expr $picheight \* $bottompercentage / 100)

# CAPTURING RUNTIME
t0=$(date +%s)

# CALCULATE TEXT SIZE AND OTHER RELATED THINGS
textsize=$(expr $bottomtextboxsize - $bottomtextboxsize / 4)
textbaseline=$(expr $bottomtextboxsize / 4)
picheightreduced=$(expr $picheight - $bottomtextboxsize)

# DATEFORMAT FOR FILENAME
nd=$(date +"%Y%m%d%H%M%S")

# DATEFORMAT FOR PICTURETEXT
nd2=$(date +"%H:%M %d-%m-%Y %Z")

# DATEFORMAT IN CASE NO SQL RESULTS
nd3=$(date +"%H:%M %d-%m-%Y")

# DB OFFSET FOR MOST RECENT VALUES
minoffset=30

# ECHO FOR LOGGING
echo "Making foto at: $nd2"

# ALL SQL NONSENSE HAS TO END WITH A WHITESPACE
TIME="select date_format(convert_tz(timestamp(t1.date,t1.time),'+01:00','+00:00'),'%d-%m-%Y %H:%i'),"
WHAT="round(t1.value,1),round(t2.value,1),round(t3.value,0),round(t4.value,1) " 

# TABLES WE WANT
FROMTABLE="FROM messnetzdb.bklidta7 as t1 "
# ADJUST FOR RHINE TEMPERATURE�WHOSE TIMEZONE IS UTC+2
FROMTABLE+="JOIN messnetzdb.B2091WT0 as t2 ON t1.date=t2.date AND t1.time=(t2.time + INTERVAL 60 MINUTE) "
#	FROMTABLE+="JOIN messnetzdb.B2613WT0 as t2 ON t1.date=t2.date AND t1.time=(t2.time + INTERVAL 60 MINUTE) "
#	FROMTABLE+="JOIN messnetzdb.B2613WT0 as t2 ON t1.date=t2.date AND t1.time=t2.time "
FROMTABLE+="JOIN messnetzdb.bklirha7 as t3 ON t1.date=t3.date AND t1.time=t3.time "
FROMTABLE+="JOIN messnetzdb.bklisda1 as t4 ON t1.date=t4.date AND t1.time=t4.time "

# CONDITION
WHERE="where timestamp(t1.date,t1.time) >= ('$(date +'%Y-%m-%d %H:%M:%S')' - interval $minoffset minute) "

# ORDER SO WE GET THE MOST RECENT ON TOP; AND LIMIT TO 1 SO WE ONLY TAKE THAT ONE
ORDER="order by timestamp(t1.date,t1.time) desc limit 1;"

# CREATE FINAL QUERY
QUERY="$TIME$WHAT$FROMTABLE$WHERE$ORDER"

# FOR DEBUGGING OF SQL UNCOMMENT THIS
#echo $QUERY

# RUN QUERY AND GET RESULT
sqlout=$(mysql -ss -h met-server3 -e "$QUERY")

#MAKE AN ARRAY OUT OF IT
sqlarr=($sqlout)

# CALCULATE WHERE THE MEASUREMENT VALUES TEXT BOX IS GOING TO
aline=$(expr $textsize + $textbaseline)

# X COORDINATES
toptextrightx=$(expr $picwidth - $textsize )
toptextleftx=$(expr $picwidth - $textsize \* 12 )

if [ ${#sqlarr[@]} -ne 0 ]; then
	nlines=${#sqlarr[@]}
else
	nlines=6
fi;

# Y COORDINATES
toptextlefty=$(expr $textsize / 2)
toptextrighty=$(expr $nlines \* $aline + $aline / 2)

# LINEPOSITIONS OF SQL QUERY
toptextdist=$(expr $textsize \* 3 / 2)
lineypos=$(expr $toptextlefty + 2 \* $aline + 3)

# FILL LINEPOSITIONS INTO AN ARRAY
lp=()
END=$nlines
for ((i=1;i<=END;i++)); do
	lp+=( $(expr $aline \* $i + $textbaseline) )
done

# MEASURE TEMPERATURE
tmp=$(vcgencmd measure_temp)
str="${sqlarr[5]}"

# ADJUST SOLAR RADIATION
if [[ $str == *[-]* ]]; then
	sqlarr[5]="0.0"
fi

# get pysolar elevation output
# sunelevation.py subtstracts 1 degree from the real sunelevation to account for dawn
cmd="python3 $TMPDIR/sunelevation.py"

# run command which outputs result to stdout
sunelevation="$($cmd)"

#TAKE THE FOTO
if [[ $sunelevation == *[-]* ]]; then

	# ITS NIGHTTIME BABY, ADJUST EXPOSURE
	# SHUTTER SPEED GETS ADJUSTED AND WE USE EXPOSURE night 
        raspistill -vf -hf -n -o $TMPDIR/shot$nd.jpg -e jpg -ex night -w $picwidth -h $picheight -awb auto -mm matrix -q 100 -drc high -ss 1900000 #-ISO 800 -ss 1900000
else
	# ITS DAYTIME BABY, TAKE A NORMAL EXPOSURE FOTO
	raspistill -vf -hf -n -o $TMPDIR/shot$nd.jpg -t 5000 -e jpg -ex auto -w $picwidth -h $picheight -awb auto -mm matrix -q 100 -drc high
fi

# ADD SOME BLACK SPACE ON THE BOTTOM FOR TEXT
gm convert $TMPDIR/shot$nd.jpg -fill black -draw "rectangle 0,$picheightreduced $picwidth,$picheight" $TMPDIR/shot$nd.jpg

# ADD BLACK LINE, THEN THE BLUE TEXT ON THE BOTTOM AND DRAW THE RECTANGLE FOR MEASUREMENT VALUES
gm convert $TMPDIR/shot$nd.jpg \
  -gravity SouthEast -pointsize $textsize -fill '#009ACD' -draw "text 10,$textbaseline \"Webcam @ $nd2\"" \
  -gravity South -pointsize $textsize -fill '#009ACD' -draw "text 0,$textbaseline 'MCR - University of Basel'" \
  -gravity SouthWest -pointsize $textsize -fill '#009ACD' -draw "text 10,$textbaseline 'meteo.duw.unibas.ch'" \
  -fill "#FFFFFF7c"  -draw "rectangle $toptextleftx,$toptextlefty $toptextrightx,$toptextrighty" \
  -fill white -stroke black -draw "line $toptextleftx,$lineypos $toptextrightx,$lineypos"  \
  $TMPDIR/shot$nd.jpg


if [ ${#sqlarr[@]} -ne 0 ]; then
	# IF THERE ARE MEASUREMENT VALUES WRITE THEM 
	gm convert $TMPDIR/shot$nd.jpg \
	  -gravity Northeast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[0]} 'Values UTC'" \
	  -gravity Northeast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[1]}  \"${sqlarr[1]} ${sqlarr[0]}\"" \
	  -gravity Northeast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[2]}  \"${sqlarr[2]} °C Temp.\"" \
	  -gravity NorthEast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[3]}  \"${sqlarr[3]} °C Rhine \"" \
	  -gravity NorthEast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[4]}  \"${sqlarr[4]} % Rel. Hum.\"" \
	  -gravity NorthEast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[5]} \"${sqlarr[5]} W/m² SRad.\"" \
	  $TMPDIR/shot$nd.jpg
else

	# IF NOT WRITE NA
	gm convert $TMPDIR/shot$nd.jpg \
	  -gravity Northeast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[0]} 'Values UTC'" \
	  -gravity Northeast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[1]}  \"  $nd3\"" \
	  -gravity Northeast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[2]}  \"  NA °C Temp.\"" \
	  -gravity NorthEast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[3]}  \"  NA °C Rhine \"" \
	  -gravity NorthEast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[4]}  \"  NA % Rel. Hum.\"" \
	  -gravity NorthEast -pointsize $textsize -fill '#000000' -draw "text $toptextdist,${lp[5]} \"  NA W/m² SRad.\"" \
	  $TMPDIR/shot$nd.jpg

fi;

# RENAME PICTURE
cp $TMPDIR/shot$nd.jpg $TMPDIR/current.jpg 2> /dev/null

# UPLOAD FILE TO WEBDAV, CREDENTIALS IN ~/.netrc
curl --anyauth --netrc-file "$TMPDIR/.netrc" -T $TMPDIR/current.jpg $WEBDAV

# PUT ON FTP FOR LATER USE IN TIMELAPSE
# REMOVE PICTURE TO SDCARD DOESNT FILL UP
wput -q -m 770 -T 10 -t 3 -R --waitretry=1 $TMPDIR/shot$nd.jpg ftp://$FTPUSER:$FTPPASSWORD@$FTPSERVER/shot$nd.jpg 2> /dev/null

t1=$(date +%s)
runtime=$(($t1-$t0))

# FOR LOGGING TO SEE HOW MUCH TIME WAS USED
echo "It tooks $runtime seconds to finish"

