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
$VERSION = '0.02';

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

        no strict 'refs';
        *{__PACKAGE__ . "::$namely"} =
            sub { use strict 'refs';
                  my $class = shift;

                  # TODO: move these parameters into a hash
                  my ( $duration, $min, $max, $check_day_overflow ) = 
                     _setup_parameters( base => $name, @_ );
                  return DateTime::Set->empty_set if $duration == -1;

                  my $next =
                      sub { my $tmp = $_[0]->clone;
                            $tmp->truncate( to => $name );
                            _get_next( $_[0], $tmp, $names,
                                       $duration, $min, $max, 
                                       $check_day_overflow ); 
                          };

                  my $prev =
                      sub { my $tmp = $_[0]->clone;
                            $tmp->truncate( to => $name );
                            _get_previous( $_[0], $tmp, $names,
                                           $duration, $min, $max, 
                                           $check_day_overflow ); 
                          };

                  return
                      DateTime::Set->from_recurrence
                              ( next     => $next,
                                previous => $prev,
                              );
                };
    }
} # BEGIN


sub weekly {
    my $class = shift;
    # TODO: move these parameters into a hash
    my ( $duration, $min, $max, $check_day_overflow ) = 
        _setup_parameters( base => 'week', @_);
    return DateTime::Set->empty_set if $duration == -1;
    return DateTime::Set->from_recurrence(
        next => sub { 
            my $tmp = $_[0]->clone;
            $tmp->truncate( to => 'day' )
                ->subtract( days => $_[0]->day_of_week_0 );
            _get_next( $_[0], $tmp, 'weeks', $duration, 
                       $min, $max, $check_day_overflow );
        },
        previous => sub {
            my $tmp = $_[0]->clone;
            $tmp->truncate( to => 'day' )
                 ->subtract( days => $_[0]->day_of_week_0 );
            _get_previous( $_[0], $tmp, 'weeks', $duration,
                           $min, $max, $check_day_overflow );
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

    my @check_day_overflow;
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
                if ( ref( $duration->[0] ) ne 'ARRAY' ) 
        }
    }
    elsif ( keys %args ) {
        my $level = 0;
        for my $unit ( 
                 qw( months weeks days hours minutes seconds nanoseconds ) 
            ) {

            next unless exists $args{$unit};

            $args{$unit} = [ $args{$unit} ] 
                unless ref( $args{$unit} ) eq 'ARRAY';

            @{$args{$unit}} = sort { $a <=> $b } @{$args{$unit}};

            $duration->[ $level ] = [];

            # TODO: add overflow checks for other units
            # TODO: use a hash instead of if-else

            if ( $unit eq 'seconds' ) {
                    @{$args{$unit}} =
                        grep { $_ < 60 && $_ > -60 } @{$args{$unit}};
            }
            elsif ( $unit eq 'minutes' ) {
                    @{$args{$unit}} =
                        grep { $_ < 60 && $_ > -60 } @{$args{$unit}};
            }
            elsif ( $unit eq 'hours' ) {
                    @{$args{$unit}} =
                        grep { $_ < 24 && $_ > -24 } @{$args{$unit}};
            }
            elsif ( $unit eq 'days' ) {
                # days start in '1'
                for ( @{$args{$unit}} ) {
                    warn 'days cannot be zero' unless $_;
                    $_-- if $_ > 0;
                }
                if ( $args{base} eq 'month' || exists $args{month} ) 
                {   # month day
                    @{$args{$unit}} = 
                        grep { $_ < 31 && $_ > -31 } @{$args{$unit}};

                    # prepare to do more overflow checks at runtime
                    # TODO: remove [$level] in @check_day_overflow

                    for ( 0 .. $#{$args{$unit}} ) {
                        $check_day_overflow[$level][$_] = 1 
                            if ( $args{$unit}[$_] > 28 );
                    }

                }
                elsif ( $args{base} eq 'week' || exists $args{week} ) 
                {   # week day
                    @{$args{$unit}} = 
                        grep { $_ < 7 && $_ > -7 } @{$args{$unit}};
                }
                else 
                {   # year day
                    @{$args{$unit}} =
                        grep { $_ < 366 && $_ > -366 } @{$args{$unit}};
                }
            }
            elsif ( $unit eq 'months' ) {
                # months start in '1'
                for ( @{$args{$unit}} ) {
                    warn 'months cannot be zero' unless $_;
                    $_-- if $_ > 0;
                }
                @{$args{$unit}} =
                    grep { $_ < 12 && $_ > -12 } @{$args{$unit}};
            }
            elsif ( $unit eq 'weeks' ) {
                # weeks start in '1'
                for ( @{$args{$unit}} ) {
                    warn 'weeks cannot be zero' unless $_;
                    $_-- if $_ > 0;
                }
                @{$args{$unit}} =
                    grep { $_ < 53 && $_ > -53 } @{$args{$unit}};
            }

            return -1 unless @{$args{$unit}};  # error - no args left

            push @{ $duration->[ $level ] }, 
                new DateTime::Duration( $unit => $_ ) 
                    for @{$args{$unit}};

            $level++;
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
            $_ = $_->clone for @{ $duration->[$i] };  
  
            $min[$i] = $duration->[$i][0];
            $max[$i] = $duration->[$i][-1];
            if ( $i < $#$duration ) {
                $min[$i] += $min[$i + 1];
                $max[$i] += $max[$i + 1];
            }
        }
    }

    return ( $duration, \@min, \@max, \@check_day_overflow );
}

