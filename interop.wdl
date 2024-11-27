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

task get_version {
	meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version: "0.0.1"
    date: "2024-02-29"
  }

	input {
		String path_exe = "somalier"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	command <<<
		~{path_exe} |
			grep "version" 
	>>>

	output {
		String version = read_string(stdout())
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "${memoryByThreadsMb}"
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "somalier"]',
			category: 'System'
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

task interop2stats {
	meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version: "0.0.1"
    date: "2024-03-01"
  }

	input {
		String seqDir
		File path_exe = "/mnt/chu-ngs/Labos/Transversal/Softs/Interne/Exome/scripts/stats_exome.sh"
		String csvtkExe = "csvtk"
		String interopExe = "Softs/InterOp-1.1.15-Linux-GNU_bin/"
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

	String OutFile = "~{outputPath}/sequencing.interop.tsv"

	command <<<
		set -xeou pipefail

		if [[ ! -d "~{seqDir}" ]] ; then
			# If NO 'InterOp' dir at all -> exit without error
			# Cuz probably a 'test' run, or a 'synthetic' one (= with FastQ from different runs)
			echo "WARNING: '~{seqDir}' dir NOT FOUND"
			exit
		fi

		if [[ ! -d "~{outputPath}" ]]; then
			mkdir --parents "~{outputPath}"
		fi

		# Edit script to set correct exe for (a bit dirty):
		tmpScript=./stats_exome.sh
		sed \
			-e 's|csvtkExe=.*|csvtkExe="~{csvtkExe}"|' \
			-e 's|interopExe=.*|interopExe="~{interopExe}"|' \
			"~{path_exe}" > "$tmpScript"

		# First send to a temp file:
		tmpOut=out.tsv
		set +e  # CRUCIAL
		bash "$tmpScript" "~{seqDir}" > "$tmpOut"
		# WARN: In case of 'not valid for InterOP':
		#       -> Script should return a non-0 exit code
		#       -> But task should allow that (for external FASTQ without InterOp)
		if [[ ! -s "$tmpOut" ]] ; then
			echo "WARN: Script exited with error -> IGNORE IT"
			echo "(mostly due to invalid 'InterOp' dir. See stderr for details)"
			exit
		fi
		# And if no error, move it as outFile:
		mv --verbose "$tmpOut" "~{OutFile}"
	>>>

	output {
		File? outFile = OutFile
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "~{memoryByThreadsMb}"
	}

	parameter_meta {
		seqDir: {
			description: '/path/to/input/sequencing/dir (eg.: <NAS>/Runs/221021_M02960_0624_000000000-KKH76)',
			category: 'Required'
		}
		path_exe: {
			description: 'Path to script [default: "/path/to/prod/Exome/code"]',
			category: 'System'
		}
		outputPath: {
			description: 'Output path where files were generated. [default: pwd()]',
			category: 'Output path/name option'
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
