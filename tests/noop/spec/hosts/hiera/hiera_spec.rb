require 'spec_helper'
require 'shared-examples'
manifest = 'hiera/hiera.pp'

describe manifest do
  shared_examples 'catalog' do
    it 'should setup hiera' do
      should contain_file('hiera_data_dir').with(
        'ensure' => 'directory',
        'path'   => '/etc/hiera'
      )
      should contain_file('hiera_config').with(
        'ensure' => 'present',
        'path'   => '/etc/hiera.yaml'
      )
      # ensure deeper merge_behavior is being set
      should contain_file('hiera_config').with_content(/deeper/)
      # check symlinks
      should contain_file('hiera_data_astute').with(
        'ensure' => 'symlink',
        'path'   => '/etc/hiera/astute.yaml',
        'target' => '/etc/astute.yaml'
      )
      should contain_file('hiera_puppet_config').with(
        'ensure' => 'symlink',
        'path'   => '/etc/puppet/hiera.yaml',
        'target' => '/etc/hiera.yaml'
      )
    end
    it 'should have ruby deep_merge installed' do
      case facts[:operatingsystem]
      when 'Ubuntu'
        package_name = 'ruby-deep-merge'
      when 'CentOS'
        package_name = 'rubygem-deep_merge'
      end

      should contain_package('rubygem-deep_merge').with(
        'ensure' => 'present',
        'name'   => package_name
      )
    end
  end

  test_ubuntu_and_centos manifest
end

