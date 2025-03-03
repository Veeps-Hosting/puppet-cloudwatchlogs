# == Class: cloudwatchlogs
#
# Configure AWS Cloudwatch Logs on Amazon Linux instances.
#
# === Authors
#
# Grant Davies 
#
class cloudwatchlogs (
  String           $state_file          = $::cloudwatchlogs::params::state_file,
  String           $logging_config_file = $::cloudwatchlogs::params::logging_config_file,
  Optional[String] $log_level           = $::cloudwatchlogs::params::log_level,
  Optional[Hash]   $logs                = {},
  String           $region              = $::cloudwatchlogs::params::region,
) inherits cloudwatchlogs::params {

  create_resources('cloudwatchlogs::log', $logs)

  $installed_marker = $::operatingsystem ? {
    'Amazon' => Package['awslogs'],
    default  => Exec['cloudwatchlogs-install'],
  }

  case $::operatingsystem {
    'Amazon': {
      package { 'awslogs':
        ensure => 'present',
      }

      concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
        require        => Package['awslogs'],
      }
      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }

      if $region {
        file_line { 'region-on-awslogs':
          path    => '/etc/awslogs/awscli.conf',
          line    => "region = ${region}",
          match   => '^region\s*=',
          notify  => Service[$service_name],
          require => Package['awslogs'],
        }
      }

      service { $service_name:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
      }
    }
    /^(Ubuntu|CentOS|RedHat)$/: {
      if ! defined(Package['wget']) {
        package { 'wget':
          ensure => 'present',
        }
      }

      exec { 'cloudwatchlogs-wget':
        path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
        command => 'wget -O /usr/local/src/awslogs-agent-setup.py https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py',
        unless  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
        require => Package['wget'],
      }

      file { '/etc/awslogs':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      } ->
      concat { '/etc/awslogs/awslogs.conf':
        ensure         => 'present',
        owner          => 'root',
        group          => 'root',
        mode           => '0644',
        ensure_newline => true,
        warn           => true,
      } ->
      file { '/etc/awslogs/config':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      concat::fragment { 'awslogs-header':
        target  => '/etc/awslogs/awslogs.conf',
        content => template('cloudwatchlogs/awslogs_header.erb'),
        order   => '00',
      }
      file { '/var/awslogs':
        ensure => 'directory',
      } ->
      file { '/var/awslogs/etc':
        ensure => 'directory',
      } ->
      file { '/var/awslogs/etc/awslogs.conf':
        ensure => 'link',
        target => '/etc/awslogs/awslogs.conf',
      } ->
      file { '/var/awslogs/etc/config':
        ensure => 'link',
        force  => true,
        target => '/etc/awslogs/config',
      }

      if ($region == undef) {
        fail("region must be defined on ${::operatingsystem}")
      } else {
        exec { 'cloudwatchlogs-install':
          path    => '/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
          command => "python2 /usr/local/src/awslogs-agent-setup.py -n -r ${region} -c /etc/awslogs/awslogs.conf",
          onlyif  => '[ -e /usr/local/src/awslogs-agent-setup.py ]',
          unless  => '[ -d /var/awslogs/bin ]',
          require => [
            Concat['/etc/awslogs/awslogs.conf'],
            Exec['cloudwatchlogs-wget']
          ],
          before  => [
            Service[$service_name],
            File['/var/awslogs/etc/awslogs.conf'],
          ]
        }
      }

      service { $service_name:
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => Concat['/etc/awslogs/awslogs.conf'],
        require    => File['/var/awslogs/etc/awslogs.conf'],
      }
    }
    default: { fail("The ${module_name} module is not supported on ${::osfamily}/${::operatingsystem}.") }
  }

  if $log_level {
    file { '/etc/awslogs/awslogs_dot_log.conf':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('cloudwatchlogs/awslogs_logging_config_file.erb'),
        notify  => Service[$service_name],
        require => $installed_marker,
    }
  }
}
