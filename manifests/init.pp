# == Class: cloudwatchlogs
#
# Configure AWS Cloudwatch Logs on Amazon Linux instances.
#
# === Authors
#
# Douglas Sappet <dsappet@gmail.com>
#
# === Copyright
#
# Copyright 2018 Douglas Sappet
#
class cloudwatchlogs (
  $state_file           = $::cloudwatchlogs::params::state_file,
  $logging_config_file  = $::cloudwatchlogs::params::logging_config_file,
  $log_level            = $::cloudwatchlogs::params::log_level,
  $region_old           = $::cloudwatchlogs::params::region,
) inherits cloudwatchlogs::params {

# This gets the metadata of this module and grabs the version to dump to console (need to use -v when running command)
  $metadata = load_module_metadata('cloudwatchlogs')
  notify { "module version is ${$metadata['version']}" : }

#somehow move this back into params? Unit tests depended on being able to inject this.
 #$region = $cloudwatchlogs_hash['region'] # this works as well, because this class inherits ::params
  $region = $::cloudwatchlogs::params::cloudwatchlogs_hash['region']

# notify will put a console logged notification to the client when run using puppet agent -t -v -d 
# -t is test -v is verbose -d is debug info.
# optionally can add -noop to cause no actual modifications to occur
#  notify { "Notify - region var in init is [${$region}]" : }
#  notify { "Notify - Operating system is [${$::operatingsystem}]" : }
# info is used to log to the puppetmaster log file
  #info("Running init code")
  #info("Info - region var in init is [${$region}]")

  #notes for me on hiera commands
  # hiera - Performs a standard priority lookup and returns the most specific value for a given key. The returned value can be data of any type (strings, arrays, or hashes).
  # hiera_array - Returns all matches throughout the hierarchy — not just the first match — as a flattened array of unique values. If any of the matched values are arrays, they’re flattened and included in the results.
  # hiera_hash - Returns a merged hash of matches from throughout the hierarchy. In cases where two or more hashes share keys, the hierarchy order determines which key/value pair will be used in the returned hash, with the pair in the highest priority data source winning.
  
  #yes there is a difference between the $logs_ and $log_ variables here
  #this hash comes from the nested ::logs
  $logs_hiera      = hiera_hash('cloudwatchlogs::log',{})
  validate_hash($logs_hiera)

  #this hash comes from its own ::log 
  $log_hiera = hiera_hash('cloudwatchlogs::log', {})
  validate_hash($log_hiera)

  #lets combine them. Perhaps I should have used merge_deep here but I didnt want hashes combining
  $logs  = merge($logs_hiera, $log_hiera)
  validate_hash($logs)
  notify { "all them log hashes: [${$logs}]" : }

  #validate all that other stuff
  validate_absolute_path($state_file)
  validate_absolute_path($logging_config_file)
  if $region {
    validate_string($region)
  }
  if $log_level {
    validate_string($log_level)
  }

  $installed_marker = $::operatingsystem ? {
    'Amazon' => Package['awslogs'],
    default  => Exec['cloudwatchlogs-install'],
  }

  # this create_resources executes the code at log.pp as it is a `define` object given the named hashes from $logs
  create_resources('cloudwatchlogs::log', $logs)

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
          command => "python /usr/local/src/awslogs-agent-setup.py -n -r ${region} -c /etc/awslogs/awslogs.conf",
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
