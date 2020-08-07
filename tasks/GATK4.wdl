version 1.0

task reorderSam {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2020-07-27"
	}

	input {
		String path_exe = "gatk"
		Array[String]? javaOptions

		File in
		String outputPath
		String? prefix
		String ext = ".bam"
		String suffix = "reorder"
		File sequenceDict

		Boolean allowIncompleteLengthDiscordance = false
		Boolean allowIncompleteDictDiscordance = false
		Int compressionLevel = 2
		Boolean createIndex = false
		Boolean createMD5 = false
		File? GA4GHClientSecrets
		Int maxRecordsInRam = 500000
		File? referenceSequence

		Boolean quiet = false
		File? tmpDir
		Boolean useJDKDeflater = false
		Boolean useJDKInflater = false
		String validationStringency = "STRICT"
		String verbosity = "INFO"
		Boolean showHidden = false
	}

	String GA4GHClientSecretsOpt = if defined(GA4GHClientSecrets) then "--GA4GH_CLIENT_SECRETS ~{GA4GHClientSecrets} " else ""
	String referenceSequenceOpt = if defined(referenceSequence) then "--REFERENCE_SEQUENCE ~{referenceSequence} " else ""

	String outputName = if defined(prefix) then "~{prefix}.~{suffix}~{ext}" else basename(in,ext) + ".~{suffix}~{ext}"
	String outputFile = "~{outputPath}/~{outputName}"

	command <<<

		if [[ ! -f ~{outputFile} ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{path_exe} ReorderSam ~{GA4GHClientSecrets}~{referenceSequenceOpt} \
			--java-options '~{sep=" " javaOptions}' \
			--ALLOW_CONTIG_LENGTH_DISCORDANCE '~{allowIncompleteLengthDiscordance}' \
			--ALLOW_INCOMPLETE_DICT_CONCORDANCE '~{allowIncompleteDictDiscordance}' \
			--COMPRESSION_LEVEL ~{compressionLevel} \
			--CREATE_INDEX '~{createIndex}' \
			--CREATE_MD5_FILE '~{createMD5}' \
			--MAX_RECORDS_IN_RAM ~{maxRecordsInRam} \
			--QUIET '~{quiet}' \
			--TMP_DIR ~{default='null' tmpDir} \
			--USE_JDK_DEFLATER '~{useJDKDeflater}' \
			--USE_JDK_INFLATER '~{useJDKInflater}' \
			--VALIDATION_STRINGENCY '~{validationStringency}' \
			--VERBOSITY ~{verbosity} \
			--showHidden ~{showHidden} \
			--INPUT ~{in} \
			--SEQUENCE_DICTIONARY ~{sequenceDict} \
			--OUTPUT ~{outputFile}

	>>>

	output {
		File outputFile = "~{outputFile}"
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "gatk"]',
			category: 'optional'
		}
		in: {
			description: 'Input file (SAM or BAM) to extract reads from..',
			category: 'Required'
		}
		outputPath: {
			description: 'Output path where file (SAM or BAM) were generated.',
			category: 'Required'
		}
		ext: {
			description: 'Extension of the input file (".sam" or ".bam") [default: ".bam"]',
			category: 'optional'
		}
		prefix: {
			description: 'Prefix for the output file [default: basename(in, ext)]',
			category: 'optional'
		}
		suffix: {
			description: 'Suffix for the output file (e.g. sample.suffix.bam) [default: "reorder"]',
			category: 'optional'
		}
		sequenceDict: {
			description: 'Sequence Dictionary for the OUTPUT file (can be read from one of the following file types (SAM, BAM, VCF, BCF, Interval List, Fasta, or Dict)',
			category: 'Required'
		}
		allowIncompleteLengthDiscordance: {
			description: 'If true, then permits mapping from a read contig to a new reference contig with the same name but a different length.  Highly dangerous, only use if you know what you are doing. [Default: false]',
			category: 'optional'
		}
		allowIncompleteDictDiscordance: {
			description: 'If true, allows only a partial overlap of the original contigs with the new reference sequence contigs.  By default, this tool requires a corresponding contig in the new reference for each read contig. [Default: false]',
			category: 'optional'
		}
		compressionLevel: {
			description: 'Compression level for all compressed files created (e.g. BAM and VCF). [default: 2]',
			category: 'optional'
		}
		createIndex: {
			description: 'Whether to create a BAM index when writing a coordinate-sorted BAM file. [Default: false]',
			category: 'optional'
		}
		createMD5: {
			description: 'Whether to create an MD5 digest for any BAM or FASTQ files created. [Default: false]',
			category: 'optional'
		}
		GA4GHClientSecrets: {
			description: 'Google Genomics API client_secrets.json file path. [Default: null]',
			category: 'optional'
		}
		maxRecordsInRam: {
			description: 'When writing files that need to be sorted, this will specify the number of records stored in RAM before spilling to disk. Increasing this number reduces the number of file handles needed to sort the file, and increases the amount of RAM needed. [Default: 500000]',
			category: 'optional'
		}
		referenceSequence: {
			description: 'Reference sequence file. [Default: null]',
			category: 'optional'
		}
		quiet: {
			description: 'Whether to suppress job-summary info on System.err. [Default: false]',
			category: 'Common options'
		}
		tmpDir: {
			description: 'Path to a directory with space available to be used by this program for temporary storage of working files. [Default: null]',
			category: 'Common options'
		}
		useJDKDeflater: {
			description: 'Use the JDK Deflater instead of the Intel Deflater for writing compressed output. [Default: false]',
			category: 'Common options'
		}
		useJDKInflater: {
			description: 'Use the JDK Inflater instead of the Intel Inflater for reading compressed input. [Default: false]',
			category: 'Common options'
		}
		validationStringency: {
			description: ' Validation stringency for all SAM files read by this program.  Setting stringency to SILENT can improve performance when processing a BAM file in which variable-length data (read, qualities, tags) do not otherwise need to be decoded. [Default: "STRIC"]',
			category: 'Common options'
		}
		verbosity: {
			description: 'Control verbosity of logging. [Default: "INFO"]',
			category: 'Common options'
		}
		showHidden: {
			description: 'Display hidden arguments. [Default: false]',
			category: 'Common options'
		}
	}
}

