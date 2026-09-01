#!/bin/bash
ip_address=$(hostname -I | awk '{print $1}')

echo "Server IP: $ip_address"
