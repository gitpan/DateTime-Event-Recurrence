#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

use DateTime;
use DateTime::Event::Recurrence;

{
    my $dt1 = new DateTime( year => 2003, month => 4, day => 28,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $dt2 = new DateTime( year => 2003, month => 5, day => 01,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );


    # DAILY
    my $daily = daily DateTime::Event::Recurrence;
    my @dt = $daily->as_list( start => $dt1, end => $dt2 );
    my $r = join(' ', map { $_->datetime } @dt);
    is( $r, 
        '2003-04-29T00:00:00 2003-04-30T00:00:00 2003-05-01T00:00:00',
        "daily" );

    # WEEKLY
    $dt1->subtract( days => 15 );
    my $weekly = weekly DateTime::Event::Recurrence;
    @dt = $weekly->as_list( start => $dt1, end => $dt2 );
    $r = join(' ', map { $_->datetime } @dt);
    is( $r, 
        '2003-04-14T00:00:00 2003-04-21T00:00:00 2003-04-28T00:00:00',
        "weekly" );
}

