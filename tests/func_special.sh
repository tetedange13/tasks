## Global func to check 'special' files


checksum_vcf() {
	printf $(basename "$1")'\t'
	bcftools view --no-header "$1" | md5sum
}
export -f checksum_vcf

checksum_bam() {
	printf $(basename "$1")'\t'
	samtools view "$1" | md5sum
}
export -f checksum_bam

excel_to_tsv() {
	local in_xlsx=$1
	local sheet_name=$2
	/mnt/Bioinfo/Softs/bin/csvtk xlsx2csv --out-tabs --sheet-name "$sheet_name" "$in_xlsx"
}
export -f excel_to_tsv

