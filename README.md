usage: 0 6 * * 1 bash -l automation/scripts/auto_NGS_checkmate.sh /lb/robot/research/freezeman-processing/NGS_Checkmate_Reports > automation/logs/cron_ngsm.txt 2>&1 &

This repository contains scripts to automatically detect new NGS checkmate files (ncm) generated from genpipes runprocessing pipeline, and calculate correlations based on predefined sets of samples.

## Steps
1. Once a week, the auto_NGS_checkmate.sh will look for new runs that have passed the NGS checkmate step for all lanes, and using the information from the run json, create directories for each project contained in the run, and copy the ncm files. Large scale projects like "MOH" project that emcompass multiple freezeman projects can be also be  - samples will be defined. 

2. on all project directories with newly added samples, and the script Correlation.R is run calculate the correlation between readsets. The script will check if each ncm file as the correct number of rows (21039). If samples contain multiple readsets (ex sequenced on multiple lanes), the lowest correlation will be will be used as a representative. Output is a dataframe saved as a "rds" object.

3. if  the file "regexes.csv" exists in the project directory, then the checkmate.out.Rmd file is run to generate a report of the NGS checkmate results.



Currently the pipeline will check for new novaseq and novaseqx runs 

Example regexes.csv file:

| column1 | column2 |
|:-------|:-------|
| individual | "MoHQ-[A-Za-z]+-[0-9]+-[0-9]+" |
| DN | DN |
| DT | DT |
| RT | RT |

output files: 
- Correlation.rds - an R object of correlation results 

if a regexes.csv file was provided:  
- checkmate_out.html - html report of results, with suspicious results extracted
- AllComparisons_table_NGSCM_.csv - contains the correlations for all pairwise comparisons in project, along with the state, and run name of the samples
- summary_table_NGSCM.csv - correlation results per individual

| Case | DNvsDT | DNvsRT | DTvsRT |
|:----|:-------|:--------|:----------|
|MoHQ-CM-21-7 | 0.9313| 0.8871| 0.8728 | 


Other configuration files:

project_blacklist.txt - list of projects for which ngscheckmate should not be run:
```
head project_blacklist.txt
71
```
email_config.txt - list of emails that should be sent when report is updated

project_regexes.txt - list of projects with sample regexes.txt, first column is project name, and second column is sample name regexes
```
head project_regexes.txt
MoHQ MoHQ
```

usage: 0 6 * * 1 bash -l automation/scripts/auto_NGS_checkmate.sh /lb/robot/research/freezeman-processing/NGS_Checkmate_Reports > automation/logs/cron_ngsm.txt 2>&1 &
