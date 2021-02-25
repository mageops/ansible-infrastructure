# --- Bash color and style codes.
def colors: {    
    reset:                  "00",

    set: {
        bold:               "01",
        dim:                "02",
        underline:          "04",
        blink:              "05",
        invert:             "07",
    },

    fg: {
        default:            "39",

        black:              "30",
        red:                "31",
        green:              "32",
        yellow:             "33",
        blue:               "34",
        magenta:            "35",
        cyan:               "36",
        gray:               "37",

        dark_gray:          "90",
        light_red:          "91",
        light_green:        "92",
        light_yellow:       "93",
        light_blue:         "94",
        light_magenta:      "95",
        light_cyan:         "96",
        white:              "97",
    },
};

def is_color_disabled: (
    ( env.MAGEOPS_NO_COLOR // false ) 
        or ( env.JQ_NO_COLOR // false )
        or ( env.NO_COLOR // false )
);

# --- Bash semantic color theme.
def theme: {
    default:    "\(colors.reset);\(colors.fg.default)",
    muted:      "\(colors.reset);\(colors.fg.gray)",
    info:       "\(colors.set.bold);\(colors.fg.dark_gray)",
    em:         "\(colors.fg.default);\(colors.set.bold)",
    header:     "\(colors.set.underline);\(colors.fg.gray)",
    title:      "\(colors.set.underline);\(colors.fg.white)",

    primary:    "\(colors.fg.default);\(colors.fg.blue)",
    primary_em: "\(colors.set.bold);\(colors.fg.blue)",
    secondary:  "\(colors.fg.default);\(colors.fg.cyan)",
    info:       "\(colors.set.bold);\(colors.fg.cyan)",
    value:      "\(colors.fg.default);\(colors.fg.magenta)",
    important:  "\(colors.set.bold);\(colors.fg.light_magenta)",

    ok:         "\(colors.fg.default);\(colors.fg.green)",
    success:    "\(colors.set.bold);\(colors.fg.light_green)",
    note:       "\(colors.reset);\(colors.fg.yellow)",
    warning:    "\(colors.set.bold);\(colors.fg.light_yellow)",
    danger:     "\(colors.reset);\(colors.fg.red)",
    error:      "\(colors.set.bold);\(colors.fg.light_red)",
};

# --- Colorizes the values using bash escape codes.
# Note: You need to pass the output through `echo -e`.
def colorize($code): 
    if is_color_disabled then ( . ) 
        else ( "\\033[\($code)m\(. | tostring)\\033[0m" ) end
;

# --- Format date as a nice, readable string.
def as_date_str: strftime("%F %R");

# --- Converts object key string to uppercase space-delimited string.
def humanize_key: gsub("_"; " ") | ascii_upcase;

# --- Converts a list of entries (key-value objects) into text definition list.
def as_defs_from_entries: .[] | "\(.key | humanize_key)\t\(.value)";

# --- Converts an object into text definition list.
def as_defs: to_entries | as_defs_from_entries;

# --- Converts an array of entry lists into text table.
def as_table_from_entries:
        ( first | map( .key ) | map( humanize_key | colorize(theme.em) ) | join("\t") ), 
        ( .[] | map( .value ) | join("\t") ) 
;

# --- Converts an array of objects into text table.
# Note: Filter the output in bash with `column -t -s$'\t'` to get nice columns.
# Note: Use `--slurp` if your output has multiple objects instead of an array.
def as_table: sort_by(.name) | map(to_entries) | as_table_from_entries;

# --- Demo the current bash color theme.
# Note: Print with `echo -e "$(jq -nr 'import "output" as out; out::print_theme_demo')" | column -t -s$'\t'`.
def print_theme_demo: null 
    | theme 
    | to_entries 
    | map( 
        .value as $code | { 
            key: .key, 
            value: "Text with theme style \"\(.key)\"" | colorize($code) 
        }
    ) | as_defs_from_entries
;