### WARNING : depthOfCoverage is on BETA
## 		--calculate-coverage-over-genes,-gene-list: option seems not working
##			properly : https://github.com/broadinstitute/gatk/issues/6714
##		--count-type: only "COUNT_READS" is supported
task depthOfCoverage {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.1b"
		date: "2020-07-27"
	}

	input {
		String path_exe = "gatk"
		Array[String]? javaOptions

		File in
		File intervals
		String outputPath
		String? prefix
		String ext = ".bam"
		String suffix = "DoC"
		File referenceFasta
		File referenceFai
		File referenceDict

		File? geneList
		String countType = "COUNT_READS"
		Boolean disableBamIndexCaching = false
		Boolean disableSequenceDictionaryValidation = false
		String intervalMergingRule = "ALL"
		Int maxBaseQuality = 127
		Int minBaseQuality = 0
		Int maxDepthPerSample = 0
		String outputFormat = "CSV"
		String partitionType = "sample"
		Boolean printBaseCounts = false

		Boolean quiet = false
		File? tmpDir
		Boolean useJDKDeflater = false
		Boolean useJDKInflater = false
		String validationStringency = "SILENT"
		String verbosity = "INFO"
		Boolean showHidden = false

		Array[Int] summaryCoverageThreshold = [5]
	}

	Array[String] summaryCoverageThresholdOpt = prefix("--summary-coverage-threshold ", summaryCoverageThreshold)

	String outputName = if defined(prefix) then "~{prefix}.~{suffix}" else basename(in,ext) + ".~{suffix}"
	String outputFile = "~{outputPath}/~{outputName}"

	command <<<

		if [[ ! -f ~{outputFile} ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi


		~{path_exe} DepthOfCoverage \
			--java-options '~{sep=" " javaOptions}' \
			--calculate-coverage-over-genes ~{default='null' geneList} \
			--count-type ~{countType} \
			--disable-bam-index-caching ~{disableBamIndexCaching} \
			--disable-sequence-dictionary-validation ~{disableSequenceDictionaryValidation} \
			--interval-merging-rule ~{intervalMergingRule} \
			--max-base-quality ~{maxBaseQuality} \
			--max-depth-per-sample ~{maxDepthPerSample} \
			--min-base-quality ~{minBaseQuality} \
			--output-format ~{outputFormat} \
			--partition-type ~{partitionType} \
			--print-base-counts ~{printBaseCounts} \
			--QUIET '~{quiet}' \
			--use-jdk-deflater '~{useJDKDeflater}' \
			--use-jdk-inflater '~{useJDKInflater}' \
			--read-validation-stringency '~{validationStringency}' \
			--verbosity ~{verbosity} \
			--showHidden ~{showHidden} \
			--input ~{in} \
			--intervals ~{intervals} \
			--reference ~{referenceFasta} \
			--output ~{outputFile} \
			~{sep=" " summaryCoverageThresholdOpt}

	>>>

	output {
		File outputFile = "~{outputFile}"
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "gatk"]',
			category: 'optional'
		}
		in: {
			description: 'BAM/SAM/CRAM file containing reads.',
			category: 'Required'
		}
		intervals: {
			description: 'Path to a file containing genomic intervals over which to operate. (format intervals list: chr1:1000-2000)',
			category: 'Required'
		}
		outputPath: {
			description: 'Output path where files were generated.',
			category: 'Required'
		}
		ext: {
			description: 'Extension of the input file (".sam" or ".bam") [default: ".bam"]',
			category: 'optional'
		}
		prefix: {
			description: 'Prefix for the output file [default: basename(in, ext)]',
			category: 'optional'
		}
		suffix: {
			description: 'Suffix for the output file (e.g. prefix.suffix.bam) [default: "DoC"]',
			category: 'optional'
		}
		referenceFasta: {
			description: 'Path to the reference file (format: fasta)',
			category: 'required'
		}
		referenceFai: {
			description: 'Path to the reference file index (format: fai)',
			category: 'required'
		}
		referenceDict: {
			description: 'Path to the reference file dict (format: dict)',
			category: 'required'
		}
		geneList: {
			description: 'Calculate coverage statistics over this list of genes. (refseq format)',
			category: 'optional'
		}
		countType: {
			description: 'How should overlapping reads from the same fragment be handled? (Possible values: {COUNT_READS, COUNT_FRAGMENTS, COUNT_FRAGMENTS_REQUIRE_SAME_BASE}) [default: COUNT_READS]',
			category: 'optional'
		}
		disableBamIndexCaching: {
			description: "If true, don't cache bam indexes, this will reduce memory requirements but may harm performance if many intervals are specified. Caching is automatically disabled if there are no intervals specified. [default: false]",
			category: 'optional'
		}
		disableSequenceDictionaryValidation: {
			description: 'If specified, do not check the sequence dictionaries from our inputs for compatibility. Use at your own risk! [default: false]',
			category: 'optional'
		}
		intervalMergingRule: {
			description: 'Interval merging rule for abutting intervals. (possible values: ALL, OVERLAPPING_ONLY) [default: ALL]',
			category: 'optional'
		}
		maxBaseQuality: {
			description: 'Maximum quality of bases to count towards depth. [default: 127]',
			category: 'optional'
		}
		minBaseQuality: {
			description: 'Minimum quality of bases to count towards depth. [default: 0]',
			category: 'optional'
		}
		maxDepthPerSample: {
			description: 'Maximum number of reads to retain per sample per locus. Reads above this threshold will be downsampled. Set to 0 to disable. [default: 0]',
			category: 'optional'
		}
		outputFormat: {
			description: 'The format of the output file. (possible values: CSV, TABLE) [default: CSV]',
			category: 'optional'
		}
		partitionType: {
			description: 'Partition type for depth of coverage. (possbile values: sample, readgroup and/or library) [default: sample]',
			category: 'optional'
		}
		printBaseCounts: {
			description: 'Add base counts to per-locus output. [default: false]',
			category: 'optional'
		}
		quiet: {
			description: 'Whether to suppress job-summary info on System.err. [Default: false]',
			category: 'Common options'
		}
		tmpDir: {
			description: 'Path to a directory with space available to be used by this program for temporary storage of working files. [Default: null]',
			category: 'Common options'
		}
		useJDKDeflater: {
			description: 'Use the JDK Deflater instead of the Intel Deflater for writing compressed output. [Default: false]',
			category: 'Common options'
		}
		useJDKInflater: {
			description: 'Use the JDK Inflater instead of the Intel Inflater for reading compressed input. [Default: false]',
			category: 'Common options'
		}
		validationStringency: {
			description: ' Validation stringency for all SAM files read by this program.  Setting stringency to SILENT can improve performance when processing a BAM file in which variable-length data (read, qualities, tags) do not otherwise need to be decoded. [Default: "STRIC"]',
			category: 'Common options'
		}
		verbosity: {
			description: 'Control verbosity of logging. [Default: "INFO"]',
			category: 'Common options'
		}
		showHidden: {
			description: 'Display hidden arguments. [Default: false]',
			category: 'Common options'
		}
	}
}

