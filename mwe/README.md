# CuCLARK MWE — FASTA Test

End-to-end test that generates reads from a bacterial FASTA, extracts targets, and classifies them with cuCLARK.

## Prerequisites

Place `uniques.fasta` (5.1 GB, ~35K bacterial sequences) in this `mwe/` directory.
The file is **not** included in the repo or Docker image (git-ignored and docker-ignored).

## What it does

1. Generates simulated reads (150 bp) from informative regions
2. Extracts N target genomes from the input FASTA as classification references
3. Auto-detects RAM/VRAM — selects cuCLARK (≥48 GB RAM) or cuCLARK-l (<48 GB)
4. Classifies reads on GPU and prints results summary

## Usage

```bash
# Build the image
docker build -t cuclark .

# Run (mount the FASTA and an output directory)
docker run --gpus all \
  -v ${PWD}/mwe/uniques.fasta:/data/uniques.fasta \
  -v ${PWD}/data:/data/test_example \
  cuclark bash /opt/cuclark/mwe/test_example_fasta.sh /data/test_example /data/uniques.fasta

# Custom target/read count
docker run --gpus all \
  -e NUM_TARGETS=100 -e NUM_READS=5000 \
  -v ${PWD}/mwe/uniques.fasta:/data/uniques.fasta \
  -v ${PWD}/data:/data/test_example \
  cuclark bash /opt/cuclark/mwe/test_example_fasta.sh /data/test_example /data/uniques.fasta
```

## Expected output

Reads should classify against extracted targets with high confidence:

```
  Total reads:    200
  Classified:     200 (100.0%)
  Unclassified:   0 (0.0%)
  Confidence ≥0.90: 199
  PASS: Reads are being classified against extracted targets
```
