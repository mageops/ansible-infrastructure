import "out" as out;

def parse_date_str: split(".") | first | strptime("%Y-%m-%dT%H:%M:%S");

def reformat_date_str: parse_date_str | mktime | out::as_date_str;

def find_tag_value($tagName): .[] | select( .Key == $tagName ).Value;

def tags_to_object: . | sort_by(.Key) | map({ ( .Key ) : .Value }) | add;

def reservations_to_instances: .Reservations | map(.Instances) | flatten;

def instance_data: {
        project:        .Tags | find_tag_value("Project")          | out::colorize(out::theme.primary),
        environment:    .Tags | find_tag_value("Environment")      | out::colorize(out::theme.primary_em),
        role:           .Tags | find_tag_value("Role")             | out::colorize(out::theme.primary_em),
        name:           .Tags | find_tag_value("Name")             | out::colorize(out::theme.default),

        type:           .InstanceType                              | out::colorize(out::theme.default),
        launched_on:    .LaunchTime | reformat_date_str            | out::colorize(out::theme.default),
        state:          .State.Name                                | out::colorize(out::theme.info),

        private_ip:     ( .PrivateIpAddress )                      | out::colorize(out::theme.default),
        public_ip:      ( .PublicIpAddress )                       | out::colorize(out::theme.em),

        state_reason:   .StateTransitionReason                     | out::colorize(out::theme.default),
        image_id:       .ImageId                                   | out::colorize(out::theme.muted),
    }
;

# echo -e "$(ssh root@3.123.238.198 aws ec2 describe-instances \
#   | jq -r 'import "aws" as aws; import "output" as out; aws::reservations_to_instances | map(aws::instance_data) | out::as_table' \
#   | column -t -s$'\t' \
# )"