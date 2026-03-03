# ---------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        g++ \
        wget \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /cuclark
COPY . .

RUN cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES="70;72;75;80;86;87;89;90" \
    && cmake --build build -j$(nproc) \
    && cmake --install build --prefix /usr/local

# ---------------------------------------------------------------
# Stage 2: Runtime (smaller image, no compiler)
# ---------------------------------------------------------------
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        gawk \
        gzip \
        coreutils \
        ca-certificates \
        libgomp1 \
        python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/exe/cuCLARK        /usr/local/bin/cuCLARK
COPY --from=builder /usr/local/exe/cuCLARK-l      /usr/local/bin/cuCLARK-l
COPY --from=builder /usr/local/exe/getTargetsDef  /usr/local/bin/getTargetsDef
COPY --from=builder /usr/local/exe/getAccssnTaxID /usr/local/bin/getAccssnTaxID
COPY --from=builder /usr/local/exe/getfilesToTaxNodes /usr/local/bin/getfilesToTaxNodes

COPY scripts/ /opt/cuclark/scripts/
COPY mwe/ /opt/cuclark/mwe/

# Fix Windows line endings and set permissions
RUN sed -i 's/\r$//' /opt/cuclark/scripts/* /opt/cuclark/mwe/* \
    && chmod +x /opt/cuclark/scripts/* /opt/cuclark/mwe/*.sh

# Add shell scripts to PATH so wrapper can find them
ENV PATH="/opt/cuclark/scripts:${PATH}"

WORKDIR /data
ENTRYPOINT ["cuclark"]
