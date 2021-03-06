require 'spec_helper'
require 'shared-examples'
manifest = 'murano/db.pp'

describe manifest do
  murano_hash = Noop.hiera('murano')

  if murano_hash['enabled']
    shared_examples 'catalog' do
      it 'should install proper mysql-client' do
        if facts[:osfamily] == 'RedHat'
          pkg_name = 'MySQL-client-wsrep'
        elsif facts[:osfamily] == 'Debian'
          pkg_name = 'mysql-client-5.6'
        end
        should contain_package('mysql-client').with(
          'name' => pkg_name,
        )
      end
    end
  end

  test_ubuntu_and_centos manifest
end

