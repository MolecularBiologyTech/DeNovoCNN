# DeNovoCNN: Deep Learning for De Novo Variant Detection

## Quick Start

### Version Management

DeNovoCNN uses a versioned installation system. The latest installer script is always available in the `Versions/` directory.

```bash
# List available versions
ls Versions/

# Use the latest version installer
./Versions/v.1.1.1/DeNovoCNN_Installer_v.1.1.1.sh --use-conda --install-dir /path/to/installation
```

**Version History:**
- v.1.1.1: Fixed environment.yml check to ensure repository is cloned if missing
- v.1.1.0: Added local Miniconda installation (conda installed in installation directory if not found)
- v.1.0.9: Added IGV snapshot generation integration (IGV 2.16.2 auto-installation, snapshot parameters, automatic region detection)
- v.1.0.8: Added support for separate SNV and SV VCFs with combined output
- v.1.0.7: Added advanced DeNovoCNN parameters (REGION, OUTPUT_DENOVOCNN_FORMAT, NOT_CONVERT_TO_INNER_FORMAT)
- v.1.0.6: Added PED file support for auto-detection of family structure and child's sex
- v.1.0.5: Updated VCF file handling (copied to working directory to avoid modifying originals)
- v.1.0.4: Restructured to follow 0.Workflow/1.Definespcs/2.Run pattern (0_README, 1_Define_data_specs.txt, 2_Run_analysis.sh)
- v.1.0.3: Updated installer with improved workflow structure
- v.1.0.2: Included run_denovocnn_pipeline.sh script in installer (copied to installation directory after setup)
- v.1.0.1: Added Ubuntu Linux support (OS detection, Ubuntu-specific paths, OS-specific conda installation instructions)
- v.1.0.0: Initial version

### 1. Installation (Required)

**Prerequisite:**
- Conda must be installed on your system (Miniconda or Anaconda), OR it will be installed locally

**You must specify an installation directory.** The installation script requires explicit parameters to ensure proper setup.

```bash
# Install with conda (or local Miniconda if not found)
./Versions/v.1.1.1/DeNovoCNN_Installer_v.1.1.1.sh --use-conda --install-dir /path/to/installation

# Example:
./Versions/v.1.1.1/DeNovoCNN_Installer_v.1.1.1.sh --use-conda --install-dir /Users/matteozoia/tools/DeNovoCNN
```

**What the installer does:**
- Clones the DeNovoCNN repository from GitHub to your specified installation directory
- Creates a conda environment using the environment.yml file with all required dependencies (Python, TensorFlow, SAMtools, Pysam)

**Required Parameters:**
- `--install-dir PATH`: Where to install DeNovoCNN (must be specified)

**Optional Parameters:**
- `--use-conda`: Use conda environment (default: true)
- `--conda-prefix PATH`: Exact conda environment location (default: install_dir/env)
- `--conda-env NAME`: Conda environment name (only if conda-prefix not set)

**If you run without --install-dir, you will see:**
```
ERROR: Installation directory not specified

You must specify an installation directory using --install-dir

Required usage:
  ./DeNovoCNN_Installer_v.1.0.4.sh --install-dir /path/to/installation

Example:
  ./DeNovoCNN_Installer_v.1.0.4.sh --install-dir /Users/matteozoia/tools/DeNovoCNN
```

### 2. After Installation

After installation completes, the DeNovoCNN repository will be cloned to your specified installation directory with all necessary dependencies set up in the conda environment. The installer generates three files in the installation directory:

- **0_README_DeNovoCNN_Workflow.md** - Complete workflow documentation
- **1_Define_data_specs.txt** - Configuration file (edit this with your data paths and parameters)
- **2_Run_analysis.sh** - Analysis pipeline script (execute this to run the analysis)

**Usage:**
1. Edit `1_Define_data_specs.txt` with your BAM/VCF file paths and analysis parameters
2. Activate the conda environment
3. Run `./2_Run_analysis.sh` to execute the analysis

**Note:** VCF files are copied to the working directory to avoid modifying the original files. BAM files and reference genome are linked via symlinks (read-only operations).

**PED File (Optional but Recommended):**
You can optionally provide a PED file to auto-detect family structure and child's sex. The PED file format is:
```
FamilyID SampleID FatherID MotherID Sex(1=male,2=female) Phenotype(1=unaffected,2=affected)
```

