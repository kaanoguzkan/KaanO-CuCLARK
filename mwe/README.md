# CuCLARK MWE — FASTA Test

Self-contained test that downloads a bacterial FASTA, extracts targets, generates reads, and classifies them with cuCLARK.

## What it does

1. Downloads `uniques.fasta` (5.1 GB, 35K bacterial sequences) from the test server
2. Validates FASTA format (header, characters, N-content)
3. Generates simulated reads (150 bp) from informative regions
4. Extracts N target genomes from the input FASTA as classification references
5. Auto-detects RAM/VRAM — selects cuCLARK (≥48 GB RAM) or cuCLARK-l (<48 GB)
6. Classifies reads on GPU and prints results summary

## Usage

```bash
# Build and run (default: 5 targets, 200 reads)
docker build -t cuclark .
docker run --gpus all --entrypoint bash -v ${PWD}:/data cuclark \
  /opt/cuclark/mwe/test_example_fasta.sh

# Custom target/read count
docker run --gpus all --entrypoint bash \
  -e NUM_TARGETS=100 -e NUM_READS=5000 \
  -v ${PWD}:/data cuclark /opt/cuclark/mwe/test_example_fasta.sh
```

## Expected output

Reads should classify against extracted targets with high confidence:

```
  Total reads:    200
  Classified:     200 (100.0%)
  Unclassified:   0 (0.0%)
  Confidence ≥0.90: 200
  PASS: Reads are being classified against extracted targets
```