sub _get_previous {
    my ( $self, $base, $unit, $duration, $min, $max, $check_day_overflow ) = @_;
    if ( $duration ) 
    {
        $base->subtract( $unit => 1 )
            while ( $base + $min->[0] ) >= $self;
        my $j = 0;
        my $next;
        my $i;
        my $month;
        GET_RECURRENCE: while(1) 
        {
            for ( $i = $#{ $duration->[$j] }; $i >= 0; $i-- ) 
            {
                $next = $base + $duration->[$j][$i];

                if ( $check_day_overflow->[$j][$i] ) {
                    $month = $base->month unless $month;
                    if ( $month != $next->month ) {
                       next if $i > 0;
                       $base->subtract( $unit => 1 );
                       $j = 0;
                       $month = undef;
                       next GET_RECURRENCE;
                    }
                }

                if ( $j == $#{$duration} ) 
                {
                    if ( $next < $self ) 
                    {
                        last; # return $next;
                    }
                }
                elsif (( $next + $min->[ $j + 1 ] ) < $self )
                {
                    last; # return $next;
                }
            }

            $base = $next;
            # print " opt0: ".$base->datetime."  \n";
            if ( $j >= $#{$duration} ) 
            {
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
    my ( $self, $base, $unit, $duration, $min, $max, $check_day_overflow ) = @_;
    if ( $duration ) 
    {
        $base->add( $unit => 1 )
            while ( $base + $max->[0] ) <= $self;
        my $j = 0;
        my $next;
        my $i;
        my $month;
        GET_RECURRENCE: while(1) 
        {
            for $i ( 0 .. $#{ $duration->[$j] } ) 
            {
                $next = $base + $duration->[$j][$i];

                if ( $check_day_overflow->[$j][$i] ) {
                    $month = $base->month unless $month;
                    if ( $month != $next->month ) {
                       $base->add( $unit => 1 );
                       $j = 0;
                       $month = undef;
                       next GET_RECURRENCE;
                    }
                }

                if ( $j == $#{$duration} ) 
                {
                    if ( $next > $self ) 
                    {
                        last; # return $next;
                    }
                }
                elsif (( $next + $max->[ $j + 1 ] ) > $self )
                {
                    last; # return $next;
                }
            }

            $base = $next;
            if ( $j >= $#{$duration} ) 
            {
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

 my $daily_set = daily DateTime::Event::Recurrence;

 my $dt_next = $daily_set->next( $dt );

 my $dt_previous = $daily_set->previous( $dt );

 my $bool = $daily_set->contains( $dt );

 my @days = $daily_set->as_list( start => $dt1, end => $dt2 );

 my $iter = $daily_set->iterator;

 while ( my $dt = $iter->next ) {
     print ' ', $dt->datetime;
 }

=head1 DESCRIPTION

This module provides convenience methods that let you easily create
C<DateTime::Set> objects for common recurrences, such as "monthly" or
"daily".

=head1 USAGE

=over 4

=item * yearly monthly weekly daily hourly minutely secondly

These methods all return a C<DateTime::Set> object representing the
given recurrence.

  my $daily_set = daily DateTime::Event::Recurrence;

If no parameters are given, then the set members occur at the
I<beginning> of each recurrence.  For example, by default the
C<monthly()> method returns a set where each members is the first day
of the month.

Without parameters, the C<weekly()> without arguments returns
I<mondays>.

However, you can pass in parameters to alter where these datetimes
fall.  The parameters are the same as those given to the
C<DateTime::Duration> constructor for specifying the length of a
duration.  For example, to create a set representing a daily
recurrence at 10:30 each day, we can do:

  my $daily_at_10_30_set =
      daily DateTime::Event::Recurrence( hours => 10, minutes => 30 );

To represent every I<Tuesday> (second day of week):

  my $weekly_on_tuesday_set =
      weekly DateTime::Event::Recurrence( days => 2 );

A negative duration counts backwards from the end of the period.  This
is the same as is specified in RFC 2445.

This is useful for creating recurrences such as the I<last day of
month>:

  my $last_day_of_month_set =
      monthly DateTime::Event::Recurrence( days => -1 );

When days are added to a month the result I<is> checked
for month overflow (such as nonexisting day 31 or 30),
and the invalid datetimes are skipped.

The behaviour when other duration overflows occur, such as when a
duration is bigger than the period, is undefined and
is version dependent. 
Invalid parameter values are usually skipped.

Note that the 'hours' duration is affected by DST changes and might
return unexpected results.  In particular, it would be possible to
specify a recurrence that creates nonexistent datetimes.
This behaviour might change in future versions.
Some possible alternatives are to use
floating times, or to use negative hours since 
DST changes usually occur in the beginning of the day.

The value C<60> for seconds (the leap second) is ignored. 
If you i<really> want the leap second, then specify 
the second as C<-1>.

You can also provide multiple sets of duration arguments, such as
this:

    my $set = daily DateTime::Event::Recurrence (
        hours => [ -1, 10, 14 ],
        minutes => [ -15, 30, 15 ] );

specifies a recurrence occuring everyday at these 9 different times:

  09:45,  10:15,  10:30,    # 10h ( -15 / +15 / +30 minutes )
  13:45,  14:15,  14:30,    # 14h ( -15 / +15 / +30 minutes )
  22:45,  23:15,  23:30,    # -1h ( -15 / +15 / +30 minutes )

To create a set of recurrences every thirty seconds, we could do this:

    my $every_30_seconds_set =
        minutely DateTime::Event::Recurrence ( seconds => [ 0, 30 ] );

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

