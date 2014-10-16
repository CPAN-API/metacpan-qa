#!/usr/bin/env perl

use strict;
use warnings;
use feature qw( say );

use Data::Printer;
use Every qw( every );
use List::Compare;
use Search::Elasticsearch;

my @new  = get_archives( 'api.bm-mc-02.metacpan.org' );
my @prod = get_archives( 'api.metacpan.org' );

my $lc = List::Compare->new( \@prod, \@new );
my @missing = $lc->get_unique;

say $_ for @missing;

sub get_archives {
    my $domain = shift;

    my $scroller = es( $domain )->scroll_helper(
        search_type => 'scan',
        scroll      => '5m',
        index       => 'v0',
        type        => 'release',
        size        => 1000,
        body        => {
            query  => { match_all => {} },
            fields => ['download_url'],
        }
    );

    my @urls;
    while ( my $result = $scroller->next ) {
        push @urls, $result->{fields}->{download_url};
        say scalar @urls . ' urls' if $ENV{DEBUG} && every( 2500 );
    }

    return @urls;
}

sub es {
    return Search::Elasticsearch->new(
        cxn_pool => 'Static::NoPing',
        nodes    => shift,
    );
}
