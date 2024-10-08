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



task annovarForMpa {
  meta {
    author: "Thomas Guignard; Olivier Ardouin (modifications)"
    email: "t-guignard(at)chu-montpellier.fr;o-ardouin(at)chu-montpellier.fr"
    version : "0.1.0"
    date: "2022-08-18"
  }

  input {
    ## Sample spécific values
    File vcf
    String? name
    String outputPath = "/."

    ## Path and Exe
    String perlExe = "perl"

    ## ANNOVAR Paths
    String AnnovarPath =  "/annovar"

    File? TableAnnovarExe
    File? RefRetrieveSeqFromFastaExe
    File? RefAnnotateVariationExe
    File? RefVariantsReductionExe
    File? RefCodingChangeExe
    File? RefConvert2AnnovarExe

    # Annovar databases
    String HumanDb = "/humandb"
    String CustomXref
    String Genome = "hg19"
    String Clinvar = "clinvar_latest"
    String Dbnsfp = "dbnsfp42a"

    String Dbscsnv = "dbscsnv11"
    String GnomadExome = "gnomad_exome"
    String GnomadGenome = "gnomad_genome"
    String PopFreqMax = "popfreq_max_20150413"
    String Intervar = "intervar_20180118"
    String SpliceAI = "spliceai_filtered"

    ## run time
    Int threads = 1
		Int memoryByThreads = 768
		String? memory
  }

  File TableAnnovar = if defined(TableAnnovarExe) then TableAnnovarExe  else AnnovarPath + "/table_annovar.pl"
  File RefRetrieveSeqFromFasta = if defined(RefRetrieveSeqFromFastaExe) then RefRetrieveSeqFromFastaExe else AnnovarPath + "/retrieve_seq_from_fasta.pl"
  File RefAnnotateVariation = if defined(RefAnnotateVariationExe) then RefAnnotateVariationExe else AnnovarPath + "/annotate_variation.pl"
  File RefVariantsReduction = if defined(RefVariantsReductionExe) then RefVariantsReductionExe else AnnovarPath + "/variants_reduction.pl"
  File RefCodingChange = if defined(RefCodingChangeExe) then RefCodingChangeExe else AnnovarPath + "/coding_change.pl"
  File RefConvert2Annovar = if defined(RefConvert2AnnovarExe) then RefConvert2AnnovarExe else AnnovarPath + "/convert2annovar.pl"

  String Dollar = "$"

  String outputName = if defined(name) then name else sub(basename(vcf),".vcf", "")
	String outputFile = if defined(outputPath) then outputPath + "/" + outputName else outputName

  String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
  Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
  Int memoryValue = sub(totalMem,"(M|G)", "")
  Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
  Int memoryByThreadsMb = floor(totalMemMb/threads)

  command <<<
    OPERATION_SUFFIX=',f'
    COMMA=','
    POPFREQMAX=',~{PopFreqMax}'
    #REFGENE='refGeneWithVer'
    if [ ${Genome} == 'hg38' ];then
    OPERATION_SUFFIX=''
      COMMA=''
      POPFREQMAX=''
      #REFGENE='refGene'
    fi
    "~{perlExe}" "~{TableAnnovar}" \
      "~{vcf}" \
      "~{HumanDb}" \
      -thread "~{threads}" \
      -buildver "~{Genome}" \
      -out "~{outputFile}" \
      -remove \
      -intronhgvs 80 \
      -protocol refGeneWithVer,refGeneWithVer,"~{Clinvar}","~{Dbnsfp}","~{Dbscsnv}","~{GnomadExome}","~{GnomadGenome}","~{Intervar}",regsnpintron,"~{SpliceAI}""~{Dollar}{POPFREQMAX}" \
      -operation gx,g,f,f,f,f,f,f,f,f"~{Dollar}{OPERATION_SUFFIX}" \
      -nastring . \
      -vcfinput \
      -otherinfo \
      -arg '-splicing 5','-hgvs',,,,,,,,"~{Dollar}{COMMA}" \
      -xref "~{CustomXref}" 2> "~{outputFile}.~{Genome}_multianno.log"
    >>>

  output {
    File outAnnotationVcf = "~{outputFile}.${Genome}_multianno.vcf"
    File outAnnotationAvinput = "~{outputFile}.avinput"
    File outAnnotationTxt = "~{outputFile}.${Genome}_multianno.txt"
    File outAnnotationLog = "~{outputFile}.${Genome}_multianno.log"
  }
  runtime {
    cpu: "~{threads}"
    requested_memory_mb_per_core: "${memoryByThreadsMb}"
  }
}

