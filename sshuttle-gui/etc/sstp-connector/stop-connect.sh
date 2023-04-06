#!/bin/bash

pkill sstpc
pkill -f /etc/sstp-connector/connect.sh
/etc/sstp-connector/update-resolv-conf down

exit 0
