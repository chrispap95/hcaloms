import argparse
import datetime
import os
import subprocess
import sys

parser = argparse.ArgumentParser(
    description="This script is used to upload analysis data to oracle database"
)
parser.add_argument("-f", "--inputfile", help="Input file name", required=True)
parser.add_argument("-p", "--parfile", help="Parameter file name", required=True)
args = parser.parse_args()


data_path = os.environ["CMSSW_BASE"] + "/src/hcaloms/data/"
data_file = args.inputfile
parfile = os.environ["CMSSW_BASE"] + "/src/hcaloms/DBUtils/" + args.parfile

dir_path = os.path.dirname(data_path)

for _root, _dirs, files in os.walk(dir_path, topdown=True):
    if data_file in files:
        if os.stat(data_path + data_file).st_size > 0:
            upload_to_db = subprocess.Popen(
                ["sqlldr", "parfile=" + parfile],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            output, errors = upload_to_db.communicate()
            upload_to_db.wait()
            with open(os.environ["CMSSW_BASE"] + "/tmp/log", "a") as log_file:
                log_file.write(datetime.datetime.now().ctime())
                log_file.write("\n")
                log_file.write(str(output, "utf-8"))
                log_file.write(str(errors, "utf-8"))
                log_file.write("\n")
    else:
        print("Input file doesn't exist!")
