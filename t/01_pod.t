use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 or greater required for testing POD" if $@;
all_pod_files_ok();
