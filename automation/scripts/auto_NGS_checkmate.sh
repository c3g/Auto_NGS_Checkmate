#!/bin/bash

# NGSCheckmate-- AUTOMATIC RUN DETECTION AND PIPELINE LAUNCH
########################################################

if [ "$#" != 1 ]
then
    echo "Error incorrect number of command line arguments."
    echo "Usage: $(basename $0) <analysis_dir>"
    exit
fi

#01 0 * * 1,3,5 source $HOME/.bash_profile; bash -l /lb/robot/research/DOvEE/automation/scripts/auto_DOvEE_vardict.sh /lb/robot/research/DOvEE/automation/latest_readsets /lb/robot/research/DOvEE/processing > /lb/robot/research/DOvEE/automation/logs/cron_vardict.log 2>&1
########################################################
# Set file paths
#OUTPUT_PATH=$(dirname $( dirname $( realpath $0 )))
OUTPUT_PATH=/lb/project/C3G/projects/Danielle/NGScheckmate_report/test
RUN_PATH=/nb/Research/freezeman-processing # where to look for new runs 
#RUN_PATH=/lb/project/C3G/projects/Danielle/NGScheckmate_report/test/run_dir/
#ANALYSIS_PATH=$(realpath ${1}) # where to the project directories
ANALYSIS_PATH=/lb/project/C3G/projects/Danielle/NGScheckmate_report/test
INSTRUMENTS="novaseq novaseqx"

#########################################################
# Functions

function process_run {  
  RUN_NAME=$( echo $NEW_RUN | awk -F'_' '{print $2"_"$3}')
 YEAR=$(echo $NEW_RUN | cut -c1-2)
 seq=$(echo $NEW_RUN | rev | cut -f1 -d- | rev)
#######################################################
## Checking if ncm files in the new run have finished generating

for f in $RUN_PATH/$seq/20${YEAR}/$NEW_RUN/job_output/check_sample_mixup/sample_mixup.ngscheckmate_by_lane*sh; do

    echo $f
     lane=$(basename $f | cut -d_ -f5 )
    if [ -f "$RUN_PATH/$seq/20${YEAR}/$NEW_RUN/job_output/checkpoint/check_sample_mixup.${RUN_NAME}.${lane}.stepDone" ]; then
        echo -e "Files for $RUN_NAME lane $lane have finished processing."
    else
        echo -e "Files for $RUN_NAME lane  $lane have not yet finished processing. Trying again later."
        return 1
    fi
done

######################################
## parse runinfo files
module purge && \
module load mugqic/python/3.12.2

json=$(ls $RUN_PATH/$seq/20${YEAR}/$NEW_RUN/${RUN_NAME}*.json)
if [ -f "$json" ];
then
python scripts/parse_json.py \
    --json $RUN_PATH/$seq/20${YEAR}/$NEW_RUN/${RUN_NAME}*.json \
    --out $OUTPUT_PATH/${RUN_NAME}_Samples.csv
else
	echo "no runInfo file for $NEW_RUN"
fi

#################################################
### create project directories, and add samples

while read line
do 
    projectid=$(echo $line | cut -f2 -d,)
    lane=$(echo $line | cut -f4 -d,)
    sample=$(echo $line | cut -f1 -d,)
    path=$(echo $line | cut -f6 -d,) 
    if [ ! -d "$ANALYSIS_PATH/Project_${projectid}/ncm_files" ]
    then    
    mkdir -p $ANALYSIS_PATH/Project_${projectid}/ncm_files
    fi
    
   echo $line >>  $ANALYSIS_PATH/Project_${projectid}/New_Samples.csv
   cp -v $path $ANALYSIS_PATH/Project_${projectid}/ncm_files/${sample}_L00${lane}.ncm

done< $OUTPUT_PATH/${RUN_NAME}_Samples.csv                         

}


########################################################
## Move to OUTPUT_PATH

TIMESTAMP=$(date +%FT%H.%M.%S)
cd $OUTPUT_PATH
echo -e "Detecting runs...\n"

## TODO: think about how to handle re-runs

for i in $INSTRUMENTS
do
	find ${RUN_PATH}/$i -mindepth 2 -maxdepth 2 -type d -exec basename {} \; >> all.runs.txt.tmp
