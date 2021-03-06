# == Class: cluster:rabbitmq_fence
#
# Configures a rabbit-fence daemon for dead rabbitmq
# nodes fencing. The daemon uses dbus
# system events generated by the Corosync.
# Requires corosync and rabbitmq packages installed
# and corosync, rabbitmq services configured and running
#
# === Parameters
#
# [*enabled*]
#    (Optional) Ensures state for the rabbit-fence daemon.
#    Defaults to 'false'
#
class cluster::rabbitmq_fence(
  $enabled = false,
) {
  case $::osfamily {
    'RedHat': {
      $packages          = ['dbus', 'dbus-python',
                            'pygobject2', 'python-daemon' ]
      $dbus_service_name = 'messagebus'
      $service_name      = 'rabbit-fence'
    }
    'Debian': {
      $packages          = [ 'python-gobject', 'python-gobject-2',
                            'python-dbus', 'python-daemon' ]
      $dbus_service_name = 'dbus'
      $service_name      = 'fuel-rabbit-fence'
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem:\
 ${::operatingsystem}, module ${module_name} only support osfamily\
 RedHat and Debian")
    }
  }

  File {
    owner   => 'root',
    group   => 'root',
  }

  Service {
    hasstatus  => true,
    hasrestart => true,
  }

  package { $packages: } ->

  service { $dbus_service_name:
    ensure     => running,
    enable     => true,
  } ->

  service { 'corosync-notifyd':
    ensure     => running,
    enable     => true,
  } ->

  package { 'fuel-rabbit-fence': } ->
  service { 'rabbit-fence':
    name    => $service_name,
    enable  => $enabled,
    ensure  => $enabled ? { true => running, false => stopped },
    require => Package['rabbitmq-server'],
  }

  if $::osfamily == 'Debian' {
    Exec {
      path    => [ '/bin', '/usr/bin' ],
      before  => Service['corosync-notifyd'],
    }

    exec { 'enable_corosync_notifyd':
      command => 'sed -i s/START=no/START=yes/ /etc/default/corosync-notifyd',
      unless  => 'grep START=yes /etc/default/corosync-notifyd',
    }

    #https://bugs.launchpad.net/ubuntu/+source/corosync/+bug/1437368
    #FIXME(bogdando) remove these hacks once the corosync package issues resolved
    exec { 'fix_corosync_notifyd_init_args':
      command => 'sed -i s/DAEMON_ARGS=\"\"/DAEMON_ARGS=\"-d\"/ /etc/init.d/corosync-notifyd',
      onlyif  => 'grep \'DAEMON_ARGS=""\' /etc/init.d/corosync-notifyd',
    }

    #https://bugs.launchpad.net/ubuntu/+source/corosync/+bug/1437359
    exec { 'fix_corosync_notifyd_init_pidfile':
      command => 'sed -i \'/PIDFILE=\/var\/run\/corosync.pid/d\' /etc/init.d/corosync-notifyd',
      onlyif  => 'grep \'PIDFILE=/var/run/corosync.pid\' /etc/init.d/corosync-notifyd',
    }
  }
}
