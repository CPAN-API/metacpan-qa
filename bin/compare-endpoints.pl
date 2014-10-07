#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use CLDR::Number::Format::Decimal;
use Cpanel::JSON::XS qw( decode_json );
use Mojo::UserAgent;
use Text::Table::Tiny;

my $decf = CLDR::Number::Format::Decimal->new( locale => 'en' );

my $ua = Mojo::UserAgent->new;

my @hosts = ( 'api', 'api.bm-mc-02' );
my @types = (
    'author', 'distribution', 'favorite', 'file',
    'mirror', 'rating',       'release',
);
my @rows = ( [ 'host', 'type', 'results' ] );

foreach my $type ( @types ) {
    foreach my $host ( @hosts ) {
        my $uri = sprintf( 'http://%s.metacpan.org/%s?size=0', $host, $type );
        my $body    = $ua->get( $uri )->res->body;
        my $results = decode_json( $body );
        push @rows,
            [ $host, $type, $decf->format( $results->{hits}->{total} || 0 ) ];
    }
}

print Text::Table::Tiny::table(
    header_row    => 1,
    rows          => \@rows,
    separate_rows => 1,
);
