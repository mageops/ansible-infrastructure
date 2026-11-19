Push cloudwatch log messages to slack hook via lambda
=====================================================

There are two required parameters:

```
aws_logs_slack_hook_url: 
aws_logs_slack_channel: "#m2c-notifications"
```

By default, the Lambda derives its daily Slack suppression window from
`mageops_security_updates_install_timer_on_calendar` (`*-*-* 03:00` by default).
The window starts at that time and lasts 60 minutes in `mageops_timezone`.
Set `aws_logs_slack_maintenance_duration_minutes` to change the duration.
This covers the default 30-minute randomized delay and 30 more minutes for
installation. To use an independent recurring schedule, set windows in
inventory:

```yaml
aws_logs_slack_maintenance_windows:
  - start: '02:00'
    end: '03:00'
```

Times use 24-hour `HH:MM` format in `mageops_timezone`. Windows repeat daily
and can cross midnight (for example, `23:00` to `01:00`); the end time is
exclusive. Multiple windows are
supported. Set `aws_logs_slack_maintenance_windows: []` to send alerts at all
times. Events skipped during maintenance remain in CloudWatch Logs and are not
replayed to Slack afterward. Start and end times must differ. The automatic
default supports a daily `*-*-* HH:MM` install timer; for other timer patterns,
set `aws_logs_slack_maintenance_windows` explicitly.