If a PED file is provided, the analysis will:
- Auto-detect the proband (affected child)
- Determine the child's sex for potential X chromosome analysis
- Display family information during analysis

**Advanced DeNovoCNN Parameters (Optional):**
In `1_Define_data_specs.txt`, you can also configure advanced DeNovoCNN parameters:
- `REGION` - Chromosome to analyze (1, 2, ... 22, X) - leave empty to analyze all regions
- `OUTPUT_DENOVOCNN_FORMAT` - Set to "true" for normalized variants with end coordinate, "false" for standard
- `NOT_CONVERT_TO_INNER_FORMAT` - Uncomment if you don't want to convert insertion positions to internal representation

These parameters can be commented out with `#` if you don't want to use them.

**SNV and SV VCF Support:**
DeNovoCNN supports two modes for VCF input:
1. **Single VCF per sample** (default): Each sample has one VCF containing both SNV and SV variants
2. **Separate SNV and SV VCFs**: Each sample has separate VCFs for SNV and SV variants

To use separate SNV and SV VCFs, uncomment the following in `1_Define_data_specs.txt`:
```bash
CHILD_SNV_VCF="/path/to/child_snv.vcf"
FATHER_SNV_VCF="/path/to/father_snv.vcf"
MOTHER_SNV_VCF="/path/to/mother_snv.vcf"
CHILD_SV_VCF="/path/to/child_sv.vcf"
FATHER_SV_VCF="/path/to/father_sv.vcf"
MOTHER_SV_VCF="/path/to/mother_sv.vcf"
```

When using separate SNV and SV VCFs:
- DeNovoCNN runs on both SNV and SV VCFs
- Results are combined into a single output file with a `variant_type` column (SNV/SV)
- Final output file: `predictions_combined.csv`

**IGV Snapshot Generation (Optional):**
DeNovoCNN can automatically generate IGV snapshots for detected de novo regions. To enable this feature, uncomment the following in `1_Define_data_specs.txt`:
```bash
ENABLE_IGV_SNAPSHOTS="true"
IGV_SNAPSHOT_DIR="igv_snapshots"
IGV_IMAGE_WIDTH="1920"
IGV_IMAGE_HEIGHT="1080"
IGV_ZOOM_LEVEL="10"
IGV_WINDOW_SIZE="500"
IGV_IMAGE_FORMAT="png"
```

When enabled:
- IGV is automatically installed with DeNovoCNN in the installation directory
- After DeNovoCNN analysis, snapshots are generated for each detected de novo variant
- Snapshots are saved in the specified directory (default: `igv_snapshots/`)
- Each snapshot is named based on variant: `{chromosome}_{position}_{ref}_{alt}.{format}`

**Note:** IGV snapshot generation requires IGV to be available. The installer downloads IGV 2.16.2 automatically during installation. Snapshots are generated using IGV batch mode scripts.

**Local Miniconda Installation:**
DeNovoCNN can automatically install Miniconda locally if conda is not found on your system. When you run the installer without system conda:
- Miniconda3 is downloaded and installed in the DeNovoCNN installation directory
- Conda environment is created within the local Miniconda installation
- All dependencies are installed in the local environment
- No system-wide conda installation is required

**Folder Structure after Installation:**
```
/path/to/DeNovoCNN/
├── miniconda3/              # Local Miniconda (if system conda not found)
│   ├── bin/
│   ├── envs/
│   │   └── denovocnn_env/   # Conda environment with dependencies
│   └── ...
├── IGV/                     # IGV installation for snapshots
│   ├── IGV/                 # IGV application
│   └── igv.sh               # Wrapper script
├── models/                  # Pre-trained CNN models
│   ├── snp/
│   ├── ins/
│   └── del/
├── apply_denovocnn.sh       # Core DeNovoCNN script
├── 0_README_DeNovoCNN_Workflow.md
├── 1_Define_data_specs.txt
└── 2_Run_analysis.sh
```

## Overview

DeNovoCNN is a deep learning approach that uses convolutional neural networks (CNNs) to identify de novo mutations (DNMs) in trio whole genome sequencing (WGS) and whole exome sequencing (WES) data. It achieves state-of-the-art performance by converting genomic sequencing data into image-like representations and applying computer vision techniques to distinguish true de novo mutations from sequencing artifacts.

