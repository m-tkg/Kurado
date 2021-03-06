#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Kurado::Plugin;
use Furl;
use IO::Socket qw/inet_aton pack_sockaddr_in/;

our $VERSION = '0.01';

my $plugin = Kurado::Plugin->new(@ARGV);
my $host = $plugin->address;
my ($port,$path,$http_host) = @{$plugin->plugin_arguments};
$port ||= 80;
$path ||= '/server-status?auto';
$http_host ||= $host;

my $furl = Furl->new(
    agent   => 'kurado-plugin',
    timeout => 10,
    get_address => sub {
        pack_sockaddr_in($port, inet_aton($host));
    }
);

my $res = $furl->request(
    scheme => 'http',
    host   => $http_host,
    port   => $port,
    path_query => $path,
);

die "server-status failed: " .$res->status_line."\n"
    unless $res->is_success;

my $time = time;

my %meta;
if ( my $server_version = $res->header('Server') ) {
    $meta{server} = $server_version;
}

my $body = $res->body;
my %metrics;
foreach my $line ( split /[\r\n]+/, $body ) {
    if ( $line =~ /^Busy.+: (\d+)/ ) {
        $metrics{busy} = $1;
    }
    if ( $line =~ /^Idle.+: (\d+)/ ) {
        $metrics{idle} = $1;
    }
    if ( $line =~ /^Uptime\s*: (\d+)/ ) {
        my $uptime = $1;
        $uptime = $time - $uptime if $uptime > 20*365*86400;
        $meta{uptime} = $uptime;
    }
    if ( $line =~ /^Total Accesses\s*: (\d+)/ ) {
        $meta{'has-reqs'} = 1;
        $metrics{reqs} = $1;
    }
}

for my $key (keys %meta) {
    print "meta.$key\t$meta{$key}\t$time\n";
}


for my $key (qw/busy idle/) {
    my $metrics = exists $metrics{$key} ? $metrics{$key} : 'U';
    print "metrics.$key.gauge\t$metrics{$key}\t$time\n";
}

if ( $meta{'has-reqs'} ) {
    print "metrics.reqs.derive\t$metrics{reqs}\t$time\n";
}

