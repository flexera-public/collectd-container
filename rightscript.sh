#! /bin/bash -e

# get the IP address of the RightLink container on the docker bridge (something like 172.17.0.4)
# this gets passed to the collectd container so it can talk to RLL's port 88
rll_ip=$(ip route show 0.0.0.0/0 | grep -Eo 'via \S+' | awk '{ print $2 }')

cat <<EOF >/etc/systemd/system/collectd.service
[Unit]
Description=Collectd Monitoring Agent
After=rightlink.target

[Service]
ExecStartPre=-/usr/bin/docker kill collectd
ExecStartPre=-/usr/bin/docker rm collectd
ExecStartPre=/usr/bin/docker pull rightscale/collectd:$BRANCH

# Start the container
ExecStart=/usr/bin/docker run --name collectd \
  -v /proc:/host/proc:ro \
  -e RS_INSTANCE_UUID=$RS_INSTANCE_UUID \
  -e RLL_IP=$rll_ip \
  rightscale/collectd:$BRANCH /root/configure.sh

# The following may be needed as well, TBD:
#  -v /sys/block:/host/sys/block:ro

ExecStop=/usr/bin/docker stop collectd

Restart=on-failure
RestartSec=17s

[Install]
WantedBy=multi-user.target
EOF

# Install the systemd unit and run it
systemctl enable /etc/systemd/system/collectd.service
systemctl start collectd.service