## Why DeNovoCNN is Superior

### Performance Metrics
- **Recall: 96.74%** - Ability to detect true de novo mutations
- **Precision: 96.55%** - Avoidance of false positive calls
- **F1-score: 96.64%** - Balanced performance metric
- **Outperforms**: GATK, DeNovoGear, DeepTrio, Samtools

### Key Advantages
1. **No Variant Recalling Required**: Works with existing BAM/VCF files from any variant caller
2. **Platform Agnostic**: Robust across different sequencing technologies (Illumina, NovaSeq, HiSeq)
3. **Capture Kit Independent**: Works with different exome capture kits
4. **WGS/WES Compatible**: Trained on WES but generalizes well to WGS data
5. **Visual Interpretation**: Mimics human expert review in IGV but with consistency
6. **No VCF Annotation Needed**: Uses raw read data, not functional annotations

## How DeNovoCNN Works

### 1. Data Encoding - Image Generation

DeNovoCNN converts genomic sequencing data into RGB images that capture the visual patterns of read alignments across trio members.

#### Image Specifications
- **Dimensions**: 160×164 pixels
- **Color Channels**: RGB (Red=Child, Green=Father, Blue=Mother)
- **Rows (160)**: Each row represents one sequencing read (limited to 160 reads)
- **Columns (164)**: Each genomic position uses 4 pixels (one-hot encoding)

#### Encoding Process
```
For each variant position:
1. Extract 20 nucleotides before and after the variant (41 bases total)
2. For each base position, create 4-pixel one-hot vector: [A, C, T, G]
3. If base is 'A', first pixel = intensity, others = 0
4. Pixel intensity = mapping(base_quality, mapping_quality)
5. Stack trio data into RGB channels
```

#### Visual Representation
- **True De Novo**: Variant visible in red channel (child), absent in green/blue (parents)
- **Inherited**: Variant visible in red + one parent channel
- **Artifact**: Inconsistent patterns, low quality, strand bias

### 2. CNN Architecture

#### Model Structure
```
Input (160×164×3 RGB image)
    ↓
9 × Convolutional Layers (96 filters, 3×3 kernels, ReLU, same padding)
    ↓
Batch Normalization (every 3rd layer)
    ↓
Squeeze-and-Excitation Blocks (channel attention)
    ↓
Global Max Pooling + Global Average Pooling
    ↓
Dense Layer (1 neuron, sigmoid activation)
    ↓
Output: Probability (0-1) of being de novo mutation
```

#### Three Specialized Models
- **SNP Model**: For single nucleotide substitutions
- **Insertion Model**: For insertion variants
- **Deletion Model**: For deletion variants

*Reason*: Different variant types exhibit distinct visual patterns in read alignments.

### 3. Classification Process

The CNN learns to recognize visual patterns that distinguish:
- **True de novo mutations**: Consistent variant presence in child, absence in parents, proper quality scores
- **Sequencing errors**: Inconsistent patterns, low quality, strand bias
- **Mapping artifacts**: Misaligned reads, soft-clipping, poor mapping quality
- **Mosaicism**: Low allele frequency in parents

## Training Methodology

### Training Dataset

#### Source Data
- **5,616 WES trios** from rare disease cohorts
- **~1.3 million candidate variants**
- **~12,000 validated de novo mutations**
- **~1.2 million negative examples** (inherited variants + artifacts)

#### Data Split
- **70% training**: ~8,400 variants
- **15% validation**: ~1,800 variants (hyperparameter tuning)
- **15% testing**: ~1,800 variants (final evaluation)

### Label Generation

#### Positive Examples (True De Novo)
- Child genotype: 0/1 (heterozygous)
- Both parents: 0/0 (homozygous reference)
- Quality filters: QUAL > 20, GQ > 20, DP ≥ 10x
- Validated by multiple callers and Sanger sequencing

#### Negative Examples
- Inherited variants (present in child + ≥1 parent)
- False positive de novo calls
- Sequencing artifacts and mapping errors

### Training Configuration

#### Technical Details
- **Framework**: TensorFlow 2.3.0
- **Loss Function**: Binary cross-entropy
- **Optimizer**: Adam (learning rate = 0.001)
- **Batch Size**: 32
- **Epochs**: 50 with early stopping
- **Class Weighting**: Applied to handle DNM rarity

