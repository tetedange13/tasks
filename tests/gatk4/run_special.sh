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

# Assume 'output_test' dir exist -> Crucial to run 'solo' test with '--keep-working-directory'

main_test_dir=$1
out_test=out-test && mkdir "$out_test"

# ENH: Find a way to correctly parallelize bellow steps through SLURM ? (instead of using frontale)
#      Or not needed as test files should be small ?


## Check content of VCF files
# HaplotypeCaller VCF:
find "$main_test_dir"/ -type f -name "*.HC.score.vcf" |
        parallel --jobs 1 "checksum_vcf {}" |
        sort --key=1,1 > "$out_test"/HC.vcf.md5