done

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


while read NEW_RUN
do  
   process_run

done< new.runs.tmp


###################################
## for each project with new samples, run R

PROJECT_LIST=$(cat *Samples.csv | cut -f2 -d,| sort -u)

for project in $PROJECT_LIST
do
    cd $ANALYSIS_PATH/Project_${project}
    project_name=$(cut -f3 -d, New_Samples.csv | sort -u) 	
    if [ ! -f "Config.yaml" ]
    then
	cat << EOF > Config.yaml
outpath: $PWD
cor_thres: 0.5
project_name: $project_name
EOF
   fi		
    
    if [  -f "Processed_Samples.csv" ]   
    then
    COMM=$(cat << EOF
module purge && module load mugqic/R_Bioconductor/4.3.2_3.18 mugqic/pandoc && 	
Rscript $OUTPUT_PATH/scripts/Correlation.R -n New_Samples.csv -s Processed_Samples.csv -o Correlation.rds -i ncm_files
EOF
)
    else
    COMM=$(cat << EOF
module purge && module load mugqic/R_Bioconductor/4.3.2_3.18 mugqic/pandoc &&
Rscript $OUTPUT_PATH/scripts/Correlation.R -n New_Samples.csv -o Correlation.rds -i ncm_files
EOF
)
fi
     
   if [ -f regexes.csv ]
   then 
	if [ ! -f checkmate_out.Rmd ]
	then
	
	    cp $OUTPUT_PATH/scripts/checkmate_out.Rmd .
        fi	
       COMM="$COMM"$(cat << EOF
 && Rscript -e 'rmarkdown::render("checkmate_out.Rmd")' &&
cat New_Samples.csv >> Processed_Samples.csv &&
rm New_Samples.csv
EOF
)
   fi	
jobid=$(echo "$COMM" | qsub -j oe -o $OUTPUT_PATH/logs/Project_${project}_${TIMESTAMP}_checkmate.out -N Project_${project}_ngs_checkmate -d $ANALYSIS_PATH/Project_${project} -l walltime=1:0:0 -l nodes=1:ppn=1 | cut -f1 -d.) 	   
ALLPIDS="$ALLPIDS $jobid"
 echo "Project_${project}" > job.log
 echo "$COMM" >> job.log
 echo "" >> job.log
done

## check if jobs are done
echo -n "Wait for jobs to complete ... "
if [ "$ALLPIDS" == "" ]
then
	echo "no jobs"
else
	ALLPIDS=$(echo "$ALLPIDS" | tr ' ' '\n' | sort)
	#echo -n "ALLPIDS:"; echo "$ALLPIDS" | tr '\n' ' ';
	sleep 15
	while(true); do
               while(true); do
                    a=$(qstat);
                    if [ $? -eq 0 ]; then
                           break;
                    fi;
                     sleep 1;
                done;
                ALLPIDSACTIVE=$(echo "$a" | tail -n+3 | awk '$5!="C"{print $0}' | awk -F'.' '{print $1}' | sort);
                #echo -n "ALLPIDSACTIVE: "; echo "$ALLPIDSACTIVE" | tr '\n' ' ';
                N=$(comm -12 <(echo "$ALLPIDS") <(echo "$ALLPIDSACTIVE") | wc -l)
                if [ "$N" == "0" ]; then
                            break
                fi
                echo -n "($N)"
                sleep 60
       done
	echo " done"
### add email here

fi

cd $OUTPUT_PATH

ls *Samples.csv | sed 's/_Samples.csv//g' | grep -f- new.runs.tmp >> done/done_SS.txt
rm *Samples.csv
rm new.runs.tmp


### Directory structure:
#### ngscheckmate_home
####             |-- automation (OUTPUT_PATH)
####                      |-- scripts
####                      |-- logs                      
####             |-- processing (ANALYSIS_PATH)  
####                      |-- project_01
####                      |-- project_02
####                             |-- New_samples.csv
####                             |-- processed_samples.csv
####                             |-- ncm
####                               |--sample.ncm
#####                            |-- correlation.rds 
####                             |-- ngs_checkmate.Rmd



