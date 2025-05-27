#!/bin/bash

# NGSCheckmate-- AUTOMATIC RUN DETECTION AND PIPELINE LAUNCH
########################################################

if [ "$#" != 1 ]
then
    echo "Error incorrect number of command line arguments."
    echo "Usage: $(basename $0) <analysis_dir>"
    exit
fi

#01 0 * * 1 source $HOME/.bash_profile; bash -l /lb/robot/research/NGSCM/automation/scripts/auto_ngscheckmate.sh /lb/robot/research/NGSCM/proc > /lb/robot/research/NGSCM/automation/logs/cron_ngscm.log 2>&1
########################################################
# Set file paths
OUTPUT_PATH=$(dirname $( dirname $( realpath $0 )))
#OUTPUT_PATH=/lb/project/C3G/projects/Danielle/NGScheckmate_report/test2
RUN_PATH=/nb/Research/freezeman-processing # where to look for new runs 
#RUN_PATH=/lb/project/C3G/projects/Danielle/NGScheckmate_report/test/run_dir
ANALYSIS_PATH=$(realpath ${1}) # where to the project directories
#ANALYSIS_PATH=/lb/project/C3G/projects/Danielle/NGScheckmate_report/test2
INSTRUMENTS="novaseq novaseqx"

#########################################################
# Functions

