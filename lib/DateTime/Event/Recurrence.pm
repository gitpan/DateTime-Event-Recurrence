package DateTime::Event::Recurrence;

use strict;
require Exporter;
use Carp;
use DateTime;
use DateTime::Set;
use DateTime::Span;
use Params::Validate qw(:all);
use vars qw( $VERSION @ISA );
@ISA     = qw( Exporter );
$VERSION = '0.01';

# debug!
use Data::Dumper;

# -------- CONSTRUCTORS

BEGIN {
    # setup constructors daily, monthly, ...
    my @freq = qw( 
        year   years   yearly
        month  months  monthly
        day    days    daily
        hour   hours   hourly
        minute minutes minutely
        second seconds secondly );
    while ( @freq ) 
    {
        my ( $name, $names, $namely ) = ( shift @freq, shift @freq, shift @freq );
        my $sub = "
            sub ".__PACKAGE__."::$namely {
                my \$class = shift;
                my ( \$duration, \$min, \$max ) = \&_setup_parameters;  # needs \&
                return DateTime::Set->from_recurrence(
                   next => sub { 
                       my \$tmp = \$_[0]->clone;
                       \$tmp->truncate( to => '$name' );
                       _get_next( \$_[0], \$tmp, '$names', \$duration, \$min, \$max );
                   },
                   previous => sub {
                       my \$tmp = \$_[0]->clone;
                       \$tmp->truncate( to => '$name' );
                       _get_previous( \$_[0], \$tmp, '$names', \$duration, \$min, \$max );
                   } 
                 );
            } ";
        # warn $sub;
        eval $sub;
        warn $@ if $@;
    }
} # BEGIN


sub weekly {
    my $class = shift;
    my ( $duration, $min, $max ) = &_setup_parameters;  # needs &
    return DateTime::Set->from_recurrence(
        next => sub { 
            my $tmp = $_[0]->clone;
            $tmp->truncate( to => 'day' )
                ->subtract( days => $_[0]->day_of_week_0 );
            _get_next( $_[0], $tmp, 'weeks', $duration, $min, $max );
        },
        previous => sub {
            my $tmp = $_[0]->clone;
            $tmp->truncate( to => 'day' )
                 ->subtract( days => $_[0]->day_of_week_0 );
            _get_previous( $_[0], $tmp, 'weeks', $duration, $min, $max );
        }
    );
}


# method( duration => $dur )
# method( duration => [ [ $dur, $dur, $dur ] ] )
# method( hours => 10 )
# method( hours => 10, minutes => 30 )
# method( hours => [ 6, 12, 18 ], minutes => [ 20, 40 ] )
# method( duration => [ [ $dur, $dur ], 
#                       [ $dur, $dur ] ] )

sub _setup_parameters {
    my %args = @_;

    my $duration;  
    if ( exists $args{ duration } ) 
    {
        $duration = delete $args{ duration };
        if ( ref( $duration ) ne 'ARRAY' ) 
        {
            $duration = [ [ $duration ] ];
        }
        else {
            die "argument 'duration' must be an array of arrays"
                if ( ref( @{$duration}[0] ) ne 'ARRAY' ) 
        }
    }
    elsif ( keys %args ) {
        my $level = 0;
        for my $unit ( qw( months weeks days hours minutes seconds nanoseconds ) ) {
            if ( exists $args{$unit} ) {
                $args{$unit} = [ $args{$unit} ] 
                    unless ref( $args{$unit} ) eq 'ARRAY';
                @{$duration}[ $level ] = [];
                push @{@{$duration}[ $level ]}, 
                    new DateTime::Duration( $unit => $_ ) 
                    for sort @{$args{$unit}};
                $level++;
            } 
        }
    }


    my @min;
    my @max;
    if ( $duration ) {
        # pre-process each duration line; get min and max
        # such that we can look up the duration table in linear time
        # (it can be done in log time - maybe later...)
        my $i;
        for ( $i = $#$duration; $i >= 0; $i-- ) {

            # make durations immutable
            $_ = $_->clone for @{@{$duration}[$i]};  
  
            $min[$i] = ${$duration}[$i][0];
            $max[$i] = ${$duration}[$i][-1];
            if ( $i < $#$duration ) {
                $min[$i] += $min[$i + 1];
                $max[$i] += $max[$i + 1];
            }
            # print " i= $i n= $#$duration ". Dumper( @{$duration}[$i] )."\n";
            # print " ".  Dumper( $min[$i] ) ." .. ". Dumper( $max[$i] )."\n";
        }
    }

    return ( $duration, \@min, \@max );
}