task splitIntervals {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2020-08-06"
	}

	input {
		String path_exe = "gatk"

		File in
		String? outputPath
		String? name

		File refFasta
		File refFai
		File refDict

		Int scatterCount = 1
		String subdivisionMode = "INTERVAL_SUBDIVISION"
		Int intervalsPadding = 0
		Boolean overlappingRule = false
		Boolean intersectionRule = false

		Int threads = 1
	}

	String baseName = if defined(name) then name else sub(basename(in),"\.([a-zA-Z]*)$","")
	String outputRep = if defined(outputPath) then "~{outputPath}/~{baseName}" else "~{baseName}"

	command <<<

		if [[ ! -d $(dirname ~{outputRep}) ]]; then
			mkdir -p $(dirname ~{outputRep})
		fi

		~{path_exe} SplitIntervals \
			--intervals ~{in} \
			--reference ~{refFasta} \
			--scatter-count ~{scatterCount} \
			--subdivision-mode ~{subdivisionMode} \
			--interval-padding ~{intervalsPadding} \
			--interval-merging-rule ~{true="OVERLAPPING_ONLY" false="ALL" overlappingRule} \
			--interval-set-rule ~{true="INTERSECTION" false="UNION" intersectionRule} \
			--output ~{outputRep}

	>>>

	output {
		Array[File] splittedIntervals = glob("~{outputRep}/*-scattered.interval_list")
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "gatk"]',
			category: 'optional'
		}
		in: {
			description: 'Path to a file containing genomic intervals over which to operate. (format intervals list: chr1:1000-2000)',
			category: 'Required'
		}
		outputPath: {
			description: 'Output path where files were generated.',
			category: 'Required'
		}
		name: {
			description: 'Output repertory name [default: sub(basename(in),"\.([a-zA-Z]*)$","")].',
			category: 'optional'
		}
		refFasta: {
			description: 'Path to the reference file (format: fasta)',
			category: 'required'
		}
		refFai: {
			description: 'Path to the reference file index (format: fai)',
			category: 'required'
		}
		refDict: {
			description: 'Path to the reference file dict (format: dict)',
			category: 'required'
		}
		scatterCount: {
			description: 'Scatter count: number of output interval files to split into [default: 1]',
			category: 'optional'
		}
		subdivisionMode: {
			description: 'How to divide intervals {INTERVAL_SUBDIVISION, BALANCING_WITHOUT_INTERVAL_SUBDIVISION, BALANCING_WITHOUT_INTERVAL_SUBDIVISION_WITH_OVERFLOW, INTERVAL_COUNT}. [default: INTERVAL_SUBDIVISION]',
			category: 'optional'
		}
		intervalsPadding: {
			description: 'Amount of padding (in bp) to add to each interval you are including. [default: 0]',
			category: 'optional'
		}
		overlappingRule: {
			description: 'Interval merging rule for abutting intervals set to OVERLAPPING_ONLY [default: false => ALL]',
			category: 'optional'
		}
		intersectionRule: {
			description: 'Set merging approach to use for combining interval inputs to INTERSECTION [default: false => UNION]',
			category: 'optional'
		}
	}
}

