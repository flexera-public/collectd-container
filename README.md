Collectd Container
==================

This repo contains the pieces necessary to build a docker image with collectd that can be
used to monitor the host on which the container is running and send the stats to another
"sibling" container running RightLink 10 for submission to TSS.

How it works
------------

- collectd runs in a debian container which needs to have all the appropriate shared libraries
  to support the various plugins
- the container needs to have /proc mounted on /host/proc in order to expose the hosts' stats
  to collectd (additional such mounts are probably necessary but not worked out yet)
- collectd is intended to be configured to push stats to RightLink, which runs in a separate
  container, this is achieved by having RL listen on a port on the host's interface on the docker
  network bridge (typically 172.17.42.1:88). This allows collectd to send stats to that IP address
  and never have the IP address change (which collectd doesn't deal well with)