function copy_ncm_files {  
  RUN_NAME=$( echo $NEW_RUN | awk -F'_' '{print $2"_"$3}')
#######################################################
## Checking if ncm files in the new run have finished generating

RUN_FOLDER=$(ls -d $RUN_PATH/*seq*/*/$NEW_RUN)

n_checkmate_scripts=$(ls ${RUN_FOLDER}/job_output/check_sample_mixup/sample_mixup.ngscheckmate_by_lane*sh 2>/dev/null | wc -l)

if [ "$n_checkmate_scripts" -eq 0 ]; then
 	echo "NGSCheckmate not run for $NEW_RUN"
        echo $NEW_RUN >> $OUTPUT_PATH/done/done.txt
        return 1
fi

lanes=$(ls ${RUN_FOLDER}/job_output/check_sample_mixup/sample_mixup.ngscheckmate_by_lane*sh | awk -F/ '{print $NF}' | cut -f5 -d_ | sort -u)
for i in $lanes; do


     done_file=$(ls -1rt ${RUN_FOLDER}/job_output/check_sample_mixup/sample_mixup.ngscheckmate_by_lane_${i}.*done 2>/dev/null | tail -n 1)

    if [ -f "$done_file" ]; then
        echo -e "Files for $RUN_NAME lane $i have finished processing."
    else
        echo -e "Files for $RUN_NAME lane  $i have not yet finished processing. Trying again later."
        return 1
    fi
done

######################################
## parse runinfo files
module purge && \
module load mugqic/python/3.12.2

json=$(ls -1rt ${RUN_FOLDER}/*${RUN_NAME}*.json 2>/dev/null | tail -n 1)
## if json is in manual launch

if [ ! -f "$json" ]; then
json=$(ls -1rt ${RUN_FOLDER}/manual_launch/*${RUN_NAME}*.json 2>/dev/null | tail -n 1)
fi

echo "$json" 
if [ -f "$json" ];
then
python scripts/parse_json.py \
    --json "$json" \
    --regex $OUTPUT_PATH/project_regexes.txt \
    --out $OUTPUT_PATH/${RUN_NAME}_Samples.csv
else
	echo "no runInfo file for $NEW_RUN"
	return 1
fi

#################################################
### create project directories, and add samples

while read line
do 
    projectid=$(echo $line | cut -f2 -d,)
    lane=$(echo $line | cut -f4 -d,)
    sample=$(echo $line | cut -f1 -d,)
    path=$(echo $line | cut -f6 -d,) 
    
    if ! grep -q -w "$projectid" $OUTPUT_PATH/project_blacklist.txt 
    then	 
    	if [ ! -d "$ANALYSIS_PATH/Project_${projectid}/ncm_files" ]
    	then    
    		mkdir -p $ANALYSIS_PATH/Project_${projectid}/ncm_files
         fi 
   
    echo $line >>  $ANALYSIS_PATH/Project_${projectid}/New_Samples.csv
    cp -v $path $ANALYSIS_PATH/Project_${projectid}/ncm_files/${sample}_L00${lane}.ncm
   fi  
done < $OUTPUT_PATH/${RUN_NAME}_Samples.csv                         

}


########################################################
## Move to OUTPUT_PATH

TIMESTAMP=$(date +%FT%H.%M.%S)
cd $OUTPUT_PATH
echo -e "Detecting runs...\n"

## TODO: think about how to handle re-runs

for i in $INSTRUMENTS
do
	find -L ${RUN_PATH}/$i -mindepth 2 -maxdepth 2 -type d -exec basename {} \; >> all.runs.txt.tmp
done

diff -Bw <(sort done/done.txt) <(sort all.runs.txt.tmp) |\
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
   copy_ncm_files

done < new.runs.tmp


###################################
## for each project with new samples, run R

PROJECT_LIST=$(cat *Samples.csv | cut -f2 -d,| grep -vf $OUTPUT_PATH/project_blacklist.txt | sort -u)

for project in $PROJECT_LIST
do
     send_email=""
   
   cd $ANALYSIS_PATH/Project_${project}
   project_name=$(cut -f3 -d, New_Samples.csv | sort -u) 	
  
    if [ ! -f "Config.yaml" ]
    then
cat << EOF > Config.yaml
outpath: $ANALYSIS_PATH/Project_${project}
cor_thres: 0.5
project_name: $project_name
EOF
   fi
    
    if [  -f "Processed_Samples.csv" ]   
    then
    COMM=$(cat << EOF
module purge && module load mugqic/R_Bioconductor/4.2.2_3.16 mugqic/pandoc && 	
Rscript $OUTPUT_PATH/scripts/Correlation.R -n $ANALYSIS_PATH/Project_${project}/New_Samples.csv -s $ANALYSIS_PATH/Project_${project}/Processed_Samples.csv -o $ANALYSIS_PATH/Project_${project}/Correlation.rds -i $ANALYSIS_PATH/Project_${project}/ncm_files
EOF
)
    else
    COMM=$(cat << EOF
module purge && module load mugqic/R_Bioconductor/4.2.2_3.16 mugqic/pandoc &&
Rscript $OUTPUT_PATH/scripts/Correlation.R -n $ANALYSIS_PATH/Project_${project}/New_Samples.csv -o $ANALYSIS_PATH/Project_${project}/Correlation.rds -i $ANALYSIS_PATH/Project_${project}/ncm_files
EOF
)
fi
     
   if [ -f regexes.csv ]
   then 
       send_email="${send_email}${project} "

       COMM="$COMM"$(cat << EOF
 && Rscript -e 'rmarkdown::render("$OUTPUT_PATH/scripts/checkmate_out.Rmd",param=list(args="$ANALYSIS_PATH/Project_${project}/Config.yaml"),output_file="$ANALYSIS_PATH/Project_${project}/checkmate_out.html")' &&
cat $ANALYSIS_PATH/Project_${project}/New_Samples.csv >> $ANALYSIS_PATH/Project_${project}/Processed_Samples.csv &&
rm $ANALYSIS_PATH/Project_${project}/New_Samples.csv
EOF
)
   fi	
jobid=$(echo "$COMM" | qsub -j oe -o $OUTPUT_PATH/logs/Project_${project}_${TIMESTAMP}_checkmate.out -N Project_${project}_ngs_checkmate -d $ANALYSIS_PATH/Project_${project} -l walltime=2:0:0 -l nodes=1:ppn=1 | cut -f1 -d.) 	   
ALLPIDS="$ALLPIDS $jobid"
 echo "Project_${project}" > $ANALYSIS_PATH/Project_${project}/job.log
 echo "$COMM" >> $ANALYSIS_PATH/Project_${project}/job.log
 echo "" >> $ANALYSIS_PATH/Project_${project}/job.log
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
echo $send_email
if [ "$send_email" != "" ]
then
  
for i in $(echo $send_email);
do

	HTML=$(cat <<EOF
<html><head><title> Project $i NGSCheckmate Report </title>
</head>
<body>
This is an automated message sent from the NGSCheckmate event monitor.<br>
NGSCheckmate report for Project $i is updated <br>
<br>
Results are stored here:<br>
$ANALYSIS_PATH/Project_${i}<br>
<br>
If you encounter any issues with this automated system please contact danielle.perley@mcgill.ca.<br>
<br>
EOF
)                       
            #EMAILLIST=$(grep $i $OUTPUT_PATH/email_config.txt | cut -f2)  
			EMAILLIST="danielle.perley@mcgill.ca"
                        (
                        echo "To: $(echo "$EMAILLIST")"
                        echo "MIME-Version: 1.0"
                        echo "Subject: NGSCheckmate Report updated for Project $i"
                        echo "Content-Type: text/html"
                        echo
                        echo "$HTML"
                        echo
			 ) | sendmail -t -f abacus.genome@mail.mcgill.ca
done
fi

cd $OUTPUT_PATH

n_sample_files=$(ls *Samples.csv 2>/dev/null | wc -l) 
if [ $n_sample_files -gt 0 ]; then
ls *Samples.csv | sed 's/_Samples.csv//g' | grep -f- new.runs.tmp >> done/done.txt
rm *Samples.csv
fi
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
####                             |-- Config.yaml
####                             |-- regexes.csv 