task baseRecalibrator {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2020-08-06"
	}

	input {
		String path_exe = "gatk"

		File in
		File bamIdx
		String? outputPath
		String? name
		File? intervals
		String ext = ".recal"

		Array[File]+ knownSites
		Array[File]+ knownSitesIdx

		File refFasta
		File refFai
		File refDict

		Int gapPenality = 40
		Int indelDefaultQual = 45
		Int lowQualTail = 2
		Int indelKmer = 3
		Int mismatchKmer = 2
		Int maxCycle = 500

		Boolean overlappingRule = false
		Int intervalsPadding = 0
		Boolean intersectionRule = false

		Int threads = 1
	}

	String baseNameIntervals = if defined(intervals) then intervals else ""
	String baseIntervals = if defined(intervals) then sub(basename(baseNameIntervals),"([0-9]+)-scattered.interval_list","\.$1") else ""

	String baseName = if defined(name) then name else sub(basename(in),"\.(sam|bam|cram)$","")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{baseIntervals}~{ext}" else "~{baseName}~{baseIntervals}~{ext}"

	command <<<

		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{path_exe} BaseRecalibrator \
			--input ~{in} \
			--known-sites ~{sep="--known-sites " knownSites} \
			--reference ~{refFasta} \
			--intervals ~{intervals} \
			--bqsr-baq-gap-open-penalty ~{gapPenality} \
			--deletions-default-quality ~{indelDefaultQual} \
			--insertions-default-quality ~{indelDefaultQual} \
			--low-quality-tail ~{lowQualTail} \
			--indels-context-size ~{indelKmer} \
			--mismatches-context-size ~{mismatchKmer} \
			--maximum-cycle-value ~{maxCycle} \
			--interval-padding ~{intervalsPadding} \
			--interval-merging-rule ~{true="OVERLAPPING_ONLY" false="ALL" overlappingRule} \
			--interval-set-rule ~{true="INTERSECTION" false="UNION" intersectionRule} \
			--output ~{outputFile}

	>>>

	output {
		File outputFile = outputFile
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "gatk"]',
			category: 'optional'
		}
		in: {
			description: 'Alignement file to recalibrate (SAM/BAM/CRAM)',
			category: 'Required'
		}
		bamIdx: {
			description: 'Index for the alignement input file to recalibrate.',
			category: 'Required'
		}
		intervals: {
			description: 'Path to a file containing genomic intervals over which to operate. (format intervals list: chr1:1000-2000)',
			category: 'optional'
		}
		outputPath: {
			description: 'Output path where bqsr report will be generated.',
			category: 'Required'
		}
		name: {
			description: 'Output file base name [default: sub(basename(in),"\.(sam|bam|cram)$","")].',
			category: 'optional'
		}
		ext: {
			description: 'Extension for the output file [default: ".recal"]',
			category: 'optional'
		}
		knownSites: {
			description: 'One or more databases of known polymorphic sites used to exclude regions around known polymorphisms from analysis.',
			category: 'optional'
		}
		knownSitesIdx: {
			description: 'Indexes of the inputs known sites.',
			category: 'optional'
		}
		refFasta: {
			description: 'Path to the reference file (format: fasta)',
			category: 'required'
		}
		refFai: {
			description: 'Path to the reference file index (format: fai)',
			category: 'required'
		}
		refDict: {
			description: 'Path to the reference file dict (format: dict)',
			category: 'required'
		}
		gapPenality: {
			description: 'BQSR BAQ gap open penalty (Phred Scaled). Default value is 40. 30 is perhaps better for whole genome call sets [default: 40]',
			category: 'optional'
		}
		indelDefaultQual: {
			description: 'Default quality for the base insertions/deletions covariate [default: 45]',
			category: 'optional'
		}
		lowQualTail: {
			description: 'Minimum quality for the bases in the tail of the reads to be considered [default: 2]',
			category: 'optional'
		}
		indelKmer: {
			description: 'Size of the k-mer context to be used for base insertions and deletions [default: 3]',
			category: 'optional'
		}
		mismatchKmer: {
			description: 'Size of the k-mer context to be used for base mismatches [default: 2]',
			category: 'optional'
		}
		maxCycle: {
			description: 'The maximum cycle value permitted for the Cycle covariate [default: 500]',
			category: 'optional'
		}
		intervalsPadding: {
			description: 'Amount of padding (in bp) to add to each interval you are including. [default: 0]',
			category: 'optional'
		}
		overlappingRule: {
			description: 'Interval merging rule for abutting intervals set to OVERLAPPING_ONLY [default: false => ALL]',
			category: 'optional'
		}
		intersectionRule: {
			description: 'Set merging approach to use for combining interval inputs to INTERSECTION [default: false => UNION]',
			category: 'optional'
		}
		threads: {
			description: 'Sets the number of threads [default: 1]',
			category: 'optional'
		}
	}
}

