# TODO(bogdando) add monit ceph-osd services monitoring, if required
notice('MODULAR: ceph-osd.pp')

$storage_hash = hiera('storage', {})
$bootstrap_osd_key = hiera('bootstrap_osd_key')
$fsid = hiera('fsid')
$osd_journal_size = hiera(osd_journal_size, "2048")

$mon_address_map     = get_node_to_ipaddr_map_by_network_role(
                          hiera_hash('ceph_monitor_nodes'),
                          'ceph/public')

# prepare_network_config is set some global variable,
# used by get_network_role_property
class { 'ceph::repo': }

prepare_network_config(hiera_hash('network_scheme'))
$ceph_cluster_network = get_network_role_property('ceph/replication', 'network')
$ceph_public_network  = get_network_role_property('ceph/public', 'network')

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
}

$osd_devices = split($::osd_devices_list, ' ')

define osd_handler {
  if ':' in $name {
    $data_and_journal = split($name, ':')
    # if size($data_and_journal) != 2 {
    #   fail(???????)
    # }
    $data = $data_and_journal[0]
    $journal = $data_and_journal[1]
  } else {
    $data = $name
    $journal = undef
  }

  ceph::osd {$data:
    journal => $journal,
  }
}

osd_handler { $osd_devices: }

ceph::key {'client.bootstrap-osd':
   keyring_path => '/var/lib/ceph/bootstrap-osd/ceph.keyring',
   secret       => $bootstrap_osd_key,
}

notify {"ceph_osd: ${osd_devices}": }
notify {"osd_devices:  ${::osd_devices_list}": }
