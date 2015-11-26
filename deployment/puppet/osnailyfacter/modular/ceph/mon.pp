notice('MODULAR: ceph/mon.pp')

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

class { 'ceph::repo': }

$storage_hash = hiera('storage', {})
$mon_address_map = get_node_to_ipaddr_map_by_network_role(hiera_hash('ceph_monitor_nodes'), 'ceph/public')
$admin_key = hiera('admin_key')
$mon_key = hiera('mon_key')
$bootstrap_osd_key = hiera('bootstrap_osd_key')
$fsid = hiera('fsid')
$osd_journal_size = hiera(osd_journal_size, "2048")

prepare_network_config(hiera_hash('network_scheme'))
$ceph_cluster_network    = get_network_role_property('ceph/replication', 'network')
$ceph_public_network     = get_network_role_property('ceph/public', 'network')

class { 'ceph':
  fsid                => $fsid,
  osd_journal_size         => $osd_journal_size,
  osd_pool_default_pg_num  => $storage_hash['pg_num'],
  osd_pool_default_pgp_num => $storage_hash['pg_num'],
  osd_pool_default_size    => $storage_hash['osd_pool_size'],
  mon_initial_members      => values($mon_address_map),
  mon_hosts                => keys($mon_address_map),
  cluster_network          => $ceph_cluster_network,
  public_network           => $ceph_public_network,
  mon_initial_members => 'mon1,mon2,mon3',
  mon_host            => '<ip of mon1>,<ip of mon2>,<ip of mon3>',
}

ceph::mon { $::hostname:
  key => $mon_key,
}

Ceph::Key {
  inject         => true,
  inject_as_id   => 'mon.',
  inject_keyring => "/var/lib/ceph/mon/ceph-${::hostname}/keyring",
}

ceph::key { 'client.admin':
  secret  => $admin_key,
  cap_mon => 'allow *',
  cap_osd => 'allow *',
  cap_mds => 'allow',
}

ceph::key { 'client.bootstrap-osd':
  secret  => $bootstrap_osd_key,
  cap_mon => 'allow profile bootstrap-osd',
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
