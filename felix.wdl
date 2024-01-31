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