sub _get_previous {
    my ( $self, $base, $unit, $duration, $min, $max ) = @_;
    if ( $duration ) 
    {
        $base->subtract( $unit => 1 )
            while ( $base + @$min[0] ) >= $self;

        my $j = 0;
        my $next;
        my $i;
        while(1) {

            for ( $i = $#{@$duration[$j]}; $i >= 0; $i-- ) {
                # my $next = $base->clone;
                # $next->add_duration( ${$duration}[$j][$i] );
                # return $next if $next < $self;


                $next = $base + ${$duration}[$j][$i];
                # print " #$j-$#{$duration} $i self ".$self->datetime." next ". $next->datetime ." \n";
                if ( $j == $#{$duration} ) 
                {
                    if ( $next < $self ) 
                    {
                        # print " #$j $i next ". $next->datetime ." \n";
                        last; # return $next;
                    }
                }
                elsif (( $next + @$min[ $j + 1 ] ) < $self )
                {
                    # print " #$j $i next ". $next->datetime ." \n";
                    last; # return $next;
                }




            }

            $base = $next;

            # print " opt0: ".$base->datetime."  \n";
            if ( $j >= $#{$duration} ) {
                # print "#0\n";
                return $base; 
            }
            $j++;
        }

    }
    else 
    {
        $base->subtract( $unit => 1 ) while $base >= $self;
    }
    return $base;
}



sub _get_next {
    my ( $self, $base, $unit, $duration, $min, $max ) = @_;
    if ( $duration ) 
    {
        $base->add( $unit => 1 )
            while ( $base + @$max[0] ) <= $self;

        # print " self ".$self->datetime." n $#{$duration} \n";

        my $j = 0;
        my $next;
        my $i;
        while(1) {

            for $i ( 0 .. $#{@$duration[$j]} ) {
                $next = $base + ${$duration}[$j][$i];
                # print " #$j-$#{$duration} $i self ".$self->datetime." next ". $next->datetime ." \n";
                if ( $j == $#{$duration} ) 
                {
                    if ( $next > $self ) 
                    {
                        # print " #$j $i next ". $next->datetime ." \n";
                        last; # return $next;
                    }
                }
                elsif (( $next + @$max[ $j + 1 ] ) > $self )
                {
                    # print " #$j $i next ". $next->datetime ." \n";
                    last; # return $next;
                }
            }

            $base = $next;

            # print " opt0: ".$base->datetime."  \n";
            if ( $j >= $#{$duration} ) {
                # print "#0\n";
                return $base; 
            }
            $j++;
        }
    }
    else 
    {
        $base->add( $unit => 1 ) while $base <= $self;
    }
    return $base;
}

=head1 NAME

DateTime::Event::Recurrence - Perl DateTime extension for computing basic recurrences.

=head1 SYNOPSIS

 use DateTime;
 use DateTime::Event::Recurrence;
 
 my $dt = DateTime->new( year   => 2000,
                         month  => 6,
                         day    => 20,
                  );

 my $r_daily = daily DateTime::Event::Recurrence;

 my $dt_next = $daily->next( $dt );

 my $dt_previous = $daily->previous( $dt );

 my $bool = $daily->contains( $dt );

 my $set_days = $r_daily->as_set( start =>$dt1, end=>$dt2 );

 my @days = $r_daily->as_list( start =>$dt1, end=>$dt2 );

 my $set = $r_daily->intersection($dt_span);
 my $iter = $set->iterator;
 while ( my $dt = $iter->next ) {
     print ' ',$dt->datetime;
 }

=head1 DESCRIPTION

This module will return a DateTime Recurrence-set object for a given recurrence rule.

=head1 USAGE

=over 4

=item * yearly monthly weekly daily hourly minutely secondly

  my $r_daily = daily DateTime::Event::Recurrence;

Build a DateTime::Event::Recurrence object.

The constructors might take "duration" arguments:

  my $r_daily_at_evening = daily DateTime::Event::Recurrence( duration => $evening );

  my $r_daily_at_10_30 = daily DateTime::Event::Recurrence( hours => 10, minutes => 30 );

Note: C<weekly> without arguments returns I<mondays>.

  my $r_tuesdays = weekly DateTime::Event::Recurrence( days => 1 );

A negative duration has the meaning as specified in RFC2445:
it counts backwards from the end of the period.

This is useful for creating recurrences such as I<last day of month>:

  my $r_last_day_of_month = monthly DateTime::Event::Recurrence( days => -1 );

The constructors do not check for duration overflow, such as 
a duration bigger than the period. The behaviour in this case is 
undefined and it might change between versions.

Note that the 'hours' duration is affected by DST changes
and might return unexpected results.

The constructors can also accept "multi-level" durations, such as
the ones used by C<crontab> and in C<RFC2445>. 

    my $daily = daily DateTime::Event::Recurrence ( 
        hours => [ -1, 10, 14 ],
        minutes => [ -15, 30, 15 ] );

specifies a recurrence occuring everyday at these 9 different times:

  09:45,  10:15,  10:30,    # 10h ( -15 / +15 / +30 minutes )
  13:45,  14:15,  14:30,    # 14h ( -15 / +15 / +30 minutes )
  22:45,  23:15,  23:30,    # -1h ( -15 / +15 / +30 minutes )

This is a recurrence occuring every 30 seconds:

    my $half_minute = minutely DateTime::Event::Recurrence ( 
        seconds => [ 0, 30 ] );

Multi-level durations can also be specified as an Array-of-Arrays
of duration objects:

  # specify a daily recurrence with hours and minutes
  my $daily = daily DateTime::Event::Recurrence ( 
     duration => [ 
         [  # first level: hours
            new DateTime::Duration( hours => -1 ),  # 23h
            new DateTime::Duration( hours => 10 ),
            new DateTime::Duration( hours => 14 ), 
         ],
         [  # second level: minutes
            new DateTime::Duration( minutes => -15 ),  # 45min
            new DateTime::Duration( minutes => 15 ),
            new DateTime::Duration( minutes => 30 ),
         ], 
     ] 
  );


The durations in an Array-of-Arrays specification I<must> be ordered.

=item * as_list

  my @dt = $r_daily->as_list( $span );

This builds a DateTime array of events that happen inside the span.

=item * previous current next closest

See DateTime::Set.

=item * contains

  my $bool = $r_daily->contains( $dt );

Verify if a DateTime is a recurrence event.

=item * union intersection complement

See DateTime::Set.

=back

=head1 AUTHOR

Flavio Soibelmann Glock
fglock@pucrs.br

=head1 CREDITS

The API is under development, with help from the people
in the datetime@perl.org list. 

Special thanks to Dave Rolsky, 
Ron Hill and Matt Sisk for being around with ideas.

=head1 COPYRIGHT

Copyright (c) 2003 Flavio Soibelmann Glock.  
All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=head1 SEE ALSO

datetime@perl.org mailing list

DateTime Web page at http://datetime.perl.org/

DateTime

DateTime::Set 

DateTime::SpanSet 

=cut
1;

