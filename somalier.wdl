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
    version: "0.0.4"
    date: "2024-03-14"
  }

	input {
		String path_exe = "somalier"
		Array[File]+ somalier_extracted_files
		File? ped
		String outputPath = "./somalier_relate"
        String csvtkExe = "csvtk"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String ped_or_infer = if defined(ped) then "--ped=uniq_samplID.ped" else "--infer"
	String relateSamplesFile = "~{outputPath}.samples.tsv"
	String relatePairsFile = "~{outputPath}.pairs.tsv"

	command <<<
		set -eou pipefail

		# Bellow condition should be:
		# * Empty string, if 'ped' NOT defined -> if FALSE -> do NOT run 'csvtk uniq'
		# * Not empty string, if 'ped' defined -> if TRUE -> RUN 'csvtk uniq'
		if [ -n "~{'' + ped}" ] ; then
			## 'somalier relate' does not allow duplicate sampleID in PED (case for pooled parents)
			# -> Uniq by sampleID (= column #2)
			"~{csvtkExe}" uniq \
				--tabs --comment-char '$' \
				--fields 2 \
				-o uniq_samplID.ped \
				"~{ped}"
		fi

		## Run 'somalier relate'
		"~{path_exe}" relate \
			~{ped_or_infer} \
			--output-prefix="~{outputPath}" \
			~{sep=" " somalier_extracted_files}
	>>>

	output {
		File RelateSamplesFile = relateSamplesFile
        File RelatePairsFile = relatePairsFile
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
		csvtkExe: {
			description: 'Path to csvtk executable [default: csvtk]',
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


task relatePostprocess {
	meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version: "0.0.1"
    date: "2024-06-21"
  }

	input {
		File relateSamplesFile
		File relatePairsFile
		File? ped
		String outputPath = "./somalier_relate"
		String csvtkExe = "csvtk"

		Int threads = 1
		Int memoryByThreads = 768
		String? memory
	}

	String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
	Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
	Int memoryValue = sub(totalMem, "M|G", "")
	Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
	Int memoryByThreadsMb = floor(totalMemMb/threads)

	String customSamplesFile = "~{outputPath}.custom.tsv"
	String relateFilteredPairs = "~{outputPath}.filtered.tsv"

	command <<<
		set -eoux pipefail

		## A) Post-process 'relate.samples.tsv' to create a custom one with more info:
		temp_custom=somalier_relate.custom.tmp  # Prefix of temporary file

		# ...With expected ploidy (if NO input PED provided, default value = -9):
		ploidy_tmp=expected_ploidy.tsv
		# Bellow condition should be:
		# * Empty string, if 'ped' NOT defined -> if FALSE -> do NOT run 'csvtk uniq'
		# * Not empty string, if 'ped' defined -> if TRUE -> RUN 'csvtk uniq'
		if [ -n "~{'' + ped}" ] ; then
			## Compute expected ploidy (+ rename 'frequency' column):
			"~{csvtkExe}" freq \
				--tabs --comment-char '$' \
				--fields IndivID \
				"~{ped}" |
				"~{csvtkExe}" rename \
					--tabs \
					--fields frequency --names ploidy_attendue \
					-o "$ploidy_tmp"

			# >> TEMP_SOLUCE
			#    Re-calculate expected relatedness from PED
			#    (not needed when Somalier allow duplicated sampleID if famID differ)
			recomputed_relatedness=expected_relatedness2.tsv
			sed '1s/^#//' "~{ped}" |
				awk -F"\t" '$3!=0 || $4!=0' |
				"~{csvtkExe}" mutate2 -t -n parent -e '$PereID + ";" + $MereID' |
				"~{csvtkExe}" unfold -t -s';' -f parent |
				"~{csvtkExe}" grep -t -f parent -v -p 0 |
				"~{csvtkExe}" cut -t -f IndivID,parent |
				"~{csvtkExe}" mutate2 -t -n expected_relatedness -e "'0.5'" |
				sed '1s/^/#/' > "$recomputed_relatedness"
			# << TEMP_SOLUCE

		else
			# Create dummy expected_ploidy, with only header + 1 empty row:
			# (for later join to work even for 'somalier relate --infer')
			echo -e "IndivID\tploidy_attendue\n\t" > "$ploidy_tmp"
		fi


		# ...With 'sample_id' column moved at 1st position of column order (required for multiQC):
		# (1st remove annoying '#' at beggining)
		sed '1s/^#//' "~{relateSamplesFile}" > "$temp_custom"
		"~{csvtkExe}" cut \
			--tabs \
			-f sample_id,$("~{csvtkExe}" headers -t "$temp_custom" | awk '$0 != "sample_id"' | "~{csvtkExe}" transpose) \
			-o "$temp_custom".reordered \
			"$temp_custom"

		"~{csvtkExe}" join \
			--tabs \
			--left-join --na '-9' \
			--fields 'sample_id;IndivID' \
			-o "$temp_custom".reordered.ploidy \
			"$temp_custom".reordered expected_ploidy.tsv

		# ...With new column 'estimated_ploidy' computed from different columns:
		# ENH: Instead do this through 'modify' attribute of multiQC config ?
		# MEMO: If no '-p/--pattern' provided, 'csvtk mutate' will copy column
		# INFO: Use 'csvtk round' to have estimated_ploidy as integer
		"~{csvtkExe}" mutate2 \
			--tabs \
			--expression '$n_hom_alt / ($n_hom_alt + $n_het + $n_hom_ref)' \
			--name fraction_hom_alt \
			"$temp_custom".reordered.ploidy |
				"~{csvtkExe}" mutate2 \
					--tabs \
					--name transform \
					--expression '-13.8 * $fraction_hom_alt + 5.58' \
					--at 2 |
						"~{csvtkExe}" mutate \
							--tabs \
							--fields transform \
							--name estimated_ploidy |
								"~{csvtkExe}" round \
									--tabs \
									--fields estimated_ploidy \
									--decimal-width 0 |
										"~{csvtkExe}" mutate2 \
											--tabs \
											--name valid_ploidy \
											--expression '($ploidy_attendue != -9 && $ploidy_attendue == $estimated_ploidy) ? "pass" : "fail"' \
											-o "$temp_custom".reordered.ploidy.fraction

		# ...With a column comparing 'pedigree_sex' with 'inferred_sex':
		# ENH: Instead do this through 'modify' attribute of multiQC config ?
		# MEMO: '(inferred_)sex' made by somalier does not work very_well with pools
		#       -> instead deduce sex from 'Scaled mean depth on Y'
		#       -> Cut-off is chosen so that a pool of 3 individuals with '2 F + 1 M' with will be predicted 'female'
		"~{csvtkExe}" mutate2 \
			--tabs \
			--name sexY \
			--expression '($Y_depth_mean < 0.5) ? "female" : "male"' \
			"$temp_custom".reordered.ploidy.fraction |
				"~{csvtkExe}" mutate2 \
					--tabs \
					--name valid_sex \
					--expression '($original_pedigree_sex != -9 && $original_pedigree_sex == $sexY) ? "pass" : "fail"' \
					-o "~{customSamplesFile}"

		## B) Post-process relate.pairs.tsv to create a 'filered' version of it:
		# Containing pairs with expected relatedness or high 'homozygous_concordance'
		# Can be used to highlight 'abnormal' relationships
		# (= declared in PED but low 'hom_concord' or undeclared in PED but high 'hom_concord')
		#
		# Bellow use 'csvtk mutate2 with ternary operator' to add 'pass/fail'
		# ENH: Instead do this through 'modify' attribute of multiQC config ?
		#
		# WARN: With 'expected_relatedness != -1', we would catch 'child-parent' relationships (= 0.5)
		#       But also 'sib-sib' relationships (= 0.490000...)
		#       -> As 'sib-sib' have '0.55 < hom_concord < 0.6', exclude them using 'expected_relatedness == 0.5'
		#
		# ENH: Replace expected_relatedness value by 'child-parent' (and 'sib-sib' if supported)
		# ENH: Add family_ID, when pair of well related samples
		#
		source_for_filtered="~{relatePairsFile}"

		# >> TEMP_SOLUCE
		# Replace original col 'expected_relatedness' with recomputed one:
		# WARN: Do that only if PED defined and 'pairs.tsv' has at least 1 record
		if [ -n "~{'' + ped}" ] && [ $("~{csvtkExe}" nrow -C'$' "~{relatePairsFile}") -gt 0 ] ; then
			source_for_filtered=temp_relatedness.tsv
			"~{csvtkExe}" join \
				-t -C'$' \
				--left-join --na '-1.0' \
				-f '1,2;1,2' \
				-o "$source_for_filtered" \
				<("~{csvtkExe}" cut -t -C'$' -f -expected_relatedness "~{relatePairsFile}") "$recomputed_relatedness"
		fi
		# << TEMP_SOLUCE

		sed '1s/^#//' "$source_for_filtered" |
			"~{csvtkExe}" filter2 \
				--tabs \
				--filter '$expected_relatedness == 0.5 || $hom_concordance > 0.6' \
				--show-row-number |
				"~{csvtkExe}" mutate2 \
					--tabs \
					--name valid_relationship \
					--expression '($expected_relatedness == 0.5 && $hom_concordance > 0.6) ? "pass" : "fail"' \
					-o "~{relateFilteredPairs}"
	>>>

	output {
		File CustomSamplesFile = customSamplesFile
		File RelateFilteredPairs = relateFilteredPairs
	}

	runtime {
		cpu: "~{threads}"
		requested_memory_mb_per_core: "~{memoryByThreadsMb}"
	}

	parameter_meta {
		relateSamplesFile: {
			description: 'Path to somalier_relate samples.tsv file',
			category: 'Required'
		}
		relatePairsFile: {
			description: 'Path to somalier_relate samples.tsv file',
			category: 'Required'
		}
		outputPath: {
			description: 'Output path where files were generated. [default: pwd()]',
			category: 'Output path/name option'
		}
		ped: {
			description: 'Optional PED file (without it, familial structure is inferred)',
			category: 'Output path/name option'
		}
		csvtkExe: {
			description: 'Path to csvtk executable [default: csvtk]',
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
