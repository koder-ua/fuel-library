require 'spec_helper'
require 'shared-examples'
manifest = 'openstack-haproxy/openstack-haproxy-sahara.pp'

describe manifest do
  test_ubuntu_and_centos manifest
end

