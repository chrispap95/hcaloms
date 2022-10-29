LOAD DATA
INTO TABLE pedestal_dev
APPEND
FIELDS TERMINATED BY "\t"
OPTIONALLY ENCLOSED BY "'"
(
run_id,
run_timestamp TIMESTAMP WITH TIME ZONE "YYYY-MM-DD HH24:MI:SS TZR",
HEsmall_mean,
HEsmall_rms,
HElarge_mean,
HElarge_rms,
HBsmall_mean,
HBsmall_rms,
HBlarge_mean,
HBlarge_rms,
HF_mean,
HF_rms,
HO_mean,
HO_rms
)
