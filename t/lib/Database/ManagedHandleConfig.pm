package Database::ManagedHandleConfig;
use strict;
use warnings;

use Moo;
# use File::Temp qw( tempfile );
use Carp qw( croak );

use Test2::Require::Module 'Test::Database::Temp';

has test_dbs => (
    is => 'lazy',
    isa => sub { croak if( ref $_[0] ne 'ARRAY' ); },
    default => \&_build_test_dbs,
);

sub _build_test_dbs {
    my ($self, $args) = @_;
    # diag 'Create temp databases';
    use Test::Database::Temp;
    my @drivers = qw( Pg SQLite );
    my @test_dbs;
    foreach (@drivers) {
        my $test_db = Test::Database::Temp->new(
            driver => $_,
        );
        # diag 'Test database (' . $test_db->driver . ') ' . $test_db->name . " created.\n";
        push @test_dbs, $test_db;
    }
    return \@test_dbs;
}

# has config => (
#     is => 'lazy',
#     default => sub {
#         my ($self) = @_;
#         my @test_dbs = @{ $self->test_dbs() };
#         my %cfg = (
#             'default' => $test_dbs[0]->name(),
#         );
#         foreach (@test_dbs) {
#             my $name = $_->name();
#             my @info = $_->connection_info();
#             my %c;
#             @c{'dsn','username','password','attr'} = @info;
#             $cfg{'databases'}->{$name} = \%c;
#         }
#         return \%cfg;
#     },
# );

sub config {
    my ($self) = @_;
    my @test_dbs = @{ $self->test_dbs() };
    my %cfg = (
        'default' => $test_dbs[0]->name(),
    );
    foreach (@test_dbs) {
        my $name = $_->name();
        my @info = $_->connection_info();
        my %c;
        @c{'dsn','username','password','attr'} = @info;
        $cfg{'databases'}->{$name} = \%c;
    }
    return \%cfg;
}

1;
