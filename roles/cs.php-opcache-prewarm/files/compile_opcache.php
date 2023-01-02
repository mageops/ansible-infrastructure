<?php
/// This script have to be executed in php-fpm context to ensure correctly generated opcache


/* polyfill str_ends_with (PHP8+) in for older php versions */
if (! function_exists('str_ends_with')) {
    function str_ends_with(string $haystack, string $needle): bool
    {
        $needle_len = strlen($needle);
        return ($needle_len === 0 || 0 === substr_compare($haystack, $needle, - $needle_len));
    }
}

/**
 * @param array $dirs
 */
function scan_files($dirs) {
    $files = [];

    while (count($dirs) > 0) {
        $dir = array_pop($dirs);
        $entries = scandir($dir);
        foreach($entries as $entry) {
            if ($entry == "." || $entry == "..") {
                continue;
            }
            // PHP do not have any dedicated path manipulation functionality build in
            $path = $dir . DIRECTORY_SEPARATOR . $entry;
            if(is_dir($path)) {
                $dirs[] = $path;
            }else {
                if(str_ends_with($entry, ".php")) {
                    $files[] = $path;
                }
            }
        }
    }

    return $files;
}

function fail($msg) {
    http_response_code(400);
    die($msg);
}

if(isset($_POST['FILE'])) {
    opcache_compile_file($_POST['FILE']);
    die();
}

if (!isset($_POST['DIRS']) || !is_array($_POST['DIRS'])) {
    fail("");
}
$verbose = isset($_POST['VERBOSE']) && $_POST['VERBOSE'] == "1";
$list_only = isset($_POST['LIST_ONLY']) && $_POST['LIST_ONLY'] == "1";
$dirs = $_POST['DIRS'];

const MINUTE = 60;
// We do not want to use standard timeout for this operation
set_time_limit(15 * MINUTE);
gc_enable();
ob_end_flush();
// validate all dirs
foreach($dirs as $dir) {
    if(!is_string($dir) || !file_exists($dir)) {
        fail("Invalid dir");
    }
}

$files = scan_files($dirs);
if($list_only) {
    die(join("\n", $files));
}
foreach($files as $file) {
    if($verbose) {
        echo "Compile $file... ";
    }
    if(opcache_is_script_cached($file)) {
        if($verbose) {
            echo "already cached\n";
        }
    }else {
        if (opcache_compile_file($file)) {
            if($verbose) {
                echo "compiled\n";
            }
        }else {
            if($verbose) {
                echo "failed\n";
            }
        }

    }
}
