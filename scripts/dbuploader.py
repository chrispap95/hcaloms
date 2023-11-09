import argparse
import datetime
import os
import subprocess

parser = argparse.ArgumentParser(
    description="This script is used to upload analysis data to oracle database"
)
parser.add_argument("-f", "--inputfile", help="Input file name", required=True)
parser.add_argument("-p", "--parfile", help="Parameter file name", required=True)
parser.add_argument("-l", "--log", help="Log file name", required=True)
args = parser.parse_args()

parfile = args.parfile
data_file = os.path.basename(args.inputfile)
data_path = os.path.dirname(args.inputfile)

for _root, _dirs, files in os.walk(data_path, topdown=True):
    if data_file in files:
        if os.stat(data_path + "/" + data_file).st_size > 0:
            upload_to_db = subprocess.Popen(
                ["sqlldr", "parfile=" + parfile],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            output, errors = upload_to_db.communicate()
            upload_to_db.wait()
            with open(args.log, "a") as log_file:
                log_file.write(datetime.datetime.now().ctime())
                log_file.write("\n")
                log_file.write(str(output, "utf-8"))
                log_file.write(str(errors, "utf-8"))
                log_file.write("\n")
    else:
        print("[dbuploader.py]: Input file doesn't exist!")
