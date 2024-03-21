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
out_test=out-test && mkdir "$out_test"

# ENH: Find a way to correctly parallelize bellow steps through SLURM ? (instead of using frontale)
#      Or not needed as test files should be small ?


## Check content of BAM files
# (by default no header with 'samtools view')
find "$main_test_dir" -type f -name "*.bam" ! -iname "*sort*" |
	parallel --jobs 1 "checksum_bam {}" |
	sort --key=1,1 > "$out_test"/bam.md5
