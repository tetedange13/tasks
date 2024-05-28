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
		date: "2024-05-28"
	}

	input {
		File scriptPed
		File PedFile
		String pythonExe = "python3"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	# WARN: Have to be a 'String' here (and not a 'File')
	String propositusJson = "propositus.json"
	String parentsJson = "parents.json"
	String siblingsJson = "siblings.json"

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)
	# Create tmp JSON and load them as variable
	# See: https://bioinformatics.stackexchange.com/a/19073

	command <<<
		set -exo pipefail

		# Simply run dedicated script on input PED:
		# (pythonExe should have 'peds' package installed)
		"~{pythonExe}" "~{scriptPed}" "~{PedFile}"
	>>>

	output {
		Array[Array[String]] propositus = read_json(propositusJson)
		Array[Array[String]] siblings = read_json(siblingsJson)
		Array[String] parents = read_json(parentsJson)
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}
}


task FALSEpedToParam {
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
	Int memoryValue = sub(totalMem, "M|G", "")
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
		Array[Array[String]] propositus = read_json(propositusJson)
		Array[Array[String]] siblings = read_json(siblingsJson)
		Array[String] parents = read_json(parentsJson)
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreads}"
	}
}


task pedToParam_ALT {
	meta {
		author: "Felix Vandermeeren"
		email: "felix.vandermeeren(at)chu-montpellier.fr"
		version: "0.0.2"
		date: "2024-01-22"
	}

	input {
		String PedFile
		Array[Array[String]] propositus
		Array[Array[String]] siblings
		Array[String] parents

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
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)
	# Create tmp JSON and load them as variable
	# See: https://bioinformatics.stackexchange.com/a/19073

	command <<<
		set -exo pipefail

		# If PedFile is still 'empty str' (= its default value)
		# -> Write user defined vars 'Parents', 'Propositus' etc to a (tmp) JSON
		# WARN: write_json produce a temp file -> rename it 'var_name.json'
		if [ -z "~{PedFile}" ] ; then
			mv ~{write_json(propositus)} "~{propositusJson}"
			mv ~{write_json(siblings)} "~{siblingsJson}"
			mv ~{write_json(parents)} "~{parentsJson}"

		else  # Otherwise use PedFile to define vars 'Parents', 'Propositus' etc
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
		fi
	>>>

	output {
		File PropositusJson = propositusJson
		File SiblingsJson = siblingsJson
		File ParentsJson = parentsJson
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
	# ENH: Add varName to output file ?
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
		String outputPath = "./"
		Array[File] filesToGather
		String csvtkExe = "csvtk"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String OutFile = "~{outputPath}/" + "all_casIndex_identito.tsv"
	String nb_files = length(filesToGather)

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	command <<<
		set -eou pipefail

		# If no 'Identito' files -> Simply create empty file and exit without error
		if [ ~{nb_files} -eq 0 ] ; then
			touch "~{OutFile}"
			exit
		fi

		if [[ ! -d "~{outputPath}" ]]; then
			mkdir --parents "~{outputPath}"
		fi

		if [ ~{nb_files} -eq 1 ] ; then
			cut --fields 1,2 ~{sep='' filesToGather} > "~{OutFile}"

		else
			# First keep only 1st col of casIndex:
			# WARN: What if casIndex is in 1st col ?
			#       IDEA: Use 'csvtk grep'
			for a_file in ~{sep=' ' filesToGather}; do echo $a_file ; done |
				awk -F"/" '{print "cut -f1,2",$0,">",$NF}' |
				bash

			# Then join intermediate files:
			"~{csvtkExe}" join --tabs -o "~{OutFile}" ./*.Identito.tsv
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
