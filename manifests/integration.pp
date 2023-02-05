# @summary
#   Installs and configures a single New Relic Infrastructure Agent Integration.
#
# @example
#  newrelic_infra::integration { 'nri-rabbitmq':
#    ensure     => present,
#    properties => {
#      env              => {
#        USERNAME => 'monitoring',
#        PASSWORD => $monitoring_password,
#      },
#      interval         => '15s',
#      labels           => {
#        env  => 'production',
#        role => 'rabbitmq',
#      },
#      inventory_source => 'config/rabbitmq',
#    }
#  }
#
# @param config_dir
#   The directory in which the plugin configuration file should be placed.
#
# @param config_file
#   The name of the configuration file. Defaults to "${title}.yml".
#
# @param ensure
#   The state of the integration package; can be one of 'present', 'absent',
#   'latest', 'config', or (on supported platforms) a version string. If set to
#   'config', a config file will be created without any package being installed
#   (useful for custom integrations).
#
# @param package
#   The name of the package to install, such as 'nri-apache'. Defaults to the
#   resource title.
#
# @param properties
#   A map containing the configuration properties of the integration. The
#   'name' property defaults to the resource title. If you wish to define more
#   than one instance of an integration in the same file, you can pass an array
#   of maps instead.
define newrelic_infra::integration(
  String              $config_dir  = '/etc/newrelic-infra/integrations.d',
  Optional[String]    $config_file = "${title}-config.yml",
  String              $ensure      = 'present',
  String[1]           $package     = $title,
  Variant[Array,Map]  $properties  = {},
) {
  if $ensure != 'config' {
    case $::operatingsystem {
      'Debian', 'Ubuntu', 'RedHat', 'CentOS','Amazon', 'OracleLinux': {
        package { $package:
          ensure => $ensure,
        }
      }
      'OpenSuSE', 'SuSE', 'SLED', 'SLES': {
        if 'ensure' in ['present', 'latest'] {
          exec { "install_${package}":
            command => "/usr/bin/zypper install -y ${package}",
            path    => ['/usr/local/sbin', '/usr/local/bin', '/sbin', '/bin', '/usr/bin'],
            require => Exec['add_newrelic_integrations_repo'],
            unless  => "/bin/rpm -qa | /usr/bin/grep ${package}"
          }
        } elsif $ensure == 'absent' {
          exec { "install_${package}":
            command => "/usr/bin/zypper remove -y ${package}",
            path    => ['/usr/local/sbin', '/usr/local/bin', '/sbin', '/bin', '/usr/bin'],
            onlyif  => "/bin/rpm -qa | /usr/bin/grep ${package}"
          }
        } else {
          fail("When using Zypper, the only supported values of ensure are 'present', 'latest', or 'absent', not '${ensure}'.")
        }
      }
      default: {
        fail('New Relic Integrations package is not yet supported on this platform')
      }
    }
  }

  $config_ensure = $ensure ? {
    'absent' => 'absent',
    default  => 'file',
  }

  if $properties =~ Array {
    $config_data = { integrations => map($properties) |$prop| { { name => $title } + $prop } }.to_yaml
  } else {
    $config_data = { integrations => [ { name => $title } + $properties ] }.to_yaml
  }

  file { "${config_dir}/${config_file}":
    ensure  => $config_ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => $config_data,
  }
}
