#!/usr/bin/env bash
set -e  # halt on first error

get_file_size() {
	CURFILESIZE=$(perl -e '@x=stat(shift);print $x[7]' $1)
}

get_file_duration() {
	TEST=$1
	FILETIME=$(echo "$1 / 50000000" | bc)
	FILEHOURS=$(echo "$FILETIME / 3600" | bc)
	FILEMINUTES=$(echo "$FILETIME % 3600 / 60" | bc)
	FILESECONDS=$(echo "$FILETIME % 60" | bc)
	FILEDURATION="${FILEHOURS}h ${FILEMINUTES}m ${FILESECONDS}s"
}
start_timer() {
	BEFORE=$(date +%s)
}

end_timer() {
	AFTER=$(date +%s)
	INTERVAL=$(echo "$AFTER - $BEFORE" | bc)
	HOURS=$(echo "$INTERVAL / 3600" | bc)
	MINUTES=$(echo "$INTERVAL % 3600 / 60" | bc)
	SECONDS=$(echo "$INTERVAL % 60" | bc)
	TIMERDURATION="${HOURS}h ${MINUTES}m ${SECONDS}s"
}


if [[ ($# -eq 1 || ($# -eq 2 && $2 == "-o")) ]] ; then
	: # we're good
else
	echo "==========================================="
	echo " Laserdisc RF compression test"
	echo " Verifies .lds -> .flac -> .lds conversion"
	echo "===========================================" 
	echo "Usage:  flactest infile.lds [-o]"
	echo "          -o overwrite infile.raw.flac and infile.copy.lds if present"
	echo
	exit
fi

if [[ $(command -v flac) == "" ]] ; then
	echo "Error: requires flac, but it was not found."
	exit 1
fi
if [[ $(command -v dddconv) == "" ]] ; then
	echo "Error: requires dddconv, but it was not found"
	echo "       see https://github.com/simoninns/DomesdayDuplicator/"
	exit 1
fi



INFILE=$1
FLACFILE=${INFILE%.*}.raw.flac
OUTFILE=${INFILE%.*}.copy.lds

if [[ ($# -eq 2 && $2 == "-o" ) ]] ; then  # overwrite files
	if [[ -e $FLACFILE ]] ; then
		rm $FLACFILE
	fi
	if [[ -e $OUTFILE ]] ; then
		rm $OUTFILE
	fi
fi

get_file_size $INFILE
INFILESIZE=$CURFILESIZE
INFILESIZEPRT=$(printf "%'d" $INFILESIZE)
get_file_duration $INFILESIZE
INFILEDURATION=$FILEDURATION
echo
echo "Source file:"
echo "  Name:     $INFILE"
echo "  Size:     $INFILESIZEPRT bytes"
echo "  Duration: $INFILEDURATION"
echo -n "  MD5:      "
INMD5=($(md5sum $INFILE))
echo $INMD5
echo 

echo "Compressing to $FLACFILE..."
start_timer
dddconv --unpack -i $INFILE | flac -s --sample-rate=48000 --sign=signed --channels=1 --endian=little --bps=16 --compression-level-8 - --output-name=$FLACFILE
end_timer
FLACSPEED=$(echo "scale=2; $FILETIME / $INTERVAL" | bc | xargs printf "%.2f")
echo "  finished in $TIMERDURATION (${FLACSPEED}x realtime)"

get_file_size $FLACFILE
FLACFILESIZE=$CURFILESIZE
FLACFILESIZEPRT=$(printf "%'d" $FLACFILESIZE)
FLACPCT=$(echo "scale=2; $FLACFILESIZE / $INFILESIZE * 100" | bc)
echo "  Size:     $FLACFILESIZEPRT bytes ($FLACPCT% of source file size)"

echo
echo "Decompressing from $FLACFILE..."
start_timer
flac -d -s $FLACFILE --force-raw-format --endian=little --sign=signed --output-name=- | dddconv --pack -o $OUTFILE
end_timer
FLACSPEED=$(echo "scale=2; $FILETIME / $INTERVAL" | bc | xargs printf "%.2f")
echo "  finished in $TIMERDURATION (${FLACSPEED}x realtime)"

get_file_size $OUTFILE
OUTFILESIZE=$CURFILESIZE
OUTFILESIZEPRT=$(printf "%'d" $OUTFILESIZE)
get_file_duration $OUTFILESIZE
OUTFILEDURATION=$FILEDURATION
echo
echo "Destination file:"
echo "  Name:     $OUTFILE"
echo "  Size:     $OUTFILESIZEPRT bytes"
echo "  Duration: $INFILEDURATION"
echo -n "  MD5:      "
OUTMD5=($(md5sum $OUTFILE))
echo $OUTMD5

echo
if [[ $OUTMD5 == $INMD5 ]] ; then
   echo "Test succeeded; source and destination files match"
else 
   echo "Test failed; source and destination files do NOT match"
   exit 1
fi
