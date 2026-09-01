# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables for non-interactive apt installations
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=US/Eastern

# Pipes below (curl | gpg, echo | tee) should fail the build if any stage
# fails, not just the last one
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Update and install required packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl jq apache2 wget apt-utils ca-certificates gnupg git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS via NodeSource current method
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
      gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | \
      tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the local QuakeJS repository into the image
COPY quakejs/ /quakejs/
WORKDIR /quakejs

# Fix dead npm dependency: the original inolen/quakejs-files repo and its
# npm package are both gone — install the surviving fork's tarball instead
RUN jq '.dependencies["quakejs-files"] = "https://github.com/JoshEngebretson/quakejs-files/archive/refs/heads/master.tar.gz"' \
      package.json > /tmp/pkg.json && mv /tmp/pkg.json package.json && \
    rm -f package-lock.json && \
    npm install --legacy-peer-deps

# Copy configurations
COPY server.cfg /quakejs/base/baseq3/server.cfg
COPY server.cfg /quakejs/base/cpma/server.cfg
COPY ./include/ioq3ded/ioq3ded.fixed.js /quakejs/build/ioq3ded.js

# Set up Apache to serve QuakeJS
RUN rm /var/www/html/index.html && cp /quakejs/html/* /var/www/html/
COPY ./include/assets/ /var/www/html/assets

# Copy and set permission for entrypoint
WORKDIR /
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 ./entrypoint.sh

# Expose port 80
EXPOSE 80

# Use custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]
