#!/bin/bash

# NGSCheckmate-- AUTOMATIC RUN DETECTION AND PIPELINE LAUNCH
########################################################

### TODO determine inputs
if [ "$#" != 2 ]
then
    echo "Error incorrect number of command line arguments."
    echo "Usage: $(basename $0) <readset_file_dir> <analysis_dir>"
    exit
fi

#01 0 * * 1,3,5 source $HOME/.bash_profile; bash -l /lb/robot/research/DOvEE/automation/scripts/auto_DOvEE_vardict.sh /lb/robot/research/DOvEE/automation/latest_readsets /lb/robot/research/DOvEE/processing > /lb/robot/research/DOvEE/automation/logs/cron_vardict.log 2>&1
########################################################
# Set file paths
OUTPUT_PATH=$(dirname $( dirname $( realpath $0 )))
RUN_PATH=/nb/Research/freezeman-processing/novaseq/2025 # where to look for new runs 
READSET_PATH=$(realpath ${1}) # where to fetch googlesheets and look for Tim's readset files
ANALYSIS_PATH=$(realpath ${2}) # where to put new genpipes runs


#########################################################
# Functions

function process_run {
 $NEW_RUN=$1   
  RUN_NAME=$( echo $NEW_RUN | awk -F'_' '{print $2"_"$3}')

#######################################################
## Checking if ncm files in the new run have finished generating

for f in $RUN_PATH/$NEW_RUN/job_output/check_sample_mixup/sample_mixup.ngscheckmate_by_lane.*.sh; do
    lane=$( basename $f | cut -d_ -f4 | cut -d'.' -f2 )
    
    if [ -f "$RUN_PATH/$NEW_RUN/job_output/checkpoint/check_sample_mixup.${RUN_NAME}.${lane}.stepDone" ]; then
        echo -e "Files for $RUN_NAME lane $lane have finished processing."
    else
        echo -e "Files for $RUN_NAME lane  $lane have not yet finished processing. Trying again later."
        return 1
    fi
done

######################################
## parse runinfo files
module purge && \
module load mugqic/python/3.12.1

python scripts/parse_json.py \
    --json $RUN_PATH/$NEW_RUN/${RUN_NAME}*.json \
    --out $OUTPUT_PATH/${NEW_RUN}_samples.csv


#################################################
### create project directories, and add samples

while read line
do 
    sample=$(echo $line| cut -f1 -d,)
    projectid=$(echo $line | cut -f2 -d,)


    if [ -d "$ANALYSIS_PATH/Project_${project}"]
    then
        cat $line >>  $ANALYSIS_PATH/Project_${project}/New_Samples.csv
    else
        mkdir $ANALYSIS_PATH/Project_${project}
        cat $line >>  $ANALYSIS_PATH/Project_${project}/New_Samples.csv
    fi
done< $OUTPUT_PATH/${NEW_RUN}_Samples.csv                         



}


########################################################
## Move to OUTPUT_PATH


cd $OUTPUT_PATH

## Prepare run list
echo -e "Detecting runs...\n"

## TODO: think about how to handle re-runs
find ${RUN_PATH} -maxdepth 1 -type d -exec basename {} \; > all.runs.txt.tmp
diff -Bw <(sort done/done_SS.txt) <(sort all.runs.txt.tmp) |\
    grep "^>" |\
    sed s:"> ":: > new.runs.tmp

if [ $(cat new.runs.tmp | wc -l) -gt 0 ]
then
    echo "New runs detected:"
    cat new.runs.tmp
else
    echo "No new runs detected."
    rm new.runs.tmp
    rm all.runs.txt.tmp
    exit
fi

rm all.runs.txt.tmp


### TODO : Modify NEW_RUN, because I'll have multiple new runs
while read NEW_RUN;
do  
   process_run $NEW_RUN

done< new.runs.tmp


###################################
## for each project with new samples, run R

PROJECT_LIST=$(cat *Samples.csv | cut -f2 -d,| sort -u)

for project in $PROJECT_LIST
do

    Rscript.....

done





### Directory structure:
#### ngscheckmate_home
####             |-- automation (OUTPUT_PATH)
####                      |-- scripts
####                      |-- logs                      
####             |-- processing (ANALYSIS_PATH)  
####                      |-- project_01
####                      |-- project_02
####                             |-- ncm.done
####                             |-- ncm
#####                            |-- .rdata  



