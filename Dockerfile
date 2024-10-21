# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables for non-interactive apt installations
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=US/Eastern

# Update and install required packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y curl jq apache2 wget apt-utils && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Node.js from nodesource
RUN curl -sL https://deb.nodesource.com/setup_19.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy the local QuakeJS repository into the image
COPY quakejs/ /quakejs/
WORKDIR /quakejs
RUN npm install

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
