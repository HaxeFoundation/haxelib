resource "aws_db_option_group" "default" {
  name_prefix              = "mysql56-default-upgrade-"
  option_group_description = "Option group created for required database upgrade from RDS mysql 5.5.62 to mysql 5.6.34."
  engine_name              = "mysql"
  major_engine_version     = "5.6"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "mysql57-haxe-org" {
  name_prefix = "mysql57-haxe-org"
  family      = "mysql5.7"

  parameter {
    apply_method = "pending-reboot"
    name         = "max_allowed_packet"
    value        = "1073741824"
  }
  parameter {
    apply_method = "pending-reboot"
    name         = "max_connect_errors"
    value        = "1000"
  }
  parameter {
    name  = "general_log"
    value = "1"
  }
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "long_query_time"
    value = "1"
  }
  parameter {
    name  = "sort_buffer_size"
    value = "8388608"
  }

  parameter {
    name         = "gtid-mode"
    value        = "ON"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "enforce_gtid_consistency"
    value        = "ON"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "binlog_format"
    value = "ROW"
  }
  parameter {
    name  = "binlog_row_image"
    value = "FULL"
  }
  parameter {
    name  = "binlog_rows_query_log_events"
    value = 1
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_option_group" "mysql57-haxe-org" {
  name_prefix          = "mysql57-haxe-org"
  engine_name          = "mysql"
  major_engine_version = "5.7"

  lifecycle {
    create_before_destroy = true
  }
}
