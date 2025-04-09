This repository contains scripts to automatically detect new NGS checkmate files (ncm) generated from genpipes runprocessing pipeline, and calculate correlations based on predefined sets of samples.

## Steps
1. At a determined frequency ie once a week, (TBD), the auto_NGS_checkmate.sh will look for new runs that have passed the NGS checkmate step for all lanes, and using the information from the run json, create directories for each project contained in the run, and copy the ncm files. minor exception is the "MOH" project- samples will be placed in the Project_MoHQ folder based on file name, not the project listed in the run json. 
2. on all project directories with newly added samples, and the script Correlation.R is run calculate the correlation between readsets. The script will check if each ncm file as the correct number of rows (21039). If samples contain multiple readsets (ex sequenced on multiple lanes), the lowest correlation will be will be used as a representative. Output is a dataframe saved as a  *rds object.
3. if a file "regexes.csv" exists, then the checkmate.out.Rmd file is run to generate a report of the NGS checkmate results.

Directory structure:
``` bash
ngscheckmate_home
            |-- automation
                     |-- scripts
                     |-- logs
            |-- processing
                     |-- project_01
                            |-- Correlation.rds
                            |-- New_Samples.csv
                            |-- ncm_files
				|-- sample_lane.ncm
                     |-- project_MoHQ
                            |-- New_Samples.csv
                            |-- Processed_Samples.csv
                            |-- ncm_files
                              |--sample_lane.ncm
                            |-- Correlation.rds
                            |-- checkmate_out.Rmd 
                            |-- checkmate_out.html
                            |-- AllComparisons_table_NGSCM_.csv
			    |-- summary_table_NGSCM.csv	

```

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


### TO-DO, etc
- samples in multiple runs
- missing samples or files
- set-up user
- make reports accessible to interested parties (ie for MOH, Pascale) 
- should there be a section called "New Samples"?
- should the ncm files be copied or linked?
