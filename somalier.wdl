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

task extract {
	meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version: "0.0.1"
    date: "2024-03-01"
  }

	input {
		String path_exe = "somalier"
		# ENH: Download correct file depending on 'genome' variable
		# WARN: Download from URL not supported by cromwell on cluster ?
		#       -> Use local file instead
		# WARN2: Once extracted, '.somalier' files are genome-build-agnostic
		#       See 'sites files' section of release
		File sites = "/mnt/chu-ngs/refData/igenomes/Homo_sapiens/GATK/GRCh37/Annotation/Somalier/sites.hg19.vcf.gz"
		String refFasta
		File bamFile
		File bamIdx  # Somalier requires BAM to be indexed
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

	# ENH: Define Outfile correctly (sample.bam -> sample.somalier)
	#      And define it in 'output' section

	command <<<
		set -eou pipefail

		if [[ ! -d ~{outputPath} ]]; then
			mkdir --parents ~{outputPath}
		fi
		
		"~{path_exe}" extract \
			--sites="~{sites}" \
			--fasta="~{refFasta}" \
			--out-dir="~{outputPath}" \
			"~{bamFile}"
	>>>

	output {
		File file = "~{outputPath}/" + basename(bamFile, ".bam") + ".somalier"
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "~{memoryByThreadsMb}"
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "somalier"]',
			category: 'System'
		}
		outputPath: {
			description: 'Output path where files were generated. [default: pwd()]',
			category: 'Output path/name option'
		}
		sites: {
			description: 'Sites used by Somalier [default: URL]',
			category: 'Output path/name option'
		}
		refFasta: {
			description: 'Path to reference genome fasta',
			category: 'Required'
		}
		bamFile: {
			description: 'Path to input BAM file',
			category: 'Required'
		}
		bamIdx: {
			description: 'Path to BAM index of input BAM file',
			category: 'Required'
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


task relate {
	meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version: "0.0.1"
    date: "2024-03-14"
  }

	input {
		String path_exe = "somalier"
		Array[File]+ somalier_extracted_files
		File? ped
		String outputPath = "./run_name"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String ped_or_infer = if defined(ped) then "--ped=~{ped}" else "--infer"
	# ENH: Define Outfile correctly (sample.bam -> sample.somalier)
	#      And define it in 'output' section

	command <<<
		set -eou pipefail

		"~{path_exe}" relate \
			~{ped_or_infer} \
			--output-prefix="~{outputPath}" \
			~{sep=" " somalier_extracted_files}
	>>>

	output {
		File file = "~{outputPath}.samples.tsv"
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "~{memoryByThreadsMb}"
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "somalier"]',
			category: 'System'
		}
		outputPath: {
			description: 'Output path where files were generated. [default: pwd()]',
			category: 'Output path/name option'
		}
		somalier_extracted_files: {
			description: 'Array of "/path/to/sample.somalier" files (obtained with "somalier extract" cmd)',
			category: 'Required'
		}
		ped: {
			description: 'Optional PED file (without it, familial structure is inferred)',
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
