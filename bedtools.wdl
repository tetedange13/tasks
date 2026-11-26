version 1.0

# MobiDL 2.0 - MobiDL 2 is a collection of tools wrapped in WDL to be used in any WDL pipelines.
# Copyright (C) 2021 MoBiDiC
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.


task computePoorCoverage {
	meta {
		author: "Olivier ARDOUIN"
		email: "o-ardouin(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2021-10-11"
	}

	input {
		File BamFile
		File IntervalBedFile
		Int BedtoolsLowCoverage = 30
		Int BedToolsSmallInterval = 20
		String GenomeVersion = "hg19"

		String? outputPath
		String? name
		String ext = ".LowCoverage.tsv"

		String BedToolsExe = "bedtools"
		String awkExe = "awk"
		String sortExe = "sort"

		Int threads = 1
		Int memory
		String apptainer_img = "bedtools:XXX"
	}

	String? baseName = if defined(name) then name else sub(basename(BamFile),"(.*)\\.(sam|bam|cram)$","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<

		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{BedToolsExe} genomecov -ibam ~{BamFile} -bga \
		| ~{awkExe} -v low_coverage="~{BedtoolsLowCoverage}" '$4<low_coverage' \
		| ~{BedToolsExe} intersect -a ~{IntervalBedFile} -b - \
		| ~{sortExe} -k1,1 -k2,2n -k3,3n \
		| ~{BedToolsExe} merge -c 4 -o distinct -i - \
		| ~{awkExe} -v small_intervall="~{BedToolsSmallInterval}" \
		'BEGIN {OFS="\t";print "#chr","start","end","region","size bp","type","UCSC link"} {a=($3-$2+1);if(a<small_intervall) {b="SMALL_INTERVAL"} else {b="OTHER"};url="http://genome-euro.ucsc.edu/cgi-bin/hgTracks?db='~{GenomeVersion}'&position="$1":"$2-10"-"$3+10"&highlight='~{GenomeVersion}'."$1":"$2"-"$3;print $0, a, b, url}' > "~{outputFile}"

	>>>

	output {
		File poorCoverageFile = "~{outputFile}"
	}

	runtime {
		cpu: threads
		requested_memory_mb_per_core: memory
		container: "~{apptainer_img}"
	}
}

task computePoorCoverageExtended {
	meta {
		author: "Thomas Guignard"
		email: "t-guignard(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2021-11-15"
	}

	input {
		String path_exe = "bedtools"

		File BamFile
		File intervalBedFile
		String PoorCoverageFileFolder
		File CoverageFile

		Int BedtoolsLowCoverage = 10
		Int BedToolsSmallInterval = 5

		String genomeVersion = "hg19"

		String? outputPath
		String? name
		String ext = ".PoorCoverage_extended.tsv"

		String ofs = "\\t"
		String fs = "\\t"

		Int threads = 1
		Int memory
		String apptainer_img = "bedtools:XXX"
	}

	String? baseName = if defined(name) then name else sub(basename(BamFile),"(.*)\\.(sam|bam|cram)$","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<

		~{path_exe} genomecov -ibam ~{BamFile} -bga \
		| awk -v low_coverage="~{BedtoolsLowCoverage}" '$4<low_coverage' \
		| ~{path_exe} intersect -wb -a ~{intervalBedFile} -b - \
		| sort -k1,1 -k2,2n -k3,3n \
		| ~{path_exe} merge -d 1 -c 4,10,10 -o distinct,min,max -i - \
		| ~{path_exe} intersect -loj -c -a -  -b ~{PoorCoverageFileFolder}/*.tsv  \
		| ~{path_exe} intersect -wb -loj -a -  -b ~{CoverageFile}  \
		| awk -v small_intervall="~{BedToolsSmallInterval}" -v genomeVersion="~{genomeVersion}" \
		'BEGIN {OFS="~{ofs}";print "#chr","start","end","gene","region","region_size","type","MIN_COV","MAX_COV","Occurrence","ROI_MEAN_COV","UCSC link"} {split($4,gene,":");a=($3-$2+1);if(a<small_intervall) {b="SMALL_INTERVAL"} else {b="OTHER"};url="http://genome-euro.ucsc.edu/cgi-bin/hgTracks?db='genomeVersion'&position="$1":"$2-10"-"$3+10"&highlight='genomeVersion'."$1":"$2"-"$3; print $1,$2,$3,gene[1],$4,a, b,$5,$6,$7,$12, url}' \
		> ~{outputFile}

	>>>

	output {
		File poorCoverageFile = outputFile
	}

	runtime {
		cpu: threads
		requested_memory_mb_per_core: memory
		container: "~{apptainer_img}"
	}

	parameter_meta {
		path_exe: {
			description: 'Path to the BedTools exe',
			category: 'Required'
		}
		BamFile: {
			description: 'Bam file to process',
			category: 'Required'
		}
		intervalBedFile: {
			description: 'Bed file, need to be merged',
			category: 'Required'
		}
		PoorCoverageFileFolder: {
			description: 'TSV file directory, output from computePoorCoverage, done with the same BAM and the same intervalBedFile',
			category: 'Required'
		}
		CoverageFile: {
			description: 'TSV file, output from computeCoverage, done with the same BAM and the same intervalBedFile',
			category: 'Required'
		}
		BedtoolsLowCoverage: {
			description: 'Limit value for define cow coverage target [default = 10]',
			category: 'Optional value'
		}
		BedToolsSmallInterval: {
			description: 'Limit value for define max size for tagging poor coverage area [default = 5]',
			category: 'Optional value'
		}
		genomeVersion: {
			description: 'Genome version used [default = hg19]',
			category: 'Optional value'
		}
		outputPath: {
			description: 'Path for outputFile [default = ./]',
			category: 'Optional value'
		}
		name: {
			description: 'Sample Name, if not supply infered form bam file name',
			category: 'Optional value'
		}
		ext: {
			description: 'extension for outputFile [default = .PoorCoverage_extended.tsv]',
			category: 'Optional value'
		}
		apptainer_img: {
			description: 'Sets the apptainer image you want to use [default: bedtools:XXX]',
			category: 'System'
		}
	}
}

task computeCoverage {
	meta {
		author: "Olivier ARDOUIN"
		email: "o-ardouin(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2021-10-11"
	}

	input {

		File bedCovFile

		String? outputPath
		String? name

		String ext = ".Coverage.tsv"

		String awkExe = "awk"
		String sortExe = "sort"

		Int threads = 1
		Int memory
		String apptainer_img = "bedtools:XXX"
	}

	String? baseName = if defined(name) then name else sub(basename(bedCovFile),".bed","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<

		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{sortExe} -k1,1 -k2,2n -k3,3n ~{bedCovFile} \
		| ~{awkExe} 'BEGIN {OFS="\t"}{a=($3-$2+1);b=($7/a);print $1,$2,$3,$4,b,"+","+"}' \
		> "~{outputFile}"

	>>>

	output {
		File TsvCoverageFile = "~{outputFile}"
	}

	runtime {
		cpu: threads
		requested_memory_mb_per_core: memory
		container: "~{apptainer_img}"
	}
}

task computeCoverageClamms {
	meta {
		author: "Olivier ARDOUIN"
		email: "o-ardouin(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2021-10-11"
	}

	input {
		File bedCovFile

		String? outputPath
		String? name

		String ext = ".coverage.bed"

		String awkExe = "awk"
		String sortExe = "sort"

		Int threads = 1
		Int memory
		String apptainer_img = "bedtools:XXX"
	}

	String? baseName = if defined(name) then name else sub(basename(bedCovFile),".bed","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<

		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{sortExe} -k1,1 -k2,2n -k3,3n ~{bedCovFile} \
		| ~{awkExe} '{ printf "%s\t%d\t%d\t%.6g\n", $1, $2, $3, $NF/($3-$2); }' \
		> "~{outputFile}"

	>>>

	output {
		File ClammsCoverageFile = "~{outputFile}"
	}

	runtime {
		cpu: threads
		requested_memory_mb_per_core: memory
		container: "~{apptainer_img}"
	}
}

task BamReadByChromosomes {
	meta {
		author: "Olivier ARDOUIN"
		email: "o-ardouin(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2021-10-11"
	}

	input {
		File in

		String? outputPath
		String? name

		String ext = ".readByChrom.tsv"

		String samtoolsExe = "samtools"
		String cutExe = "cut"
		String uniqExe = "uniq"

		Int threads = 1
		Int memory
		String apptainer_img = "bedtools:XXX"
	}

	String? baseName = if defined(name) then name else sub(basename(in),"(.*)\\.(sam|bam|cram)$","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<
		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{samtoolsExe} view ~{in} \
		| ~{cutExe} -f 3 \
		| ~{uniqExe} -c \
		> "~{outputFile}"
	>>>

	output {
		File ReadCountByChrom = "~{outputFile}"
	}

	runtime {
		cpu: threads
		requested_memory_mb_per_core: memory
		container: "~{apptainer_img}"
	}
}
