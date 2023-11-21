#!perl
# no critic (ControlStructures::ProhibitPostfixControls)
# no critic (ValuesAndExpressions::ProhibitMagicNumbers)
# no critic (RegularExpressions::ProhibitComplexRegexes)

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

use Module::Load qw( load );
use DBI;

# use Path::Tiny;

# use TheSchwartz::JobScheduler::TestingUtils;
use TheSchwartz::JobScheduler;

use Database::Temp;

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
        my $test_db = Database::Temp->new(
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

subtest 'Insert Jobs With Same uniqkey, policy "no_check", and Receive an Exception' => sub {
    foreach my $driver (@drivers) {
        diag 'Testing with ' . $driver;
        my $get_dbh = sub {
            my ($id) = @_;
            my $db = $test_dbs{ $driver }->{ $id };
            return DBI->connect( $db->connection_info );
        };
        my %databases;
        foreach my $id (keys %{ $test_dbs{ $driver } }) {
            $databases{ $id } = {
                dbh_callback => $get_dbh,
                prefix => q{}
            };
        }

        # Start
        my $client = TheSchwartz::JobScheduler->new(
            databases => \%databases,
            opts => {
                handle_uniqkey => 'no_check',
                }
            );

        my $job = TheSchwartz::JobScheduler::Job->new(
            funcname => 'Test::uniqkey',
            arg      => { an_item => 'value A' },
            uniqkey  => 'UNIQUE_STR_A',
            );

        my $jobid_1 = $client->insert( $job );
        ok( $jobid_1, 'Got a job id');

        $job->arg( { an_item => 'value B' } );
        ## no critic (RegularExpressions::RequireExtendedFormatting)
        like(
            dies { $client->insert( $job ); },
            qr/DBD::[[:word:]]{1,}::st execute failed:/ms,
            'Failed as expected',
            );
    }
    done_testing;
};

subtest 'Insert Jobs With Same uniqkey, policy "acknowledge", and get same jobid' => sub {
    foreach my $driver (@drivers) {
        diag 'Testing with ' . $driver;
        my $get_dbh = sub {
            my ($id) = @_;
            my $db = $test_dbs{ $driver }->{ $id };
            return DBI->connect( $db->connection_info );
        };
        my %databases;
        foreach my $id (keys %{ $test_dbs{ $driver } }) {
            $databases{ $id } = {
                dbh_callback => $get_dbh,
                prefix => q{}
            };
        }

        # Start
        my $client = TheSchwartz::JobScheduler->new(
            databases => \%databases,
            opts => {
                handle_uniqkey => 'acknowledge',
                }
            );

        my $job = TheSchwartz::JobScheduler::Job->new(
            funcname => 'Test::uniqkey',
            arg      => { an_item => 'value A' },
            uniqkey  => 'UNIQUE_STR_A',
            );

        my $jobid_1 = $client->insert( $job );
        ok( $jobid_1, 'Got a job id');

        $job->arg( { an_item => 'value B' } );
        my $jobid_2 = $client->insert( $job );
        ok( $jobid_2, 'Got a job id');

        is( $jobid_1, $jobid_2, 'job ids are the same' );

        # Create one more
        $job->arg( { an_item => 'value C' } );
        $job->uniqkey( undef );
        my $jobid_3 = $client->insert( $job );
        ok( $jobid_3, 'Got a job id');
        ok( $jobid_3 > $jobid_2, 'New jobid is greater than previous' );
    }
    done_testing;
};

done_testing;
