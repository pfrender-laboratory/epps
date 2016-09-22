#!/bin/bash

WAIT () {
  # Description:
  # This takes a qstat job (as $1) and sleeps until its finished
  if [[ $( qstat -j $1) =~ "job_number" ]]
    then
      sleep 5;
      WAIT $1
  fi
}


#!/bin/bash

HELP() {
  # Description:
  # Outputs flag info then exits

  echo -e "Welcome to the Meta Pipeine Script, the safe way to run the eDNA pipeline, running is as simple as:\n
\t\tsh eDNA_Meta_Pipeline_Script.sh -l log_or_output_file -p /path/to/primer.fas -r /path/to/raw/directory -w /path/to/work/dir\n
\t-h displays the help file and exits (what this is)
\t-V is the Version, it will print the version and exit
\t-f is \"force\" it can be used if you'd like to run everything in the background
\t-l is the log file, it is required if you are in force mode
\t-p is the primers file (what primers were used), it is required
\t-r is the raw data directory (where the .fastq.gz files are), it is required
\t-w is the work directory (everything will be done in here), it is required
" >&2;
  exit 1;
}

VERSION() {
  # Description:
  # Outputs version then exits 

  echo "VERSION=0.1" >&2;
  exit 1;
}

MSG() {
  # Description:
  # Outputs the log formated message, either to std out or to the log

  [ -t 1 ] && echo "[ $(date) ]: $1" >&2;
  [ ! -z "$LOG" ] && echo "[ $(date) ]: $1" >> "$LOG"
}

CONTINUE() {
  # Description:
  # Propmts the user for yes or no, then either coninues the program or exits the program

  if [ -z "$FORCE" ]; then
    echo "$1" >&2;
    read cont
    case "$cont" in
      Y|y|yes|Yes|YES )
      ;;
      N|n|no|No|NO )
        MSG "NO ENTERED, exiting"; exit 1;
      ;;
      *) 
        MSG "Invalid input You entered: $cont" >&2;
	    CONTINUE
      ;;
    esac
  fi
}

# - - - - - - - - - - - #
# Start of main program #
# - - - - - - - - - - - #

while getopts ":hVfl:p:r:w:" opt; do
 case "${opt}" in
  h)
    HELP; 
  ;;
  V)
    VERSION;
  ;;
  f)
    FORCE="on";
  ;;
  l)
    LOG=${OPTARG};
  ;;
  p)
    PRIMERS=${OPTARG};
  ;;
  r)
    RAW_DATA_DIRECTORY=${OPTARG};
  ;;
  w)
    WORK_DIR=${OPTARG};
  ;;
 esac
done


#check logging and interactive mode requirements
[ ! -z "$force" ] && MSG "Script running in force mode, this is not recomended";
[ -z "$LOG" ] && { MSG "Script running in non-interactive shell without Logging, exiting"; exit 1; }

#check that primers and raw data direcoty are things
[ ! -f "$PRIMERS" ] && { MSG "Script can not find primers file, exiting."; exit 1; }
[ "$(ls -A $RAW_DATA_DIRECTORY)" ] || { MSG "Script can not find raw data directory or direcotry is empty, exiting."; exit 1; }

MSG "LOG set to: $LOG, PRIMER FILE set to:$PRIMERS, RAW DATA DIRECTORY set to $RAW_DATA_DIRECTORY, and WORK DIRECTORY set to: $WORK_DIR"
CONTINUE "Continue with current configuration?"

#Prep for runs
mkdir $WORK_DIR || MSG "could not create work directory, perhaps it already exists"
mkdir $WORK_DIR/raw_data || MSG "could not create raw data directory, perhaps it already exists"
mkdir $WORK_DIR/work_space || MSG "could not create work space direcoty, perhaps it already exists"
mkdir $WORK_DIR/work_space/Samples || "could not create Samples dir, perhaps it already exists"
for f in "$RAW_DATA_DIRECTORY/*"; do ln -s $f $WORK_DIR/raw_data; done
FQ_LIST="$(find $WORK_DIR/raw_data -iname '*.fastq.gz')"
PRIMERS_LOC="$WORK_DIR/work_space/primer.fas"

#Move primers, create fq list file
cp $PRIMERS $WORK_DIR/work_space/primer.fas || { MSG "could not move primers, exiting."; exit 1; }
printf $FQ_LIST >> $WORK_DIR/work_space/fq.list || { MSG "could not create fq list, exiting."; exit 1; }

MSG "primers are now:$( cat $WORK_DIR/work_space/primer.fas )"
MSG "list of fastq files is now:\n$( cat $WORK_DIR/work_space/fq.list )"

CONTINUE "Continue with current fastq files and current primers?"

#Run eDNA_pipeline script
MSG "Running eDNA_pipeline.pl script"
MSG "$( perl eDNA_pipeline.pl -l $WORK_DIR/work_space/fq.list -o $WORK_DIR/work_space -dm Y -pm $WORK_DIR/work_space/primer.fas -p NA )" 

CONTINUE "Continue with qsub submissions?"

#qsub other scripts
MSG "moving to samples folder"
cd $WORK_DIR/work_space/Samples/
MSG "now in the $( pwd ) folder"
MSG "qsubing batch_filter"
WAIT "$( qsub batch_filter.sh | grep -oP '\d+' | head -n 1 )"

MSG "qsubing other filters"
for f in $( ls batch_* | grep -v "filter" ); do WAIT "$( qsub $f | grep -oP '\d+' | head -n 1 )";  done 

MSG "moving back to work directory"
cd ..
MSG "now in the $( pwd ) directory"

MSG "qsubing the primers"
for f in $( ls All_* ); do WAIT "$( qsub $f | grep -oP '\d+' | head -n 1 )"; done
