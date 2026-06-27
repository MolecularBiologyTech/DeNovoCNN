# DeNovoCNN: Deep Learning for De Novo Variant Detection

## Quick Start

### Version Management

DeNovoCNN uses a versioned installation system. The latest installer script is always available in the `Versions/` directory.

```bash
# List available versions
ls Versions/

# Use the latest version installer
./Versions/v.1.0.0/DeNovoCNN_Installer_v.1.0.0.sh --use-conda --install-dir /path/to/installation
```

### 1. Installation (Required)

**Prerequisite:**
- Conda must be installed on your system (Miniconda or Anaconda)

**You must specify an installation directory.** The installation script requires explicit parameters to ensure proper setup.

```bash
# Install with conda
./Versions/v.1.0.0/DeNovoCNN_Installer_v.1.0.0.sh --use-conda --install-dir /path/to/installation

# Example:
./Versions/v.1.0.0/DeNovoCNN_Installer_v.1.0.0.sh --use-conda --install-dir /Users/matteozoia/tools/DeNovoCNN
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
  ./DeNovoCNN_Installer_v.1.0.0.sh --install-dir /path/to/installation

Example:
  ./DeNovoCNN_Installer_v.1.0.0.sh --install-dir /Users/matteozoia/tools/DeNovoCNN
```

### 2. After Installation

After installation completes, the DeNovoCNN repository will be cloned to your specified installation directory with all necessary dependencies set up in the conda environment or Docker image.

The installer saves your configuration to `install_config.sh` in the installation directory for reference.

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
