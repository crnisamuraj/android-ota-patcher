# Containerfile for Android OTA Patcher
FROM fedora:40

LABEL maintainer="Android OTA Patcher Project"
LABEL description="Automated Google Pixel OTA scraper and patcher with avbroot"

# Install system dependencies
RUN dnf update -y && \
    dnf install -y \
    python3 \
    python3-pip \
    wget \
    curl \
    unzip \
    git \
    chromium \
    chromium-headless \
    chromedriver \
    java-17-openjdk \
    android-tools \
    golang \
    make \
    gcc \
    openssl \
    openssl-devel \
    procps-ng \
    which \
    file \
    pv \
    p7zip \
    p7zip-plugins \
    && dnf clean all

# Install avbroot
RUN AVBROOT_URL=$(curl -s https://api.github.com/repos/chenxiaolong/avbroot/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-gnu.zip\"" | grep -v "\.sig" | cut -d '"' -f 4) && \
    echo "Downloading avbroot from: $AVBROOT_URL" && \
    curl -L "$AVBROOT_URL" -o /tmp/avbroot.zip && \
    unzip /tmp/avbroot.zip -d /tmp && \
    find /tmp -name "avbroot" -type f -exec mv {} /usr/local/bin/ \; && \
    chmod +x /usr/local/bin/avbroot && \
    rm -rf /tmp/avbroot*

# Install payload-dumper-go for boot image extraction
RUN PAYLOAD_DUMPER_URL=$(curl -s https://api.github.com/repos/ssut/payload-dumper-go/releases/latest | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d '"' -f 4) && \
    echo "Downloading payload-dumper-go from: $PAYLOAD_DUMPER_URL" && \
    curl -L "$PAYLOAD_DUMPER_URL" -o /tmp/payload-dumper-go.tar.gz && \
    tar -tf /tmp/payload-dumper-go.tar.gz && \
    tar -xzf /tmp/payload-dumper-go.tar.gz -C /tmp && \
    find /tmp -name "payload-dumper-go" -type f -exec mv {} /usr/local/bin/ \; && \
    chmod +x /usr/local/bin/payload-dumper-go && \
    rm -rf /tmp/payload-dumper-go* && \
    /usr/local/bin/payload-dumper-go --help || echo "payload-dumper-go installed successfully"

# Install magiskboot (from official Magisk releases)
RUN MAGISK_VERSION="v29.0" && \
    curl -L "https://github.com/topjohnwu/Magisk/releases/download/${MAGISK_VERSION}/Magisk-${MAGISK_VERSION}.apk" -o /tmp/magisk.apk && \
    unzip -j /tmp/magisk.apk lib/x86_64/libmagiskboot.so -d /tmp && \
    mv /tmp/libmagiskboot.so /usr/local/bin/magiskboot && \
    chmod +x /usr/local/bin/magiskboot && \
    rm -rf /tmp/magisk.apk

# Set working directory
WORKDIR /workspace

# Copy application files
COPY . .

# Create Python virtual environment and install dependencies
RUN python3 -m venv .venv && \
    .venv/bin/pip install --upgrade pip && \
    .venv/bin/pip install selenium webdriver-manager pyyaml requests

# Verify tools are installed correctly
RUN echo "Verifying tool installations..." && \
    /usr/local/bin/avbroot --version && \
    /usr/local/bin/payload-dumper-go --help > /dev/null || true && \
    /usr/local/bin/magiskboot 2>&1 | head -1 && \
    echo "All tools verified successfully"

# Set up Chrome configuration for container environment
RUN echo "CHROME_BINARY=/usr/bin/chromium-browser" > chrome_paths.conf

# Create data directory for persistent storage with proper permissions
RUN mkdir -p /data && \
    chmod 777 /data && \
    mkdir -p /workspace/keys && \
    chmod 755 /workspace/keys

# Create entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set environment variables
ENV PYTHONPATH=/workspace/.venv/lib/python3.11/site-packages
ENV PATH="/workspace/.venv/bin:/usr/local/bin:${PATH}"
ENV CHROME_BINARY=/usr/bin/chromium-browser
ENV WORKDIR=/data

# Create volume mount points
VOLUME ["/data", "/workspace/keys"]

# Expose any necessary ports (for potential web interface in future)
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--help"]
