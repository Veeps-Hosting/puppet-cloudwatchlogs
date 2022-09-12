# cloudwatchlogs [![Build Status](https://travis-ci.org/Veeps-Hosting/puppet-cloudwatchlogs.svg)](https://travis-ci.org/Veeps-Hosting/puppet-cloudwatchlogs)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with cloudwatchlogs](#setup)
    * [What cloudwatchlogs affects](#what-cloudwatchlogs-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with cloudwatchlogs](#beginning-with-cloudwatchlogs)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview
This module is a fork of [this repo](https://github.com/kemra102/puppet-cloudwatchlogs) that has been fixed to work with hiera. Examples have been adjusted to be hiera yaml examples. Otherwise the functionality is very similar.
This module installs, configures and manages the service for the AWS Cloudwatch Logs Agent on Amazon Linux, Ubuntu, Red Hat & CentOS EC2 instances.

## Module Description

CloudWatch Logs can be used to monitor your logs for specific phrases, values, or patterns. For example, you could set an alarm on the number of errors that occur in your system logs or view graphs of web request latencies from your application logs. You can view the original log data to see the source of the problem if needed. Log data can be stored and accessed for as long as you need using highly durable, low-cost storage so you don’t have to worry about filling up hard drives.

## Setup

### What cloudwatchlogs affects

* The `awslogs` package.
* Configuration files under `/etc/awslogs`.
* The `awslogs` service.

### Setup Requirements

This module does *NOT* manage the AWS CLI credentials. As such if you are not using an IAM role (recommended) then you will need some other way of managing the credentials.

[This module](https://forge.puppetlabs.com/jdowning/awscli) by [Justin Downing](https://github.com/justindowning) is recommended for this purpose.

### Beginning with cloudwatchlogs
*ALL EXAMPLES ARE FOR HIERA IN YAML*

The minimum you need to get this module up and running is (assuming your instance is launched with a suitable IAM role):

```yaml
classes:
- cloudwatchlogs

cloudwatchlogs:
```

## Usage

On NON *Amazon Linux* instances you also need to provide a default region:

```yaml
classes:
- cloudwatchlogs
cloudwatchlogs:
  region: 'eu-west-1'
```
For each log you want send to Cloudwatch Logs you create a `cloudwatchlogs::log` resource.
This shall be set as its own item. It requires a name for each log to create so that a nested object is created.

A simple example that might be used on the RedHat *::osfamily* is:

```yaml
classes:
- cloudwatchlogs
cloudwatchlogs:
  region: 'eu-west-1'
cloudwatchlogs::log:
  'Messages':
    path: '/var/log/messages'
  'Node':
    path: '/path/to/your/node.log'

```

See the *examples/* directory for further examples.

## Reference

### `cloudwatchlogs`

#### `state_file`:

Defaults:

* Amazon Linux: `/var/lib/awslogs/agent-state`
* Other: `/var/awslogs/state/agent-state`

State file for the awslogs agent.

#### `logging_config_file`:

Defaults: `/etc/awslogs/awslogs_dot_log.conf`

Config file for the awslogs agent logging system (http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/AgentReference.html).

#### `region`:

Default: `undef`

#### `log_level`:

Default: `undef`

The region your EC2 instance is running in.

**NOTE:** This is required for none *Amazon* distros.

### `cloudwatchlogs::log`

#### `path`

Default: `undef`

Optional. This is the absolute path to the log file being managed. If not set the name of the resource is used instead (and must be an absolute path if that this situation occurs).

#### `streamname`

Default: `{instance_id}`

The name of the stream in Cloudwatch Logs. This should be a string like all the others. See the ams cloudwatch logs docs for options. One other common option is `{hostname}`

#### `datetime_format`

Default: `%b %d %H:%M:%S`

Specifies how the timestamp is extracted from logs. See [the official docs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/AgentReference.html) for further info.

#### `log_group_name`

Default: *Resource Name*

Specifies the destination log group. A log group will be created automatically if it doesn't already exist.

#### `multi_line_start_pattern`

Default: `undef`

Optional. This is a regex string that identifies the start of a log line. See [the official docs](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/AgentReference.html) for further info.

#### `Example`

```yaml
classes:
- cloudwatchlogs

cloudwatchlogs:
  region: 'eu-west-1'

cloudwatchlogs::log:
  'node':
    path: '/path/to/your/logfile.log'
    streamname: '{hostname}'
    datetime_format: '%Y-%m-%dT%H:%M:%S%z'
    log_group_name: 'my-node-project'
  'Messages':
    path: '/var/log/messages'
    streamname: '{hostname}'
    log_group_name: 'system-messages'
```

## Http Proxy Usage

If you have a http_proxy or https_proxy then run the following puppet code after calling cloudwatchlogs to modify the launcher script as a workaround bcause awslogs python code currently doesn't have http_proxy support:

```puppet
$launcher = "#!/bin/sh
# Version: 1.3.5
echo -n $$ > /var/awslogs/state/awslogs.pid
/usr/bin/env -i AWS_CONFIG_FILE=/var/awslogs/etc/awscli.conf HOME=\$HOME HTTPS_PROXY=${http_proxy} HTTP_PROXY=${http_proxy} NO_PROXY=169.254.169.254  /bin/nice -n 4 /var/awslogs/bin/aws logs push --config-file /var/awslogs/etc/awslogs.conf >> /var/log/awslogs.log 2>&1
"

file { '/var/awslogs/bin/awslogs-agent-launcher.sh':
  ensure  => file,
  owner   => root,
  group   => root,
  mode    => '0755',
  content => $launcher,
  require => Class['cloudwatchlogs'],
}
```

## Limitations

This module is currently only compatible with:

* Amazon Linux AMI 2014.09 or later.
* Ubuntu
* Red Hat
* CentOS

More information on support as well as information in general about the set-up of the Cloudwatch Logs agent can be found [here](http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/QuickStartEC2Instance.html).

## Development

Contributions are welcome via pull requests.
To test and build:
Download the Puppet Development Kit from [https://puppet.com/download-puppet-development-kit]
To build run `pdk build` from terminal in project folder
To run lint and validator `pdk validate`
To run unit tests `pdk test unit`

## Contributors
Authors:

* [Grant Davies](https://github.com/Veeps-Hosting)

Original Repo Authors:
* [Douglas Sappet](https://github.com/Veeps-Hosting)
* [Danny Roberts](https://github.com/kemra102)
* [Russ McKendrick](https://github.com/russmckendrick/)

All other contributions: [https://github.com/Veeps-Hosting/puppet-cloudwatchlogs/graphs/contributors](https://github.com/Veeps-Hosting/puppet-cloudwatchlogs/graphs/contributors)
