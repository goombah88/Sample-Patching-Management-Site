#!/bin/bash

# Author: Chad Crider
# Date:   1/8/2024
# Purpose:To set up APT to not use the proxy for our local OS repo
#		otherwise it'll fail.
#	  All 3rd party repos will still use the proxy.

PROXY_CONFIG="/etc/apt/apt.conf.d/80proxy"
: "${APT_LOCAL_REPO_HOST:?Set APT_LOCAL_REPO_HOST}"
: "${APT_PROXY_URL:?Set APT_PROXY_URL}"
: "${APT_FTP_PROXY_URL:?Set APT_FTP_PROXY_URL}"

# First move any old config out of the way, just in case
[[ -f $PROXY_CONFIG ]] && mv $PROXY_CONFIG /home/ansible/80proxy.old

# Now write the new one
cat > "$PROXY_CONFIG" <<EOF
Acquire {
    http::proxy::$APT_LOCAL_REPO_HOST "DIRECT";
    http::proxy "$APT_PROXY_URL";
}
Acquire {
    https::proxy::$APT_LOCAL_REPO_HOST:80 "DIRECT";
    https::proxy "$APT_PROXY_URL";
}
Acquire::ftp::proxy "$APT_FTP_PROXY_URL";
EOF

chmod 644 $PROXY_CONFIG
chown root:root $PROXY_CONFIG