#### Data Augmentation
- Random rotations
- Brightness adjustments
- Quality score normalization
- Platform-specific normalization

### Validation Strategy

#### Internal Validation
- Genome in a Bottle (GIAB) reference trio
- 20 in-house WES trios
- 7 in-house WGS trios

#### External Validation
- 551 WES trios from SolveRD project
- Multiple sequencing platforms
- Different capture kits
- Sanger sequencing confirmation

### Training Insights

The model learned to:
1. **Distinguish platform-specific artifacts** (different sequencers have different error patterns)
2. **Recognize capture kit biases** (different exome kits have varying coverage patterns)
3. **Generalize across technologies** (WGS-trained model works on WES and vice versa)
4. **Identify subtle quality patterns** that statistical methods miss
5. **Detect complex artifacts** like strand bias and mapping errors

## Why This Approach Works

### 1. Mimics Human Expert Review
Geneticists typically review variants manually in IGV by visually inspecting read alignments. DeNovoCNN automates this process with greater consistency and speed.

### 2. Spatial Pattern Recognition
CNNs excel at recognizing local spatial patterns - exactly what's needed to distinguish real mutations from alignment artifacts.

### 3. Quality Integration
Base quality and mapping quality are encoded directly into pixel intensities, allowing the model to learn quality thresholds automatically.

### 4. Trio Context
The RGB channel representation simultaneously shows inheritance patterns across all family members, enabling the model to learn Mendelian constraints.

### 5. Data-Driven Learning
Instead of hand-crafted rules, the model learns optimal criteria from thousands of examples, discovering subtle patterns that humans might miss.

## Comparison with Traditional Methods

| Method | Recall | Precision | F1-Score | Variant Recalling Needed |
|--------|--------|-----------|----------|-------------------------|
| DeNovoCNN | 96.74% | 96.55% | 96.64% | No |
| GATK | 89.2% | 87.8% | 88.5% | Yes |
| DeNovoGear | 91.5% | 85.3% | 88.3% | No |
| DeepTrio | 92.1% | 94.2% | 93.1% | Yes |
| Samtools | 78.4% | 82.1% | 80.2% | Yes |

## Use Cases

### Clinical Diagnostics
- Rare disease diagnosis in trio sequencing
- Identification of pathogenic de novo mutations
- Reduction of false positives for faster diagnosis

### Research Applications
- De novo mutation rate studies
- Genotype-phenotype correlation studies
- Population genetics research

### Data Re-analysis
- Re-analysis of existing trio datasets without variant recalling
- Cross-platform validation studies
- Method comparison and benchmarking

## Technical Requirements

### Input Files
- **BAM/CRAM files**: Aligned sequencing data for child, father, mother
- **VCF files**: Candidate variant locations (can be from any variant caller)
- **Reference genome**: FASTA file (e.g., GRCh38)

### Computational Resources
- **CPU**: 8+ cores recommended
- **RAM**: 16GB+ for WGS, 8GB+ for WES
- **Storage**: 100GB+ for intermediate files
- **Optional**: GPU for faster inference (not required)

### Software Dependencies

**Prerequisite:**
- **Conda** (Miniconda or Anaconda) - Must be installed on your system before running the installer

The installer will create a conda environment with all required packages (Python, TensorFlow, SAMtools, Pysam) from the environment.yml file. You do not need to install these packages manually.

## Limitations

1. **Training Data Bias**: Trained primarily on WES data, though works well on WGS
2. **Variant Types**: Optimized for SNVs and small indels, not structural variants
3. **Coverage Requirements**: Requires ≥10x coverage in all trio members
4. **Reference Bias**: Performance may vary with different reference genome versions

## Citation

If you use DeNovoCNN in your research, please cite:

```
Khazeeva G, Sablauskas K, van der Sanden B, et al. 
DeNovoCNN: a deep learning approach to de novo variant calling in next generation sequencing data. 
Nucleic Acids Res. 2022;50(17):e97. doi:10.1093/nar/gkac511
```

## License

DeNovoCNN is released under MIT License. See LICENSE file for details.

## Contact

For questions or issues, please visit: https://github.com/Genome-Bioinformatics-RadboudUMC/DeNovoCNN
