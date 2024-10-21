#!/bin/sh

# This script is used to configure and start the QuakeJS server and client.

# Navigate to the directory containing the QuakeJS web assets
cd /var/www/html

# Update the hostname for the QuakeJS client to use the current server's hostname
# This replaces the default 'quakejs:' with the current server's hostname
sed -i "s/'quakejs:/window.location.hostname + ':/g" index.html

# Start the Apache2 service to serve the QuakeJS client
# This ensures that the QuakeJS client is accessible via a web browser
/etc/init.d/apache2 start

# Navigate to the QuakeJS server directory
cd /quakejs

# Start the QuakeJS dedicated server with the appropriate settings and configurations
# This command starts the QuakeJS server with the baseq3 game settings, sets it to dedicated mode, and executes the server.cfg configuration file
node build/ioq3ded.js +set fs_game baseq3 set dedicated 1 +exec server.cfg
