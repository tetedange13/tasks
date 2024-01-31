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


task pedToParam {
	meta {
		author: "Felix Vandermeeren"
		email: "felix.vandermeeren(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2024-01-22"
	}

	input {
		File PedFile

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String pythonExe = "python3"
	# WARN: Have to be a 'String' here (and not a 'File')
	String propositusJson = "propositus.json"
	String parentsJson = "parents.json"
	String siblingsJson = "siblings.json"

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)
	# Create tmp JSON and load them as variable
	# See: https://bioinformatics.stackexchange.com/a/19073

	command <<<
		set exo pipefail

		# 'Propositus' var:
		{
			echo "with open('~{PedFile}', 'r', encoding='latin') as my_file: common = [x.rstrip(',').replace(',','\t') for x in my_file.read().splitlines() if x != '\t\t\t']"
			echo "print(list(map(lambda x: list(filter(''.__ne__, x.split('\t')[0:3])), common))[1:])"
		} | "~{pythonExe}" | tr "'" '"' > "~{propositusJson}"

		# 'Parents' var:
		{
			echo "with open('~{PedFile}', 'r', encoding='latin') as my_file: common = [x.rstrip(',').replace(',','\t') for x in my_file.read().splitlines() if x != '\t\t\t']"
			echo "print(list(dict.fromkeys(sum(map(lambda x: list(filter(''.__ne__, x.split('\t')[1:])), common[1:]), []))))"
		} | "~{pythonExe}" | tr "'" '"' > "~{parentsJson}"

		# 'Siblings' var: 
		{
			echo "with open('~{PedFile}', 'r', encoding='latin') as my_file: common = [x.rstrip(',').replace(',','\t') for x in my_file.read().splitlines() if x != '\t\t\t']"
			echo "print([ [x.split('\t')[1], x.split('\t')[3]] for x in common[1:] if x.split('\t')[3] ])"
		} | "~{pythonExe}" | tr "'" '"' > "~{siblingsJson}"
	>>>

	output {
		File propositusJson = propositusJson
		File parentsJson = parentsJson
		File siblingsJson = siblingsJson
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}
}


task checksum {
	meta {
		author: "Felix Vandermeeren"
		email: "felix.vandermeeren(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2024-01-10"
	}

	input {
		String outputPath

		# Bed input
		File TargetBed
		File? BaitBed
		File? Genemap2File
		File WindowsBed
		File? WindowsBedNoCHR

		# Genome input
		File refFasta
		File refDict
		File refFai
		File refAmb
		File refAnn
		File refBwt
		File refPac
		File refSa

		# Known sites (/!\ Except flattenned arrays)
		Array[File?]+ knownSites
		Array[File?]+ knownSitesIdx
		# dbSNP
		File dbsnp
		File dbsnpIdx

		## experiment inputs
		File? GenesOfInterest
		File? CustomVCF

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem,"([0-9]+)(M|G)", "$1")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)


	String path_exe = "sha256sum"
	String outputFile = "~{outputPath}/Checksums.txt"

	# Handle optional support files:
	String cmd_BaitBed = if defined(BaitBed) then "~{path_exe} ~{BaitBed}" else ""
	String cmd_Genemap2File = if defined(Genemap2File) then "~{path_exe} ~{Genemap2File}" else ""
	String cmd_WindowsBedNoCHR = if defined(WindowsBedNoCHR) then "~{path_exe} ~{WindowsBedNoCHR}" else ""
	String cmd_GenesOfInterest = if defined(GenesOfInterest) then "~{path_exe} ~{GenesOfInterest}" else ""
	String cmd_CustomVCF = if defined(CustomVCF) then "~{path_exe} ~{CustomVCF}" else ""
	# WARN: knownSites is an array -> use 'sep' bellow
	String cmd_knownSites = if defined(knownSites) then "~{path_exe} ~{sep=' ' knownSites}" else ""
	String cmd_knownSitesIdx = if defined(knownSitesIdx) then "~{path_exe} ~{sep=' ' knownSitesIdx}" else ""
	# WARN: Input path of each file became internal one (copied by WDL) -> basename with awk

	command <<<
		set exo pipefail

		if [[ ! -d "~{outputPath}" ]]; then
			mkdir --parents "~{outputPath}"
		fi
		echo ~{cmd_knownSitesIdx}

		{
			"~{path_exe}" \
				"~{TargetBed}" \
				"~{WindowsBed}"
			~{cmd_BaitBed}
			~{cmd_Genemap2File}
			~{cmd_WindowsBedNoCHR}
			"~{path_exe}" \
				"~{refFasta}" \
				"~{refDict}" \
				"~{refFai}" \
				"~{refAmb}" \
				"~{refAnn}" \
				"~{refBwt}" \
				"~{refPac}" \
				"~{refSa}"
			# ~{cmd_knownSites}
			# ~{cmd_knownSitesIdx}
			~{cmd_GenesOfInterest}
			~{cmd_CustomVCF}
		} | sed 's/  /\t/' | awk -F"\t" -v OFS="\t" '{n=split($2,a,"/"); print $1,a[n]}' > "~{outputFile}"
	>>>

	output {
		File outputFile = outputFile
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}
}
