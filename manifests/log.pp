define cloudwatchlogs::log (
  Optional[String] $log_path                 = undef,
  String           $streamname               = '{instance_id}',
  String           $datetime_format          = '%b %d %H:%M:%S',
  Optional[String] $multi_line_start_pattern = undef,
){
  concat::fragment { "cloudwatchlogs_fragment_${name}":
    target  => '/etc/awslogs/awslogs.conf',
    content => template('cloudwatchlogs/awslogs_log.erb'),
    order   => '01',
  }
}
