import json
import csv
import argparse
import os
import re

parser = argparse.ArgumentParser()
parser.add_argument("--json")
parser.add_argument("--outdir")


run_info="/Users/dperley/Library/CloudStorage/GoogleDrive-danielle.perley@computationalgenomics.ca/My Drive/Projects/MAGIC/NGScheckmate/LH00375_0083_MOHYR4Run33_2025-01-29_10-20-52.json"

run_dir=os.path.dirname(run_info)
out="Samples.csv"
with open(run_info,mode='r') as f:
    run_data=json.load(f)

run_name=run_data['run_name']    
sample_data=run_data['samples']
sample_reduced=[]
for s in sample_data:
    d={}
    d['sample_name']=s['sample_name'] + "_" + str(s['derived_sample_obj_id'])
    if re.match("MoHQ",s['sample_name']):
        d['projectID']="MoHQ"
    else:    
        d['projectID']=s['project_obj_id']
    d['projectName']=s['project_name']
    d['lane']=s['lane']
    d['run_name']= run_name
    d['ncm_path'] = os.path.join(run_dir,"sample_mixup_detection/NGSCheckMate/Homo_sapiens/by_lane",str(s['lane']),s['sample_name'] + "_" + str(s['derived_sample_obj_id'])+".ncm")
    sample_reduced.append(d)

## add path to ncm file
cnames=['sample_name','projectID','projectName','lane','run_name','ncm_path']    
with open(out, 'w') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=cnames)
    writer.writeheader()
    writer.writerows(sample_reduced)
 