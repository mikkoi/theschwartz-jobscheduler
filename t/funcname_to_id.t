#!perl
use strict;
use warnings;

use utf8;
use Test2::V0;
set_encoding('utf8');

use FindBin 1.51 qw( $RealBin );
use File::Spec;
my $lib_path;
BEGIN {
    $lib_path = File::Spec->catdir(($RealBin =~ /(.+)/msx)[0], q{.}, 'lib');
}
use lib "$lib_path";

# use TheSchwartz::JobScheduler::TestingUtils;
use TheSchwartz::JobScheduler;

subtest 'Code is syntactically correct' => sub {
    # foreach $::prefix ("", "someprefix") {
    #
    #     run_test {
    #         my $dbh1 = shift;
    #         run_test {
    #             my $dbh2 = shift;
    #
    #             my $sch = TheSchwartz::Simple->new([$dbh1, $dbh2]);
    #             $sch->prefix($::prefix) if $::prefix;
    #             isa_ok $sch, 'TheSchwartz::Simple';
    #             is $sch->funcname_to_id($dbh1, 'foo'), 1;
    #             is $sch->funcname_to_id($dbh1, 'bar'), 2;
    #             is $sch->funcname_to_id($dbh1, 'foo'), 1;
    #             is $sch->funcname_to_id($dbh1, 'baz'), 3;
    #             is $sch->funcname_to_id($dbh2, 'bar'), 1, 'other dbh';
    #
    #             my $job_id = $sch->insert('foo', { bar => 1 });
    #             ok $job_id;
    #         };
    #     };
    #
    # }
    pass('fool');
    done_testing;
};

done_testing;