task gatherBQSRReports {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2020-08-06"
	}

	input {
		String path_exe = "gatk"

		Array[File?] in
		String? outputPath
		String? name
		String subString = "\.[0-9]\.recal$"
		String ext = ".bqsr.report"

		Int threads = 1
	}

	String firstFile = basename(select_first(in))
	String baseName = if defined(name) then name else sub(basename(firstFile),subString,"")
	String outputFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{ext}" else "~{baseName}~{ext}"

	command <<<

		if [[ ! -d $(dirname ~{outputFile}) ]]; then
			mkdir -p $(dirname ~{outputFile})
		fi

		~{path_exe} GatherBQSRReports \
			--input ~{sep="--input " in} \
			--output ~{outputFile}

	>>>

	output {
		File outputFile = outputFile
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "gatk"]',
			category: 'optional'
		}
		in: {
			description: 'List of scattered BQSR report files',
			category: 'Required'
		}
		outputPath: {
			description: 'Output path where bqsr report will be generated.',
			category: 'optional'
		}
		name: {
			description: 'Output file base name [default: sub(basename(firstFile),subString,"")].',
			category: 'optional'
		}
		ext: {
			description: 'Extension for the output file [default: ".bqsr.report"]',
			category: 'optional'
		}
		subString: {
			description: 'Extension to remove from the input file [default: "\.[0-9]\.recal$"]',
			category: 'optional'
		}
		threads: {
			description: 'Sets the number of threads [default: 1]',
			category: 'optional'
		}
	}
}

