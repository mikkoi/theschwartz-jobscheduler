#!perl
# no critic (ControlStructures::ProhibitPostfixControls)
## no critic (ValuesAndExpressions::ProhibitMagicNumbers)

use strict;
use warnings;

use utf8;
use Test2::V0;
set_encoding('utf8');

use Data::Dumper;

# Activate for testing
use Log::Any::Adapter ('Stdout', log_level => 'debug' );

use FindBin 1.51 qw( $RealBin );
use File::Spec;
my $lib_path;
BEGIN {
    $lib_path = File::Spec->catdir(($RealBin =~ /(.+)/msx)[0], q{.}, 'lib');
}
use lib "$lib_path";

# use Path::Tiny;

# use TheSchwartz::JobScheduler::TestingUtils;
use TheSchwartz::JobScheduler;

use Test::Database::Temp;

use Module::Load qw( load );

# Luo temp db
# Luo MaangedHandleConfig
# Alusta db

my @drivers = qw( Pg SQLite );
sub init_db {
    my ($driver, $dbh, $name) = @_;
    # my $schema_path = File::Spec->catdir(($RealBin =~ /(.+)/msx)[0], q{.},
    #         'schemas', "${driver}.sql");
    # diag Dumper $schema_path;
    # my $schema = path($schema_path)->slurp_utf8;
    my $module = "TheSchwartz::Database::Schemas::${driver}";
    load $module;
    my $schema = $module->new->schema;
    $dbh->begin_work();
    foreach my $row (split qr/;\s*/msx, $schema) {
        $dbh->do( $row );
    }
    $dbh->commit;
    return;
}

sub build_test_dbs {
    my ($self) = @_;
    # diag 'Create temp databases';
    # my @test_dbs;
    my %test_dbs;
    foreach my $driver (@drivers) {
        my $test_db = Test::Database::Temp->new(
            driver => $driver,
            init => sub {
                my ($dbh, $name) = @_;
                init_db( $driver, $dbh, $name);
            },
        );
        # diag 'Test database (' . $test_db->driver . ') ' . $test_db->name . " created.\n";
        # push @test_dbs, $test_db;
        # my @dbs;
        # @dbs = @{ $test_dbs{$driver} } if( exists $test_dbs{$driver} );
        # push @dbs, $test_db;
        # $test_dbs{$driver} = \@dbs;
        # my $name = $test_db->name
        $test_dbs{$driver}->{ $test_db->name } = $test_db;
    }
    return %test_dbs;
}

sub build_managed_handle_config {
    my (@test_dbs) = @_;
    my %cfg = (
        default => $test_dbs[0]->name,
    );
    foreach my $db (@test_dbs) {
        my $name = $db->name();
        my @info = $db->connection_info();
        my %c;
        @c{'dsn','username','password','attr'} = @info;
        $cfg{'databases'}->{$name} = \%c;
    }
    return \%cfg;
}

# ##############################################################################
# BEGIN {
#     my @test_dbs = build_test_dbs();
#     diag Dumper \@test_dbs;
#
#     {
#         package Database::ManagedHandleConfigLocal;
#         use Moo;
#         has config => (
#             is => 'ro',
#             default => sub {
#                 return main::build_managed_handle_config(@test_dbs);
#             },
#         );
#
#         1;
#     }
#
#     ## no critic (Variables::RequireLocalizedPunctuationVars)
#     $ENV{DATABASE_MANAGED_HANDLE_CONFIG} = 'Database::ManagedHandleConfigLocal';
#     use Database::ManagedHandle;
# }

my %test_dbs = build_test_dbs();
subtest 'Insert Job and Verify' => sub {
    # my $mh = Database::ManagedHandle->instance;
    # my @test_dbs;
    foreach my $driver (@drivers) {
        diag 'Testing with ' . $driver;
        # my @dbs = @{$test_dbs{ $driver }};
        # diag 'We have ' . @dbs . ' databases to test against.';
        my $get_dbh = sub {
            my ($id) = @_;
            my $db = $test_dbs{ $driver }->{ $id };
            return DBI->connect( $db->connection_info );
        };
        my %databases;
        foreach my $id (keys %{ $test_dbs{ $driver } }) {
            $databases{ $id } = {
                # dbh_callback => 'Database::ManagedHandle->instance',
                dbh_callback => $get_dbh,
                prefix => q{}
            };
        }
        my $client = TheSchwartz::JobScheduler->new(
            \%databases, # databases
            );

        # &{ $get_dbh }()->start_work;
        my $jobid_1 = $client->insert('fetch', 'http://wassr.jp/');
        # &{ $get_dbh }()->end_work;
        is($jobid_1, 1, 'Job id is 1');

        my $jobid_2 = $client->insert(
            TheSchwartz::JobScheduler::Job->new(
                funcname => 'fetch',
                arg      => {type=>'site',url => 'http://pathtraq.com/'},
                priority => 3,
                )
            );
        is($jobid_2, 2, 'Job id is 2');

        my @jobs = $client->list_jobs({ funcname => 'fetch'});
        my $row = $jobs[0];
        ok($row, 'Jobs[0] exists');
        is($row->jobid,    1, 'jobs[0]->jobid is 1');
        # is $row->funcid,   $client->funcname_to_id( $dbh, $prefix, 'fetch' );
        is($row->arg,      'http://wassr.jp/', 'arg(scalar) is correct');
        is($row->priority, undef, 'priority is correct');

        $row = $jobs[1];
        ok($row, 'Jobs[1] exists');
        is($row->jobid,    2, 'jobs[0]->jobid is 2');
        # is $row->funcid,   $client->funcname_to_id( $dbh, 'fetch' );
        is($row->arg,      {type=>'site',url => 'http://pathtraq.com/'}, 'arg(hash) is correct');
        is($row->priority, 3, 'priority is correct');
    }
    done_testing;
};
done_testing;
