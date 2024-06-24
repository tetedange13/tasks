#########################################
#			                            #
# Bash script to checksum special files #
#			                            #
#########################################


# Activate Conda env with all required tools:
source /etc/profile.d/conda.sh && conda activate /mnt/Bioinfo/Softs/src/conda/envs/Exome_prod


# 'set -u' can only be used AFTER activation of Conda env
set -xeuo pipefail


source ./tests/func_special.sh

# Assume 'Exome_solo_on_cluster' dir exist
# -> Crucial to run 'solo' test with '--keep-working-directory'

main_test_dir=$1
csvtk_exe=/mnt/Bioinfo/Softs/bin/csvtk
out_test=out-test && mkdir "$out_test"



## Check sheets of Achab xlsx ('catch' and 'newHope' are expected to have the same ?)
find "$main_test_dir" -type f -name "*achab*.xlsx" |
	parallel "printf {/}'\t'; $csvtk_exe xlsx2csv --list-sheets {} | $csvtk_exe cut --tabs --fields sheet | $csvtk_exe del-header | $csvtk_exe transpose" |
	sort --key=1,1 > "$out_test"/achab_sheets.tsv


## Check content of Achab xlsx files
# First convert to TSV:
# WARN: Sheet_name for 'ALL_' is different through miniwdl (more zeros at the end)
#       -> Due to a problem of 'locale' maybe ?
find "$main_test_dir" -type f -name "*achab*.xlsx" |
	parallel --jobs 1 "excel_to_tsv {} 'ALL_0.012000' > $out_test/{/}.tsv"
# Then checksum all:
md5sum "$out_test"/*achab*.xlsx.tsv |
	sort --key=2,2 > "$out_test"/achab.xlsx.md5


## Check content of 're-sorted' Achab
# (to bypass Achab problem of random sort for some variants)
ls -d "$out_test"/*achab*.xlsx.tsv |
	parallel "printf {/}'\t'; csvtk cut --tabs --fields -MPA_ranking {} | sort | md5sum" |
	sort --key=1,1 > "$out_test"/achab.xlsx.unsorted.md5
