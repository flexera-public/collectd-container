#! /bin/bash

# Expected environment variables (specify on docker run command line)
# RS_INSTANCE_UUID: the monitoring ID of this server in the RightScale platform

# Configure a collectd plugin.
#
# $1: the name of the collectd plugin to configure
# $@: zero or more configuration options to set
#
function configure_collectd_plugin() {
  local collectd_plugin=$1
  # Remove $1 from $@
  shift
  local collectd_plugin_conf="$collectd_conf_plugins_dir/${collectd_plugin}.conf"

  echo "LoadPlugin \"$collectd_plugin\""  >$collectd_plugin_conf

  # Add each configuration option to the collectd plugin configuration if there are any
  if [[ $# -ne 0 ]]; then
    echo "<Plugin \"$collectd_plugin\">" >>$collectd_plugin_conf
    for option in "$@"; do
      echo "  $option" >>$collectd_plugin_conf
    done
    echo '</Plugin>' >>$collectd_plugin_conf
  fi

  echo "collectd plugin $collectd_plugin configured"
}

# Define locations of things
collectd_base_dir=/var/lib/collectd
collectd_types_db=/usr/share/collectd/types.db
collectd_interval=20
collectd_read_threads=5
collectd_server_port=3011
collectd_service=collectd
collectd_service_notify=0
collectd_conf_dir=/etc/collectd
collectd_conf_plugins_dir="$collectd_conf_dir/plugins"
collectd_plugin_dir=/usr/lib/collectd
collectd_conf="$collectd_conf_dir/collectd.conf"
collectd_collection_conf="$collectd_conf_dir/collection.conf"
collectd_thresholds_conf="$collectd_conf_dir/thresholds.conf"

mkdir -p --mode=0755 $collectd_conf_plugins_dir $collectd_base_dir $collectd_plugin_dir

cat >$collectd_conf <<EOF
# Config file for collectd(1).
#
# Some plugins need additional configuration and are disabled by default.
# Please read collectd.conf(5) for details.
#
# You should also read /usr/share/doc/collectd/README.Debian.plugins before
# enabling any more plugins.

Hostname "$RS_INSTANCE_UUID"
FQDNLookup false
BaseDir "$collectd_base_dir"
PluginDir "$collectd_plugin_dir"
TypesDB "$collectd_types_db"
Interval $collectd_interval
ReadThreads $collectd_read_threads

Include "$collectd_conf_plugins_dir/*.conf"
Include "$collectd_thresholds_conf"
EOF

cat >$collectd_collection_conf <<EOF
datadir: "$collectd_base_dir/rrd/"
libdir: "$collectd_plugin_dir/"
EOF

cat >$collectd_thresholds_conf <<EOF
# Threshold configuration for collectd(1).
#
# See the section "THRESHOLD CONFIGURATION" in collectd.conf(5) for details.

#<Threshold>
#	<Type "counter">
#		WarningMin 0.00
#		WarningMax 1000.00
#		FailureMin 0
#		FailureMax 1200.00
#		Invert false
#		Persist false
#		Instance "some_instance"
#	</Type>
#
#	<Plugin "interface">
#		Instance "eth0"
#		<Type "if_octets">
#			DataSource "rx"
#			FailureMax 10000000
#		</Type>
#	</Plugin>
#
#	<Host "hostname">
#		<Type "cpu">
#			Instance "idle"
#			FailureMin 10
#		</Type>
#
#		<Plugin "memory">
#			<Type "memory">
#				Instance "cached"
#				WarningMin 100000000
#			</Type>
#		</Plugin>
#	</Host>
#</Threshold>
EOF

#configure_collectd_plugin syslog \
#  'LogLevel "debug"'
configure_collectd_plugin interface \
  'Interface "eth0"'
configure_collectd_plugin cpu
configure_collectd_plugin df \
  'ReportReserved false' \
  'FSType "proc"' \
  'FSType "sysfs"' \
  'FSType "fusectl"' \
  'FSType "debugfs"' \
  'FSType "securityfs"' \
  'FSType "devtmpfs"' \
  'FSType "devpts"' \
  'FSType "tmpfs"' \
  'IgnoreSelected true'
configure_collectd_plugin disk
configure_collectd_plugin memory

if [[ $(swapon -s | wc -l) -gt 1 ]];then
  configure_collectd_plugin swap
else
  echo "swapfile not setup, skipping collectd swap plugin"
fi

configure_collectd_plugin write_http \
  "URL \"http://$RLL_IP:88/rll/tss/collectdv5\""
configure_collectd_plugin load
configure_collectd_plugin processes
configure_collectd_plugin users

if collectd -T 2>&1 | grep 'Parse error' >/dev/null 2>&1; then
  echo "ERROR: collectd config contains syntax errors:"
  collectd -T
  exit 1
fi

# run the daemon (in the foreground, since we are ourselves running in a systemd unit)
collectd -f
