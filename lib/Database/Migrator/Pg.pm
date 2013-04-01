package Database::Migrator::Pg;

use strict;
use warnings;
use namespace::autoclean;

use Database::Migrator::Types qw( Str );
use File::Slurp qw( read_file );
use Pg::CLI::createdb;
use Pg::CLI::psql;

use Moose;

with 'Database::Migrator::Core';

has encoding => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_encoding',
);

has owner => (
    is        => 'ro',
    isa       => Str,
    predicate => '_has_owner',
);

has _psql => (
    is       => 'ro',
    isa      => 'Pg::CLI::psql',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_psql',
);

has _cli_constructor_args => (
    is       => 'ro',
    isa      => HashRef,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_cli_constructor_args',
);

sub _build_database_exists {
    my $self = shift;

    my $stdout = $self->_psql_or_dir(
        'run',
        options => ['-l'],
    );

    return $stdout =~ /^\s+\Q$database\E\s+/;
}

sub _create_database {
    my $self = shift;

    my $database = $self->database();

    $self->logger()->info("Creating the $database database");

    my $createdb = Pg::CLI::createdb->new( $self->_cli_constructor_args() );

    my @opts;
    push @opts, '-E', $self->encoding()
        if $self->_has_encoding();
    push @opts, '-O', $self->owner()
        if $self->_has_owner();

    $createdb->run(
        database => $self->database(),
        options  => \@opts,
    );

    return;
}

sub _run_ddl {
    my $self = shift;
    my $file = shift;

    $self->_psql_or_dir(
        'execute_file',
        database => $self->database(),
        file     => $file,
    );
}

sub _psql_or_die {
    my $self   = shift;
    my $method = shift;
    my %args   = @_;

    my $stdout;
    my $stderr;
    $self->_psql()->$method(
        %args,
        stdout => \$stdout,
        stderr => \$stderr,
    );

    die $stderr if $stderr;

    return $stdout;
}

sub _build_psql {
    my $self = shift;

    return Pg::CLI::psql->new(
        %{ $self->_cli_constructor_args() },
        quiet => 1,
    );
}

sub _build_cli_constructor_args {
    my $self = shift;

    my %args;
    for my $m (qw( username password host port )) {
        $args{$m} = $self->$m()
            if defined $self->$m();
    }

    return \%args;
}

sub _build_dbh {
    my $self = shift;

    return DBI->connect(
        'dbi:Pg:' . $self->database(),
        $self->user(),
        $self->password(),
    );
}

__PACKAGE__->meta()->make_immutable();

1;

#ABSTRACT: Database::Migrator implementation for Postgres

=head1 SYNOPSIS

  package MyApp::Migrator;

  use Moose;

  extends 'Database::Migrator::Pg';

  has '+database' => (
      required => 0,
      default  => 'MyApp',
  );

=head1 DESCRIPTION

This module provides a L<Database::Migrator> implementation for Postgres. See
L<Database::Migrator> and L<Database::Migrator::Core> for more documentation.
