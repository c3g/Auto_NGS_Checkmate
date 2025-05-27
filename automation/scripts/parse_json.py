import json
import csv
import argparse
import os
import re
import glob

parser = argparse.ArgumentParser()
parser.add_argument("--json")
parser.add_argument("--out")
parser.add_argument("--regex")

args = parser.parse_args()
run_info=args.json

#run_dir=os.path.dirname(run_info)
#if "manual_launch" in run_dir:
#    run_dir=os.path.dirname(run_dir)

## process regexes
project_regexes={}
with open(args.regex,mode='r') as f:
    for row in csv.reader(f,delimiter=' '):
        project_regexes[row[0]]=row[1]
    
with open(run_info,mode='r') as f:
    run_data=json.load(f)
fcid=run_data['container_barcode']
run_dir=glob.glob("/nb/Research/freezeman-processing/*seq*/*/*"+fcid+"*")[0]
run_name=run_data['run_name']    
sample_data=run_data['samples']
sample_reduced=[]
for s in sample_data:
    d={}
    d['sample_name']=s['sample_name'] + "_" + str(s['derived_sample_obj_id'])
    for key in project_regexes:
        if re.match(project_regexes[key],s['sample_name']):
            d['projectID']=key
            d['projectName']=key
        else:    
            d['projectID']=s['project_obj_id']
            d['projectName']=s['project_name']

    d['lane']=s['lane']
    d['run_name']= run_name
    d['ncm_path'] = os.path.join(run_dir,"sample_mixup_detection/NGSCheckMate/Homo_sapiens/by_lane",str(s['lane']),s['sample_name'] + "_" + str(s['derived_sample_obj_id'])+".ncm")
    sample_reduced.append(d)

## add path to ncm file
cnames=['sample_name','projectID','projectName','lane','run_name','ncm_path']    
with open(args.out, 'w') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=cnames,lineterminator="\n")
    writer.writerows(sample_reduced)
 
