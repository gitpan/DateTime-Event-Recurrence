#!/usr/bin/perl -w

use strict;

use Test::More tests => 30;

use DateTime;
use DateTime::Event::Recurrence;

{
# two options, two levels

    my $dt1 = new DateTime( year => 2003, month => 4, day => 28,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $month = monthly DateTime::Event::Recurrence (
        days => [ 31, 15 ],
        minutes => [ 20, 30 ] );

    my $dt;

    $dt = $month->next( $dt1 );
    is ( $dt->datetime, '2003-05-15T00:20:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-05-15T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-05-31T00:20:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-05-31T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-06-15T00:20:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-06-15T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-07-15T00:20:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-07-15T00:30:00', 'next' );

#  TODO: {
#    local $TODO = "binary search breaks overflow checks";
    # PREVIOUS
    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-07-15T00:20:00', 'previous' );

    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-06-15T00:30:00', 'previous' );
    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-06-15T00:20:00', 'previous' );

    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-05-31T00:30:00', 'previous' );
    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-05-31T00:20:00', 'previous' );

    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-05-15T00:30:00', 'previous' );
#  }

}


{
# two options

    my $dt1 = new DateTime( year => 2003, month => 4, day => 28,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $month = monthly DateTime::Event::Recurrence ( 
        days => [ 31, 15 ],
        minutes => [ 30 ] );

    my $dt;

    $dt = $month->next( $dt1 );
    is ( $dt->datetime, '2003-05-15T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-05-31T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-06-15T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-07-15T00:30:00', 'next' );

#  TODO: {
#    local $TODO = "binary search breaks overflow checks";
    # PREVIOUS
    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-06-15T00:30:00', 'previous' );
    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-05-31T00:30:00', 'previous' );
    $dt = $month->previous( $dt );
    is ( $dt->datetime, '2003-05-15T00:30:00', 'previous' );
#  }

}

{
# only one option

    my $dt1 = new DateTime( year => 2003, month => 4, day => 28,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $month = monthly DateTime::Event::Recurrence (
        days => [ 31 ],
        minutes => [ 30 ] );

    my $dt;

    $dt = $month->next( $dt1 );
    is ( $dt->datetime, '2003-05-31T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-07-31T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-08-31T00:30:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-10-31T00:30:00', 'next' );

}

{
# invalid value

    my $dt1 = new DateTime( year => 2003, month => 4, day => 28,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $month = monthly DateTime::Event::Recurrence (
        days => [ 32 ],
        minutes => [ 30 ] );

    my $dt;

    $dt = $month->next( $dt1 );
    is ( $dt, undef, 'next' );
}

{
# february-30

    my $dt1 = new DateTime( year => 2003, month => 1, day => 30,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $month = monthly DateTime::Event::Recurrence (
        months => [ 2 ],
    );

    my $dt;

    $dt = $month->next( $dt1 );
    is ( $dt->datetime, '2003-02-01T00:00:00', 'next' );

}

{
# february-29

    my $dt1 = new DateTime( year => 2003, month => 1, day => 20,
                           hour => 12, minute => 10, second => 45,
                           nanosecond => 123456,
                           time_zone => 'UTC' );

    my $month = monthly DateTime::Event::Recurrence (
        days => [ 29 ],
    );

    my $dt;

    $dt = $month->next( $dt1 );
    is ( $dt->datetime, '2003-01-29T00:00:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-03-29T00:00:00', 'next' );
    $dt = $month->next( $dt );
    is ( $dt->datetime, '2003-04-29T00:00:00', 'next' );

}
