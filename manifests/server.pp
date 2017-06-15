# This class provides a method to set up a fully functioning rsync server.
#
# The main idea behind this was to work around limitations of the native Puppet
# fileserving type.
#
# Most usual options are supported, but there are far too many to tackle all of
# them at once.
#
# This mainly daemonizes rsync and keeps it running. It will also subscribe it
# to the stunnel service if it has been declared.
#
# == Parameters ==
#
# @param stunnel [Boolean] Use Stunnel to encrypt this connection. It is
#   *highly* recommended to leave this enabled.
#
# @param stunnel_port [Port] The port upon which Stunnel should listen for
#   connections.
#
# @param stunnel_connect [Array[Simplib::Port]] Address and port to which to
#   **forward** connections
#
# @param stunnel_accept [String] Address and port upon which to **accept**
#   connections
#
# @param stunnel_client [Boolean] Indicates that this connection is a client
#   connection
#
# @param listen_address [IPAddress] The IP Address upon which to listen. Set to
#   0.0.0.0 to listen on all addresses.
#
# @param drop_rsyslog_noise [Boolean] Ensure that any noise from rsync is
#   dropped. The only items that will be retained will be startup, shutdown,
#   and remote connection activities. Anything from 127.0.0.1 will be dropped
#   as useless.
#
# @param trusted_nets [NetList] A list of networks and/or hostnames that are
#   allowed to connect to this service.
#
class rsync::server (
  Simplib::IP          $listen_address     = '0.0.0.0',
  Boolean              $stunnel            = simplib::lookup('simp_options::stunnel', { default_value => true }),
  Simplib::Port        $stunnel_port       = 8730,
  Array[Simplib::Port] $stunnel_connect    = [873],
  String               $stunnel_accept     = "${listen_address}:${stunnel_port}",
  Boolean              $stunnel_client     = false,
  Boolean              $drop_rsyslog_noise = true,
  Simplib::Netlist     $trusted_nets       = simplib::lookup('simp_options::trusted_nets', { default_value => ['127.0.0.1'] })
) {
  include '::rsync'
  include '::rsync::server::global'

  $_subscribe  = $stunnel ? {
    true    => Service['stunnel'],
    default => undef
  }

  if $stunnel {
    include '::stunnel'

    stunnel::connection { 'rsync':
      connect      => $stunnel_connect,
      accept       => $stunnel_accept,
      client       => $stunnel_client,
      trusted_nets => $trusted_nets
    }
  }

  concat { '/etc/rsyncd.conf':
    owner          => 'root',
    group          => 'root',
    mode           => '0400',
    ensure_newline => true,
    warn           => true,
    require        => Package['rsync']
  }

  if 'systemd' in $facts['init_systems'] {
    service { 'rsyncd':
      ensure     => 'running',
      enable     => true,
      hasstatus  => true,
      hasrestart => true,
      require    => Package['rsync'],
      subscribe  => $_subscribe
    }
  }
  else {
    file { '/etc/init.d/rsyncd':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0750',
      content => file("${module_name}/rsync.init")
    }

    service { 'rsyncd':
      ensure     => 'running',
      enable     => true,
      hasstatus  => true,
      hasrestart => true,
      require    => Package['rsync'],
      provider   => 'redhat',
      subscribe  => $_subscribe
    }
    File['/etc/init.d/rsyncd'] ~> Service['rsyncd']
  }

  Concat['/etc/rsyncd.conf'] ~> Service['rsyncd']

  if $drop_rsyslog_noise {
    include '::rsyslog'

    rsyslog::rule::drop { '00_rsyncd':
      rule => '$programname == \'rsyncd\' and not ($msg contains \'rsync on\' or $msg contains \'SIG\' or $msg contains \'listening\')'
    }
    rsyslog::rule::drop { '00_rsync_localhost':
      rule => '$programname == \'rsyncd\' and $msg contains \'127.0.0.1\''
    }
  }
}
