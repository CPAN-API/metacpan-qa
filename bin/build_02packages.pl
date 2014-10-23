#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;

use Search::Elasticsearch;

print build( 'api.metacpan.org' );

sub build {
    my $host = shift;

    my $scroller = scroller($host, module =>
        filter => {
            and => [
                { term   => { status => 'latest' } },
                { exists => { field  => 'file.module.name' } },
            ],
        },
        fields => [qw( module release author )],
    );

    my $urls = urls($host);

    my @lines;
    while ( my $result = $scroller->next ) {
        foreach my $mod ( @{ $result->{fields}->{module} } ){
            next unless $mod->{indexed} && $mod->{authorized};

            push @lines, pkg_line($mod, $urls->{ url_key($result) });
        }
    }

    return join '',
        header(scalar @lines),
        # Sort the way PAUSE does.
        sort {lc $a cmp lc $b}
            @lines;
}

sub url_key {
    my $fields = $_[0]->{fields};
    join '/',
        $fields->{author},
        $fields->{release} || $fields->{name};
}

sub urls {
    my $host = shift;

    my $scroller = scroller($host, release =>
        filter => {
            term => { status => 'latest' }
        },
        fields => [qw( author name download_url )],
    );

    my %urls;
    while ( my $result = $scroller->next ) {
        ($urls{ url_key($result) }) =
            $result->{fields}{download_url} =~ m!([A-Z]/[A-Z]{2}/[A-Z]+/.+)!;
    }

    return \%urls;
}

sub es {
    return Search::Elasticsearch->new(
        cxn_pool => 'Static::NoPing',
        nodes    => shift,
    );
}

sub scroller {
    my ($host, $type, %args) = @_;
    es( $host )->scroll_helper(
        search_type => 'scan',
        scroll      => '5m',
        index       => 'v0',
        size        => 1000,
        type        => $type,
        body => {
            query => {
                filtered => {
                    query => { match_all => {} },
                    filter => delete $args{filter},
                }
            },
            fields => delete $args{fields},
        },
        %args
    );
}

sub header {
    my %vars = (
        lines => shift,
        url   => 'http://cpan.metacpan.org/',
        time  => scalar gmtime,
    );

my $header = <<'HEAD';
File:         02packages.details.txt
URL:          {{ url }}modules/02packages.details.txt.gz
Description:  Package names found in directory $CPAN/authors/id/
Columns:      package name, version, path
Intended-For: Automated fetch routines, namespace documentation.
Written-By:   metacpan-qa
Line-Count:   {{ lines }}
Last-Updated: {{ time }} GMT

HEAD

    return $header =~ s/\{\{\s*(.+?)\s*\}\}/$vars{$1}/gr;
}

sub pkg_line {
    my ($mod, $path) = @_;

    my @row = (
        $mod->{name},
        # Seems like this should be // but we have 0's in the data.
        $mod->{version} || 'undef',
        $path || '',
    );

    my ($one, $two) = (30, 8);

    # From PAUSE/mldistwatch.pm (rewrite02() ~ 622).
    if (length($row[0])>$one) {
        $one += 8 - length($row[1]);
        $two = length($row[1]);
    }

    sprintf "%-${one}s %${two}s  %s\n", @row;
}

sub path {
    my ($author, $release) = @{ $_[0] }{qw( author release )};
    join '/',
        (map { substr($author, 0, $_) } (1, 2)),
        $author,
        $release;
}
