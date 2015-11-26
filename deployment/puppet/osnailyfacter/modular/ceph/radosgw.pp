notice('MODULAR: ceph/radosgw.pp')

$mon_address_map  = get_node_to_ipaddr_map_by_network_role(hiera_hash('ceph_monitor_nodes'), 'ceph/public')

if hiera('storage', {})['objects_ceph'] {
  # Apache and listen ports
  class { 'osnailyfacter::apache':
    listen_ports => hiera_array('apache_ports', ['80', '8888']),
  }

  if ($::osfamily == 'Debian'){
    apache::mod {'rewrite': }
    apache::mod {'fastcgi': }
  }

  include ::tweaks::apache_wrappers

  $service_endpoint = hiera('service_endpoint')
  $haproxy_stats_url = "http://${service_endpoint}:10000/;csv"

  haproxy_backend_status { 'keystone-admin' :
    name  => 'keystone-2',
    count => '200',
    step  => '6',
    url   => $haproxy_stats_url,
  }

  haproxy_backend_status { 'keystone-public' :
    name  => 'keystone-1',
    count => '200',
    step  => '6',
    url   => $haproxy_stats_url,
  }

  Haproxy_backend_status['keystone-admin']  -> Class ['ceph::keystone']
  Haproxy_backend_status['keystone-public'] -> Class ['ceph::keystone']

  class { 'ceph::rgw':
    # RadosGW settings
    rgw_port                         => '6780',
    swift_endpoint_port              => '8080',
    rgw_print_continue               => true,
    keyring_path                     => '/etc/ceph/keyring.radosgw.gateway',
    log_file                         => '/var/log/ceph/radosgw.log',
    rgw_data                         => '/var/lib/ceph/radosgw',
    rgw_dns_name                     => "*.${::domain}",
    rgw_print_continue               => true,
  }
 
  # rgw Keystone settings

  $keystone_hash    = hiera('keystone', {})

  class { 'ceph::rgw::keystone':
    rgw_keystone_url                 => "${service_endpoint}:35357",
    rgw_keystone_admin_token         => $keystone_hash['admin_token'],
    rgw_keystone_token_cache_size    => '10',
    rgw_keystone_accepted_roles      => '_member_, Member, admin, swiftoperator',
    rgw_keystone_revocation_interval => '1000000',
  }  

  Exec { path => [ '/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/' ],
    cwd  => '/root',
  }
}
