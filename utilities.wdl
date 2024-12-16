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

task findFiles {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2021-04-28"
	}

	input {
		String path

		String? regexpName
		String? regexpPath

		Int? maxDepth
		Int? minDepth

		Int? uid
		Int? gid

		Boolean readable = false
		Boolean writable = false
		Boolean executable = false

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String regexpNameOpt = if defined(regexpName) then "-name \"~{regexpName}\" " else ""
	String regexpPathOpt = if defined(regexpPath) then "-path \"~{regexpPath}\" " else ""

	command <<<

		find ~{path} \
			~{default="" "-maxdepth " + maxDepth} \
			~{default="" "-mindepth " + minDepth} \
			~{default="" "-uid " + uid} \
			~{default="" "-gid " + gid} \
			~{true="-readable" false="" readable} \
			~{true="-writable" false="" writable} \
			~{true="-executable" false="" executable} \
			~{regexpPathOpt} \
			~{regexpNameOpt}

	>>>

	output {
		Array[File] files = read_lines(stdout())
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
	}

	parameter_meta {
		path: {
			description: "Path where find will work on.",
			category: 'Required'
		}
		regexpName: {
			description: "Base of file name (the path with the leading directories removed) matches shell pattern pattern.",
			category: 'Tool option'
		}
		regexpPath: {
			description: "File name matches shell pattern pattern. The metacharacters do not treat `/' or `.' specially.",
			category: 'Tool option'
		}
		maxDepth: {
			description: "Descend at most levels (a non-negative integer) levels of directories below the starting-points.",
			category: 'Tool option'
		}
		minDepth: {
			description: "Do not apply any tests or actions at levels less than levels (a non-negative integer).",
			category: 'Tool option'
		}
		uid: {
			description: "File's numeric user ID is n.",
			category: 'Tool option'
		}
		gid: {
			description: "File's numeric group ID is n.",
			category: 'Tool option'
		}
		readable: {
			description: "Matches files which are readable.",
			category: 'Tool option'
		}
		writable: {
			description: "Matches files which are writable.",
			category: 'Tool option'
		}
		executable: {
			description: "Matches files which are executable and directories which are searchable (in a file name resolution sense).",
			category: 'Tool option'
		}
		threads: {
			description: 'Sets the number of threads [default: 1]',
			category: 'System'
		}
		memory: {
			description: 'Sets the total memory to use ; with suffix M/G [default: (memoryByThreads*threads)M]',
			category: 'System'
		}
		memoryByThreads: {
			description: 'Sets the total memory to use (in M) [default: 768]',
			category: 'System'
		}
	}
}

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
		String AwkExe = "awk"
		String SortExe = "sort"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String baseName = if defined(name) then name else sub(basename(BamFile),"(.*)\.(sam|bam|cram)$","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<
		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{BedToolsExe} genomecov -ibam ~{BamFile} -bga \
		| ~{AwkExe} -v low_coverage="~{BedtoolsLowCoverage}" '$4<low_coverage' \
		| ~{BedToolsExe} intersect -a ~{IntervalBedFile} -b - \
		| ~{SortExe} -k1,1 -k2,2n -k3,3n \
		| ~{BedToolsExe} merge -c 4 -o distinct -i - \
		| ~{AwkExe} -v small_intervall="~{BedToolsSmallInterval}" \
		'BEGIN {OFS="\t";print "#chr","start","end","region","size bp","type","UCSC link"} {a=($3-$2+1);if(a<small_intervall) {b="SMALL_INTERVAL"} else {b="OTHER"};url="http://genome-euro.ucsc.edu/cgi-bin/hgTracks?db='~{GenomeVersion}'&position="$1":"$2-10"-"$3+10"&highlight='~{GenomeVersion}'."$1":"$2"-"$3;print $0, a, b, url}' > "~{outputFile}"
	>>>

	output {
		File poorCoverageFile = "~{outputFile}"
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
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

		File BedCovFile

		String? outputPath
		String? name

		String ext = ".Coverage.tsv"

		String AwkExe = "awk"
		String SortExe = "sort"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String baseName = if defined(name) then name else sub(basename(BedCovFile),".bed","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<
		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{SortExe} -k1,1 -k2,2n -k3,3n ~{BedCovFile} \
		| ~{AwkExe} 'BEGIN {OFS="\t"}{a=($3-$2+1);b=($7/a);print $1,$2,$3,$4,b,"+","+"}' \
		> "~{outputFile}"
	>>>
	output {
		File TsvCoverageFile = "~{outputFile}"
	}
	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
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
		Int memoryByThreads = 768
		String? memory
	}

	String baseName = if defined(name) then name else sub(basename(BamFile),"(.*)\.(sam|bam|cram)$","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

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
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
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
		File BedCovFile

		String? outputPath
		String? name

		String ext = ".coverage.bed"

		String AwkExe = "awk"
		String SortExe = "sort"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String baseName = if defined(name) then name else sub(basename(BedCovFile),".bed","$1")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<
		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{SortExe} -k1,1 -k2,2n -k3,3n ~{BedCovFile} \
		| ~{AwkExe} '{ printf "%s\t%d\t%d\t%.6g\n", $1, $2, $3, $NF/($3-$2); }' \
		> "~{outputFile}"
	>>>
	output {
		File ClammsCoverageFile = "~{outputFile}"
	}
	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
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
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String baseName = if defined(name) then name else sub(basename(in),"(.*)\.(sam|bam|cram)$","$1")
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
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
	}
}

task printSoftVersion {
	meta {
		author: "Olivier ARDOUIN"
		email: "o-ardouin(at)chu-montpellier.fr"
		version: "0.0.3"
		date: "2022-08-31"
	}

	input {
		Array[String] Soft
		String outFile

		Boolean Append = false

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String to = if Append then ">>" else ">"

	command <<<
		set exo pipefail
		if [[ ! -d $(dirname ~{outFile}) ]]; then
			mkdir -p $(dirname ~{outFile})
		fi
		date ~{to} ~{outFile}
		echo -e "~{sep='\n---\n' Soft}" >> ~{outFile}
		echo "----" >> ~{outFile}
	>>>

	output {
		File out = "~{outFile}"
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
	}
}

task mkDir {
	meta {
		author: "Olivier Ardouin"
		email: "o-ardouin(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2022-08-22"
	}

	input {
		String outputPath

		Int threads = 1
		Int memoryByThreads = 768
	}

	command <<<
		set -exo pipefail
		if [[ ! -d "~{outputPath}" ]]; then mkdir -p "~{outputPath}"; fi
	>>>

	output {
		Boolean DirCreated = true
		String output_Path = "~{outputPath}"
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}

	parameter_meta {
		outputPath: {
			description: 'Path of the directory to create',
			category: 'Output path/name option'
		}
		threads: {
			description: 'Sets the number of threads [default: 1]',
			category: 'System'
		}
		memoryByThreads: {
			description: 'Sets the total memory to use (in M) [default: 768]',
			category: 'System'
		}
	}
}

task checksum {
	meta {
		author: "Felix Vandermeeren"
		email: "felix.vandermeeren(at)chu-montpellier.fr"
		version: "0.0.5"
		date: "2024-01-10"
	}

	input {
		Array[File]+ filesToCheck
		String path_exe = "md5sum"
		String outputPath = "./"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String OutFile = "~{outputPath}/Checksums.txt"

	# ENH: Find a way to quote optional variables correctly ?
	# Format of (tab-separated) outfile MUST be as follow:
	# (otherwise corresponding section in 'custom multiQC' will be broken)
	# - Header = fileName ; md5sum
	# - Example_value = hg19.fa ; 7c1739fd43764bd5e3b9b76ce8635bf0

	command <<<
		set -eou pipefail

		if [[ ! -d "~{outputPath}" ]]; then
			mkdir --parents "~{outputPath}"
		fi

		echo ~{sep=" " filesToCheck} |
			xargs --max-args=1 --max-procs "~{threads}" "~{path_exe}" |
			sed 's/  /\t/' |
			awk -F"\t" -v OFS="\t" '{n=split($2,a,"/"); print a[n],$1}' |
			sort -k1,1 |
			sed '1i fileName\tmd5sum' > "~{OutFile}"
	>>>

	output {
		File outFile = OutFile
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}
}

task gatherIdentito {
	meta {
		author: "Felix Vandermeeren"
		email: "felix.vandermeeren(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2024-01-22"
	}

	input {
		Array[File] filesToGather
		String outputPath = "./"
		String csvtkExe = "csvtk"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String OutFile = "~{outputPath}/" + "all_casIndex.identito.tsv"
	String nb_files = length(filesToGather)

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	command <<<
		set -xeuo pipefail

		if [[ ! -d "~{outputPath}" ]]; then
			mkdir --parents "~{outputPath}"
		fi

		# If only 1 file --> simply transform it:
		if [ ~{nb_files} -eq 1 ] ; then
			cat ~{sep='' filesToGather} |
				"~{csvtkExe}" replace --tabs --fields -GENE --ignore-case --pattern 'Not Found' --replacement 'WT' |
				"~{csvtkExe}" replace --tabs --fields -GENE --pattern '0/0' --replacement 'WT' |
				"~{csvtkExe}" replace --tabs --fields -GENE --pattern '0/1' --replacement 'HTZ' |
				"~{csvtkExe}" replace --tabs --fields -GENE --pattern '1/1' --replacement 'MUT' |
				"~{csvtkExe}" transpose --tabs |
				"~{csvtkExe}" grep \
									--tabs \
									--fields GENE \
									--ignore-case --use-regexp --pattern "^pool" --invert \
									-o "~{OutFile}"

		else
			# Otherwise, join input files then transform:
			# MEMO: Bellow one-liner 'for' is used to list elements from WDL Array
			for a_file in ~{sep=' ' filesToGather}; do echo $a_file ; done |
				xargs "~{csvtkExe}" join --tabs --fields GENE |
				"~{csvtkExe}" replace --tabs --fields -GENE --ignore-case --pattern 'Not Found' --replacement 'WT' |
				"~{csvtkExe}" replace --tabs --fields -GENE --pattern '0/0' --replacement 'WT' |
				"~{csvtkExe}" replace --tabs --fields -GENE --pattern '0/1' --replacement 'HTZ' |
				"~{csvtkExe}" replace --tabs --fields -GENE --pattern '1/1' --replacement 'MUT' |
				"~{csvtkExe}" transpose --tabs |
				"~{csvtkExe}" grep \
									--tabs \
									--fields GENE \
									--ignore-case --use-regexp --pattern "^pool" --invert \
									-o "~{OutFile}"
		fi
	>>>

	output {
		File outFile = OutFile
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}
}
