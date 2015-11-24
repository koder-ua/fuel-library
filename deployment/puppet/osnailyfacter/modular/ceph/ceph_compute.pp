notice('MODULAR: ceph/ceph_compute.pp')

$mon_address_map          = get_node_to_ipaddr_map_by_network_role(hiera_hash('ceph_monitor_nodes'), 'ceph/public')
$storage_hash             = hiera_hash('storage_hash', {})
$public_vip               = hiera('public_vip')
$management_vip           = hiera('management_vip')
$use_syslog               = hiera('use_syslog', true)
$syslog_log_facility_ceph = hiera('syslog_log_facility_ceph','LOG_LOCAL0')
$keystone_hash            = hiera_hash('keystone_hash', {})

prepare_network_config(hiera_hash('network_scheme'))
$ceph_cluster_network = get_network_role_property('ceph/replication', 'network')
$ceph_public_network  = get_network_role_property('ceph/public', 'network')

$fsid                      = "121212"
$osd_journal_size          = "2048"

ceph {$fsid:
  osd_journal_size         => $osd_journal_size,
  osd_pool_default_pg_num  => $storage_hash['pg_num'],
  osd_pool_default_pgp_num => $storage_hash['pg_num'],
  osd_pool_default_size    => $storage_hash['osd_pool_size'],
  mon_initial_members      => values($mon_address_map),
  mon_hosts                => keys($mon_address_map),
  cluster_network          => $ceph_cluster_network,
  public_network           => $ceph_public_network,
}

service { $::ceph::params::service_nova_compute :}


# Cinder settings
$cinder_pool              = 'volumes'
# Glance settings
$glance_pool              = 'images'
#Nova Compute settings
$compute_user             = 'compute'
$compute_pool             = 'compute'

# ceph::key {
  # user          => $compute_user,
  # acl           => "mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=${cinder_pool}, allow rx pool=${glance_pool}, allow rwx pool=${compute_pool}'",
  # keyring_owner => 'nova',
# }

ceph::key {"client.${compute_user}":
  cap_mon => "allow r",
  cap_osd => "allow class-read object_prefix rbd_children, allow rwx pool=${cinder_pool}, allow rx pool=${glance_pool}, allow rwx pool=${compute_pool}"
  user => "nova"
}

ceph::pool {$compute_pool:
  pg_num        => $storage_hash['pg_num'],
  pgp_num       => $storage_hash['pg_num'],
}

# include ceph::nova_compute

if ($storage_hash['ephemeral_ceph']) {
  # include ceph::ephemeral
  # Class['ceph::conf'] -> Class['ceph::ephemeral'] ~>
  Service[$::ceph::params::service_nova_compute]
}

# Class['ceph::conf'] ->
# Ceph::Pool[$compute_pool] ->
# Class['ceph::nova_compute'] ~>
Service[$::ceph::params::service_nova_compute]

Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
  cwd  => '/root',
}
