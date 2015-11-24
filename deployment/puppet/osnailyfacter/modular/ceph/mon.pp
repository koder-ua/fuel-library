notice('MODULAR: ceph/mon.pp')

$storage_hash                   = hiera('storage', {})
$mon_address_map                = get_node_to_ipaddr_map_by_network_role(hiera_hash('ceph_monitor_nodes'), 'ceph/public')

# if ($storage_hash['images_ceph']) {
#   $glance_backend = 'ceph'
# } elsif ($storage_hash['images_vcenter']) {
#   $glance_backend = 'vmware'
# } else {
#   $glance_backend = 'swift'
# }

# if ($storage_hash['volumes_ceph'] or
#   $storage_hash['images_ceph'] or
#   $storage_hash['objects_ceph'] or
#   $storage_hash['ephemeral_ceph']
# ) {
#   $use_ceph = true
# } else {
#   $use_ceph = false
# }

prepare_network_config(hiera_hash('network_scheme'))
$ceph_cluster_network    = get_network_role_property('ceph/replication', 'network')
$ceph_public_network     = get_network_role_property('ceph/public', 'network')
$mon_addr                = get_network_role_property('ceph/public', 'ipaddr')

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

if ($storage_hash['volumes_ceph']) {
  include ::cinder::params
  service { 'cinder-volume':
    ensure     => 'running',
    name       => $::cinder::params::volume_service,
    hasstatus  => true,
    hasrestart => true,
  }

  service { 'cinder-backup':
    ensure     => 'running',
    name       => $::cinder::params::backup_service,
    hasstatus  => true,
    hasrestart => true,
  }

  Class['ceph'] ~> Service['cinder-volume']
  Class['ceph'] ~> Service['cinder-backup']
}

if ($storage_hash['images_ceph']) {
  include ::glance::params
  service { 'glance-api':
    ensure     => 'running',
    name       => $::glance::params::api_service_name,
    hasstatus  => true,
    hasrestart => true,
  }

  Class['ceph'] ~> Service['glance-api']
}
