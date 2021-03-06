# == Class: pacemaker_wrappers::rabbitmq
#
# Overrides rabbitmq service provider as a pacemaker
#
# TODO(bogdando) that one just an example of Pacemaker service
#   provider wrapper implementation and should be moved to openstack_extra
#   and params should be described
#

class pacemaker_wrappers::rabbitmq (
  $primitive_type     = 'rabbitmq-server',
  $service_name       = $::rabbitmq::service_name,
  $port               = $::rabbitmq::port,
  $debug              = false,
  $ocf_script_file    = 'cluster/ocf/rabbitmq',
  $command_timeout    = '',
  $erlang_cookie      = 'EOKOWXQREETZSHFNTPEY',
) inherits ::rabbitmq::service {

  $parameters      = {
    'node_port'       => $port,
    'debug'           => $debug,
    'command_timeout' => $command_timeout,
    'erlang_cookie'   => $erlang_cookie,
  }

  $metadata        = {
    'migration-threshold' => 'INFINITY',
    'failure-timeout'     => '360s'
  }

  $ms_metadata     = {
    'notify'      => 'true',
    # We shouldn't enable ordered start for parallel start of RA.
    'ordered'     => 'false',
    'interleave'  => 'true',
    'master-max'  => '1',
    'master-node-max' => '1',
    'target-role' => 'Master'
  }

  $operations      = {
    'monitor' => {
      'interval' => '30',
      'timeout'  => '60'
    },
    'monitor:Master' => { # name:role
      'role' => 'Master',
      # should be non-intercectable with interval from ordinary monitor
      'interval' => '27',
      'timeout'  => '60'
    },
    'monitor'           => {
      'interval'        => '103',
      'timeout'         => '60',
      'OCF_CHECK_LEVEL' => '30'
    },
    'start'     => {
      'timeout' => '360'
    },
    'stop' => {
      'timeout' => '120'
    },
    'promote' => {
      'timeout' => '120'
    },
    'demote' => {
      'timeout' => '120'
    },
    'notify' => {
      'timeout' => '180'
    },
  }

  pacemaker_wrappers::service { $service_name :
    primitive_type      => $primitive_type,
    complex_type        => 'master',
    metadata            => $metadata,
    ms_metadata         => $ms_metadata,
    operations          => $operations,
    parameters          => $parameters,
    #    ocf_script_file     => $ocf_script_file,
  }
  Service[$service_name] -> Rabbitmq_user <||>
}
