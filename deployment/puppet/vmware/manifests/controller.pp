#    Copyright 2014 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

# modules needed: nova
# limitations:
# - only one vcenter supported

class vmware::controller (
  $vcenter_settings = undef,
  $api_retry_count = 5,
  $datastore_regex = undef,
  $amqp_port = '5673',
  $compute_driver = 'vmwareapi.VMwareVCDriver',
  $ensure_package = 'present',
  $maximum_objects = 100,
  $nova_conf = '/etc/nova/nova.conf',
  $task_poll_interval = 5.0,
  $vcenter_cluster = 'cluster',
  $vcenter_host_ip = '10.10.10.10',
  $vcenter_user = 'user',
  $vcenter_password = 'password',
  $vlan_interface = undef,
  $vnc_address = '0.0.0.0',
  $use_linked_clone = true,
  $use_quantum = false,
  $wsdl_location = undef
)
{
  include nova::params

  # Stubs from nova class in order to not include whole class
  if ! defined(Class['nova']) {
    exec { 'post-nova_config':
      command     => '/bin/echo "Nova config has changed"',
      refreshonly => true,
    }
    exec { 'networking-refresh':
      command     => '/sbin/ifdown -a ; /sbin/ifup -a',
      refreshonly => true,
    }
    package { 'nova-common':
      ensure  => 'installed',
      name    => 'binutils',
    }
  }

  # Split provided string with cluster names and enumerate items.
  # Index is used to form file names on host system, e.g.
  # /etc/sysconfig/nova-compute-vmware-0
  $vsphere_clusters = vmware_index($vcenter_cluster)

  if ($::operaringsystem == 'Ubuntu') {
    $libvirt_type = hiera('libvirt_type')
    $compute_package_name = "nova-compute-${libvirt_type}"
  } else {
    $compute_package_name = $::nova::params::compute_package_name
  }

  package { 'nova-compute':
    name   => $compute_package_name,
    ensure => 'present',
  }

  service { 'nova-compute':
    name   => $::nova::params::compute_service_name,
    ensure => 'stopped',
    enable => false
  }

  file { 'vcenter-nova-compute-ocf':
    path   => '/usr/lib/ocf/resource.d/fuel/nova-compute',
    source => 'puppet:///modules/vmware/ocf/nova-compute',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Create nova-compute per vsphere cluster
  create_resources(vmware::compute::ha, parse_vcenter_settings($vcenter_settings))

  Package['nova-compute']->
  Service['nova-compute']->
  File['vcenter-nova-compute-ocf']->
  Vmware::Compute::Ha<||>->

  # network configuration
  class { 'vmware::network':
    use_quantum => $use_quantum,
  }

  # Enable metadata service on Controller node
  # Set correct parameter for vnc access
  nova_config {
    'DEFAULT/enabled_apis': value => 'ec2,osapi_compute,metadata';
    'DEFAULT/novncproxy_base_url': value => "http://${vnc_address}:6080/vnc_auto.html";
  } -> Service['nova-compute']

  # install cirros vmdk package
  package { 'cirros-testvmware':
    ensure => present
  }
  package { 'python-suds':
    ensure => present
  }
}

