package Kurado::ConfigLoader;

use strict;
use warnings;
use utf8;
use YAML::XS qw//;
use File::Spec;
use Kurado::Config;

sub yaml_head {
    my $ref = shift;
    my $dump = YAML::XS::Dump($ref);
    chomp($dump);
    my @dump = split /\n/, $dump;
    join("\n", map { "> $_"} splice(@dump,0,8), (@dump > 8 ? "..." : ""))."\n";
}

sub new {
    my ($class,$path) = @_;
    my $self = bless {
        path => $path,
    }, $class;
    $self->parse_file();
    $self;
}

sub parse_file {
    my ($self) = @_;
    my $path = $self->{path};
    my @configs = eval {
        YAML::XS::LoadFile($path);
    };
    die "Failed to load $path: $@" if $@;
    
    for ( @configs ) {
        if ( ! ref $_ || ref $_ ne "HASH" ) {
            die "config shuold be HASH(or dictionary):\n" . yaml_head($_); 
        }
    }

    my $main_config = shift @configs;
    $self->parse_main_config($main_config);

    $self->{services} = {};
    for my $service_config ( @configs ) {
        $self->parse_service_config($service_config);
    }
}

sub parse_main_config {
    my ($self, $config) = @_;

    my $main_config = $config->{config};
    die "There is no 'config' in:\n".yaml_head($config) unless $main_config;
    eval {
        $self->{config} = Kurado::Config->load($main_config, $self->{path});
    };
    die "failed to config: $@\n===\n".yaml_head($config) if $@;

    $self->{metrics_config} = $config->{metrics_config};
    $self->{metrics_config} ||= {};
    die "metrics_config should be HASH(or dictionary)\n".yaml_head($self->{metrics_config})
        if ! ref $self->{metrics_config} || ! ref $self->{metrics_config} eq 'HASH';
}

sub parse_service_config {
    my ($self,$config) = @_;
    my $service = $config->{service};
    die "There is no 'service' in:\n".yaml_head($config) unless $service;
    die "found duplicated service '$service'".yaml_head($config) if exists $self->{services}->{$service};
    my $servers_config = $config->{servers};
    $servers_config ||= [];
    die "metrics_config should be Array\n".yaml_head($servers_config)
        if ! ref $servers_config || ! ref $servers_config eq 'ARRAY';
    my @sections;
    my %labels;
    for my $server_config ( @$servers_config ) {
        my $roll = $server_config->{roll}
            or die "cannot find roll in service:$service servers:".yaml_head($server_config);
        my $hosts = $server_config->{hosts} || [];
        my $label = $server_config->{label} // '';

        # lebel の2重チェック
        if ( $label ) {
            die "found duplicated label '$label'".yaml_head($config) if exists $labels{$label};
        }

        my @hosts;
        for my $host_line ( @$hosts ) {
            my $host = $self->parse_host( $host_line, $roll );
            push @hosts, $host;
        }
        
        if ( @sections && !$label ) {
            push @{$sections[-1]->{hosts}}, @hosts;
            next;
        }

        push @sections, {
            label => $label,
            hosts => \@hosts,
        };
        $labels{$label} = 1;
    }

    $self->{services}->{$service} = \@sections;
}

sub parse_host {
    my ($self, $line, $roll_name) = @_;

    my ( $address, $hostname, $comments )  = split /\s+/, $line, 3;
    die "cannot find address in host '$line'\n" unless $address;
    $hostname //= $address;
    $comments //= "";

    my $roll = $self->load_roll( $roll_name );

    return {
        address => $address,
        hostname => $hostname,
        comments => $comments,
        roll => $roll_name,
        metrics_config => $roll->{metrics_config},
        metrics => $roll->{metrics},
    };
}

my %ROLL_CACHE;
sub load_roll {
    my ($self, $roll_name) = @_;
    # cache
    return $ROLL_CACHE{$roll_name} if $ROLL_CACHE{$roll_name};
    my $path = File::Spec->catfile($self->config->rolls_dir, $roll_name);
    my ($roll_config) = eval {
        YAML::XS::LoadFile($path);
    };
    die "Failed to load roll $path: $@" if $@;
    if ( ! ref $roll_config || ref $roll_config ne "HASH" ) {
        die "roll config shuold be HASH(or dictionary):\n" . yaml_head($roll_config); 
    }
    my $metrics_config = $self->merge_metrics_config($roll_config->{metrics_config} || {});
    my @metrics;
    for ( @{$roll_config->{metrics} || []} ) {
        push @metrics, $self->parse_metrics($_);
    }    
    
    my $roll = {
        metrics_config => $metrics_config,
        metrics => \@metrics
    };    
    $ROLL_CACHE{$roll_name} = $roll;
    return $roll;
}

sub parse_metrics {
    my ($self, $line) = @_;
    my ( $metrics, @arguments )  = split /:/, $line;
    die "cannot find merics name: in '$line'\n" unless $metrics;
    return {
        metrics => $metrics,
        arguments => \@arguments,
    };
}

sub config {
    $_[0]->{config};
}

sub metrics_config {
    $_[0]->{metrics_config};
}

sub merge_metrics_config {
    my ($self,$ref) = @_;
    +{
        %{$self->{metrics_config}},
        %$ref
    };
}

sub services {
    $_[0]->{services};
}

sub dump {
    my $self = shift;
    +{
        config => $self->config->dump,
        metrics_config => $self->metrics_config,
        services => $self->services
    }
}

1;
