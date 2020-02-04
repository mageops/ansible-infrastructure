#!/usr/bin/env bash

# We're doing this prerotate because during postrotate we don't know the filename - sometimes it's suffixed by date,
# sometimes by number and I haven't found a way to know for sure.

ACCESS_LOG="$1"

if [[ $ACCESS_LOG = */error* ]] ; then
    echo "The file $ACCESS_LOG is probably an error log, skipping..." >&2
    exit
fi

# Remove weekly DB at the on each monday start collecting new data
[ "$(date '+%w')" == '1' ] && rm -f "{{ goaccess_data_dir }}/weekly/*.tcb"

# Remove monthly DB at the start of each month to start collecting new data
[ "$(date '+%d')" == '01' ] && rm -f "{{ goaccess_data_dir }}/monthly/*.tcb"

# Use load-from-disk only if the DB already exists (this is crap, but how goaccess works)
# When previous DB is loaded form disk newly parsed data will be appended
([ -z "$(ls -A {{ goaccess_data_dir }}/weekly/*.tcb 2>/dev/null)" ] && LOAD_WEEKLY_DB="") || LOAD_WEEKLY_DB="--load-from-disk"
([ -z "$(ls -A {{ goaccess_data_dir }}/monthly/*.tcb 2>/dev/null)" ] && LOAD_MONTHLY_DB="") || LOAD_MONTHLY_DB="--load-from-disk"

/usr/bin/goaccess "$ACCESS_LOG" --db-path="{{ goaccess_data_dir }}/daily/" --keep-db-files --compression=zlib --log-format=COMBINED -o "{{ goaccess_report_dir }}/daily.html" --html-report-title="Daily {{ mageops_project }} ({{ mageops_environment }})" --agent-list
/usr/bin/goaccess "$ACCESS_LOG" --db-path="{{ goaccess_data_dir }}/weekly/" --keep-db-files --compression=zlib --log-format=COMBINED -o "{{ goaccess_report_dir }}/weekly.html" $LOAD_WEEKLY_DB --html-report-title="Weekly {{ mageops_project }} ({{ mageops_environment }})" --agent-list
/usr/bin/goaccess "$ACCESS_LOG" --db-path="{{ goaccess_data_dir }}/monthly/" --keep-db-files --compression=zlib --log-format=COMBINED -o "{{ goaccess_report_dir }}/monthly.html" $LOAD_MONTHLY_DB --html-report-title="Monthly {{ mageops_project }} ({{ mageops_environment }})" --agent-list

# Generate JSON reports, do not rescan, just use the existing DBs
/usr/bin/goaccess --db-path="{{ goaccess_data_dir }}/daily/" --keep-db-files --compression=zlib --log-format=COMBINED -o "{{ goaccess_report_dir }}/daily.json" --load-from-disk --json-pretty-print --agent-list
/usr/bin/goaccess --db-path="{{ goaccess_data_dir }}/weekly/" --keep-db-files --compression=zlib --log-format=COMBINED -o "{{ goaccess_report_dir }}/weekly.json" --load-from-disk --json-pretty-print --agent-list
/usr/bin/goaccess --db-path="{{ goaccess_data_dir }}/monthly/" --keep-db-files --compression=zlib --log-format=COMBINED -o "{{ goaccess_report_dir }}/monthly.json" --load-from-disk --json-pretty-print --agent-list
