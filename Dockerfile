FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# System packages: Node 20 setup prereqs + runtime tools
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    iptables \
    jq \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Node 20 via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Non-root user for loop execution
RUN useradd -m -s /bin/bash claude

WORKDIR /workspace

COPY init-firewall.sh /init-firewall.sh
RUN chmod +x /init-firewall.sh

# init-firewall.sh runs as root, sets up iptables, then drops to claude user
ENTRYPOINT ["/init-firewall.sh"]