task applyBQSR {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.0.1"
		date: "2020-08-07"
	}

	input {
		String path_exe = "gatk"

		File in
		File bamIdx
		File bqsrReport
		File? intervals
		String? outputPath
		String? name
		String suffix = ".bqsr"

		File refFasta
		File refFai
		File refDict

		Boolean originalQScore = false
		Int globalQScorePrior = -1
		Int preserveQScoreLT = 6
		Int quantizeQual = 0

		Boolean overlappingRule = false
		Int intervalsPadding = 0
		Boolean intersectionRule = false

		Boolean bamIndex = true
		Boolean bamMD5 = true

		Int threads = 1
	}

	String baseNameIntervals = if defined(intervals) then intervals else ""
	String baseIntervals = if defined(intervals) then sub(basename(baseNameIntervals),"([0-9]+)-scattered.interval_list","\.$1") else ""

	String baseName = if defined(name) then name else sub(basename(in),"(.*)\.(sam|bam|cram)$","$1")
	String ext = sub(basename(in),"(.*)\.(sam|bam|cram)$","$2")
	String outputBamFile = if defined(outputPath) then "~{outputPath}/~{baseName}~{baseIntervals}~{suffix}\.~{ext}" else "~{baseName}~{baseIntervals}~{suffix}\.~{ext}"
	String outputBaiFile = sub(outputBamFile,"(m)$","i")

	command <<<

		if [[ ! -d $(dirname ~{outputBamFile}) ]]; then
			mkdir -p $(dirname ~{outputBamFile})
		fi

		~{path_exe} ApplyBQSR \
			--input ~{in} \
			--bqsr-recal-file ~{bqsrReport} \
			--reference ~{refFasta} \
			~{default="" "--intervals " + intervals} \
			~{true="--emit-original-quals" false="" originalQScore} \
			--global-qscore-prior ~{globalQScorePrior} \
			--preserve-qscores-less-than ~{preserveQScoreLT} \
			--quantize-quals ~{quantizeQual} \
			--interval-padding ~{intervalsPadding} \
			--interval-merging-rule ~{true="OVERLAPPING_ONLY" false="ALL" overlappingRule} \
			--interval-set-rule ~{true="INTERSECTION" false="UNION" intersectionRule} \
			~{true="--create-output-bam-index" false="" bamIndex} \
			~{true="--create-output-bam-md5" false="" bamMD5} \
			--output ~{outputBamFile}

	>>>

	output {
		File outputBam = outputBamFile
		File outputBai = outputBaiFile
	}

	parameter_meta {
		path_exe: {
			description: 'Path used as executable [default: "gatk"]',
			category: 'optional'
		}
		in: {
			description: 'Bam file top apply BQSR.',
			category: 'Required'
		}
		bamIdx: {
			description: 'Index for the alignement input file to recalibrate.',
			category: 'Required'
		}
		outputPath: {
			description: 'Output path where bam will be generated.',
			category: 'optional'
		}
		name: {
			description: 'Output file base name [default: sub(basename(firstFile),subString,"")].',
			category: 'optional'
		}
		suffix: {
			description: 'Suffix to add for the output file (e.g sample.suffix.bam)[default: ".bqsr"]',
			category: 'optional'
		}
		bqsrReport: {
			description: 'Path to a file containing bqsr report',
			category: 'Required'
		}
		intervals: {
			description: 'Path to a file containing genomic intervals over which to operate. (format intervals list: chr1:1000-2000)',
			category: 'optional'
		}
		refFasta: {
			description: 'Path to the reference file (format: fasta)',
			category: 'required'
		}
		refFai: {
			description: 'Path to the reference file index (format: fai)',
			category: 'required'
		}
		refDict: {
			description: 'Path to the reference file dict (format: dict)',
			category: 'required'
		}
		originalQScore: {
			description: 'Emit original base qualities under the OQ tag [default: false]',
			category: 'optional'
		}
		globalQScorePrior: {
			description: 'Global Qscore Bayesian prior to use for BQSR [default: -1]',
			category: 'optional'
		}
		preserveQScoreLT: {
			description: "Don't recalibrate bases with quality scores less than this threshold [default: 6]",
			category: 'optional'
		}
		quantizeQual: {
			description: 'Quantize quality scores to a given number of levels [default: 0]',
			category: 'optional'
		}
		intervalsPadding: {
			description: 'Amount of padding (in bp) to add to each interval you are including. [default: 0]',
			category: 'optional'
		}
		overlappingRule: {
			description: 'Interval merging rule for abutting intervals set to OVERLAPPING_ONLY [default: false => ALL]',
			category: 'optional'
		}
		intersectionRule: {
			description: 'Set merging approach to use for combining interval inputs to INTERSECTION [default: false => UNION]',
			category: 'optional'
		}
		bamIndex: {
			description: 'Create a BAM/CRAM index when writing a coordinate-sorted BAM/CRAM file [default: true]',
			category: 'optional'
		}
		bamMD5: {
			description: 'Create a MD5 digest for any BAM/SAM/CRAM file created [default: true]',
			category: 'optional'
		}
		threads: {
			description: 'Sets the number of threads [default: 1]',
			category: 'optional'
		}
	}
}