task AnnovarTableVersion {
  meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version : "0.1.0"
    date: "2024-07-25"
  }

  input {
    File TableAnnovarExe = "table_annovar.pl"
    String PerlExe = "perl"

    Int threads = 1
    Int memoryByThreads = 768
    String? memory
  }

  String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
  Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
  Int memoryValue = sub(totalMem,"(M|G)", "")
  Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
  Int memoryByThreadsMb = floor(totalMemMb/threads)

  command <<<
  set -ex
  #set -o pipefail --> Had to disable this option, otherwise 'exit code = 1' ??? (due to grep I suspect)

  "~{PerlExe}" "~{TableAnnovarExe}" | grep --only-matching "Version.*"
  >>>

  output {
    String version = read_string(stdout())
  }

  runtime {
    cpu: "~{threads}"
    requested_memory_mb_per_core: "${memoryByThreadsMb}"
  }

  parameter_meta {
    TableAnnovarExe: {
      description: 'Path of table_annovar perl script',
      category: 'option'
    }
    PerlExe: {
      description: 'Path of table_annovar perl script',
      category: 'Mandatory'
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

task AnnovarUsedDb {
  meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version : "0.1.0"
    date: "2024-07-25"
  }

  input {
    File StderrAnnovar  # Stderr produced by Annovar (log)

    Int threads = 1
    Int memoryByThreads = 768
    String? memory
  }

  String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
  Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
  Int memoryValue = sub(totalMem,"(M|G)", "")
  Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
  Int memoryByThreadsMb = floor(totalMemMb/threads)

  command <<<
  set -exo pipefail

  cat "~{StderrAnnovar}" |
    grep -m2 system |
    tail -1 |
    sed 's/ -/\n-/g' |
    grep protocol |
    tr ',' '\n' |
    sed '1s/-protocol /\n/'
  >>>

  output {
    String version = read_string(stdout())
  }

  runtime {
    cpu: "~{threads}"
    requested_memory_mb_per_core: "${memoryByThreadsMb}"
  }

  parameter_meta {
    StderrAnnovar: {
      description: 'Path of stderr produced by Annovar (log)',
      category: 'option'
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

task CustomXrefVersion {
  meta {
    author: "Olivier Ardouin"
    email: "o-ardouin(at)chu-montpellier.fr"
    version : "0.1.0"
    date: "2022-08-18"
  }

  input {
    String CustomXref

    Int threads = 1
    Int memoryByThreads = 768
    String? memory
  }

  String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
  Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
  Int memoryValue = sub(totalMem,"(M|G)", "")
  Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
  Int memoryByThreadsMb = floor(totalMemMb/threads)

  command <<<
  set -exo pipefail
  if [[ -f "~{CustomXref}" ]]; then
    readlink ~{CustomXref} | cut -d "_" -f 3 | cut -d "." -f 1
  else
    echo "..No CustomXrefFile.."
  fi
  >>>

  output {
    String version = read_string(stdout())
  }

  runtime {
    cpu: "~{threads}"
    requested_memory_mb_per_core: "${memoryByThreadsMb}"
  }

  parameter_meta {
    CustomXref: {
      description: 'Path of CustomXref File (link)]',
      category: 'Mandatory'
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

task ClinvarVersion {
  meta {
    author: "Olivier Ardouin"
    email: "o-ardouin(at)chu-montpellier.fr"
    version : "0.0.1"
    date: "2022-03-21"
  }

  input {
    String HumanDb = "/humandb"
    String Genome = "hg19"
    String Clinvar = "clinvar_latest"

    Int threads = 1
    Int memoryByThreads = 768
    String? memory
  }

  String ClinFile = "~{HumanDb}/~{Genome}_~{Clinvar}.ver"

  String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
  Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
  Int memoryValue = sub(totalMem,"(M|G)", "")
  Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
  Int memoryByThreadsMb = floor(totalMemMb/threads)

  command <<<
  set -exo pipefail
  if [[ -f "~{ClinFile}" ]]; then
    cat ~{ClinFile}
  else
    echo "..No Clinvar Version File.."
  fi
  >>>

  output {
    String version = read_string(stdout())
  }

  runtime {
    cpu: "~{threads}"
    requested_memory_mb_per_core: "${memoryByThreadsMb}"
  }

  parameter_meta {
    HumanDb: {
      description: 'Path of CustomXref File]',
      category: 'option'
    }
    Genome: {
      description: 'Genome version]',
      category: 'option'
    }
    Clinvar: {
      description: 'Clinvar File]',
      category: 'option'
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

task GeneVersion {
  meta {
    author: "Felix VANDERMEEREN"
    email: "felix.vandermeeren(at)chu-montpellier.fr"
    version : "0.0.1"
    date: "2024-07-25"
  }

  input {
    String HumanDb = "/humandb"
    String Genome = "hg19"
    String GeneType = "refGeneWithVer"

    Int threads = 1
    Int memoryByThreads = 768
    String? memory
  }

  File geneFile = "~{HumanDb}/~{Genome}_~{GeneType}.txt"

  String totalMem = if defined(memory) then memory else memoryByThreads*threads + "M"
  Boolean inGiga = (sub(totalMem,"([0-9]+)(M|G)", "$2") == "G")
  Int memoryValue = sub(totalMem,"(M|G)", "")
  Int totalMemMb = if inGiga then memoryValue*1024 else memoryValue
  Int memoryByThreadsMb = floor(totalMemMb/threads)

  command <<<
  set -exo pipefail

  if [[ -f "~{geneFile}" ]]; then
    readlink ~{geneFile} | cut -d "_" -f 3 | cut -d "." -f 1
  else
    echo "..No '(ref)Gene(WithVer).txt' file.."
  fi
  >>>

  output {
    String version = read_string(stdout())
  }

  runtime {
    cpu: "~{threads}"
    requested_memory_mb_per_core: "${memoryByThreadsMb}"
  }

  parameter_meta {
    HumanDb: {
      description: 'Path of HumanDB dir for Annovar',
      category: 'option'
    }
    Genome: {
      description: 'Genome version',
      category: 'option'
    }
    GeneType: {
      description: 'Type of gene db for Annovar (eg: refGene, refGeneWithVer or ensGene)',
      category: 'option'
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
