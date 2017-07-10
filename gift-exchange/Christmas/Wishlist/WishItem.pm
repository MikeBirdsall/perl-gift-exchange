#!/usr/local/bin/perl -w
#
# Module to manage user wishlist item objects.
# WishItems can be (have the methods):
# new       -> get or create the wishlist for a particular person
# buy       -> mark some items as bought
# by        -> Return the user who created the item
# for       -> return the person the item is intended for
# requested -> set and/or return the number of this item requested
# description -> set and/or return the description of the item

#
# Attributes to add to the object:
# _last_update
# _purchasers
package Christmas::Wishlist::WishItem;

use Christmas::Wishlist::Purchase;
use Time::Local;
use strict;

my %valid_param =
  map { $_ => 1 } qw(for by description ident requested bought expires when);

#_____________________________________________________________________________
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my $self = bless {}, $class;
    return $self->_init(@_);
}

sub _init
{
    my ( $self, %arg ) = @_;

    # Check for "extra" parameters

    foreach my $param ( keys %arg ) {
        return unless defined $valid_param{$param};
    }

    %$self = (
        _for     => $arg{for} || return,
        _creator => $arg{by}  || return,
        _created     => $arg{when},
        _description => $arg{description} || "No Description",
        _ident       => $arg{ident} || "",
        _requested   => $arg{requested} || "any",
        _deleted     => 0,

        #        _notes   => [],
        _expires => $arg{expires} || "never",
        _purchases => [],

        #        _obsolete  => 0,
    );

    return $self;

}

#_____________________________________________________________________________
# Check for differences

sub diff
{
    my ( $self1, $self2 ) = @_;

    return "by: $self1->by ne $self2->by" unless ( $self1->by eq $self2->by );
    return "for: $self1->for ne $self2->for"
      unless ( $self1->for eq $self2->for );

    # created may not be defined, so check that either both undefined or same
    return "created:"
      unless ( ( !defined $self1->created && !defined $self2->created )
        or ( $self1->created() eq $self2->created() ) );
    return "requested:"   unless ( $self1->requested   eq $self2->requested );
    return "description:" unless ( $self1->description eq $self2->description );
    return "bought:"      unless ( $self1->bought      eq $self2->bought );
    return "deleted:"     unless ( $self1->deleted     eq $self2->deleted );

    return "number of purchases:"
      unless (
        scalar @{ $self1->{_purchases} } == scalar @{ $self2->{_purchases} } );

    foreach my $purchase ( 0 .. scalar @{ $self1->{_purchases} } - 1 ) {
        return join ( ":",
            "purchase $purchase",
            $self1->{_purchases}[$purchase]
              ->diff( $self2->{_purchases}[$purchase] ) )
          if ( $self1->{_purchases}[$purchase]
            ->diff( $self2->{_purchases}[$purchase] ) );
    }

    return "expiration date:"
      unless ( $self1->expiration_date eq $self2->expiration_date );
    return "obsolete:" unless ( $self1->obsolete eq $self2->obsolete );
    return "ident:"    unless ( $self1->ident    eq $self2->ident );

    return;
}

#_____________________________________________________________________________
# Check for equality

sub eq
{
    my ( $self1, $self2 ) = @_;

    return unless ( $self1->by  eq $self2->by );
    return unless ( $self1->for eq $self2->for );

    # created may not be defined, so check that either both undefined or same
    return
      unless ( ( !defined $self1->created && !defined $self2->created )
        or ( $self1->created() eq $self2->created() ) );
    return unless ( $self1->requested   eq $self2->requested );
    return unless ( $self1->description eq $self2->description );
    return unless ( $self1->bought      eq $self2->bought );
    return unless ( $self1->deleted     eq $self2->deleted );

    return
      unless (
        scalar @{ $self1->{_purchases} } == scalar @{ $self2->{_purchases} } );

    foreach my $purchase ( 0 .. scalar @{ $self1->{_purchases} } - 1 ) {
        return
          unless ( $self1->{_purchases}[$purchase]
            ->eq( $self2->{_purchases}[$purchase] ) );
    }

    return unless ( $self1->expiration_date eq $self2->expiration_date );
    return unless ( $self1->obsolete        eq $self2->obsolete );
    return unless ( $self1->ident           eq $self2->ident );

    return 1;
}

sub by
{
    my ( $self, $creator ) = @_;
    $self->{_creator} = $creator if defined $creator;
    return $self->{_creator};
}

sub for
{
    my ( $self, $for ) = @_;
    $self->{_for} = $for if defined $for;
    return $self->{_for};
}

sub created
{
    my ( $self, $created ) = @_;
    $self->{_created} = $created if defined $created;
    return $self->{_created};
}

sub requested
{
    my ( $self, $requested ) = @_;
    $self->{_requested} = $requested if defined $requested;
    return $self->{_requested};
}

sub description
{
    my ( $self, $description ) = @_;
    $self->{_description} = $description if defined $description;
    return $self->{_description};
}

#_____________________________________________________________________________
#
# date_from_time returns the month, day, year for the passed in integer seconds
# from start of epoch
#
sub _date_from_time
{
    my ($epochsec) = @_;
    my ( $dd, $mmm, $yyyy ) = ( localtime($epochsec) )[ 3, 4, 5 ];
    $yyyy += 1900;
    $mmm = (
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    )[$mmm];
    return "$mmm $dd $yyyy";
}

#
# time_from_date returns the integer seconds from start of epoch
# for the passed in month, day, year
#
sub _time_from_date
{
    my ($date) = @_;
    my ( $mmm, $dd, $yyyy ) = split " ", $date;
    my %month_vals = (
        Jan => 0,
        Feb => 1,
        Mar => 2,
        Apr => 3,
        May => 4,
        Jun => 5,
        Jul => 6,
        Aug => 7,
        Sep => 8,
        Oct => 9,
        Nov => 10,
        Dec => 11,
    );
    my $month_val = $month_vals{$mmm};
    return timelocal( 0, 0, 0, $dd, $month_val, $yyyy - 1900 );
}

#_____________________________________________________________________________
sub expiration_seconds
{
    my ( $self, $expires ) = @_;
    my %month = map { $_ => 1 } (
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    );

    if ( defined $expires ) {
        $self->{_expires} = _date_from_time($expires);
    }
    return unless ( defined $self->{_expires} );
    return if ( $self->{_expires} eq "never" );
    return unless ( $self->{_expires} =~ /(\w{3}) \d{1,2} \d{4}/ );
    return unless exists $month{$1};
    return _time_from_date( $self->{_expires} );

}

sub expiration_date
{
    my ( $self, $expires ) = @_;
    $self->{_expires} = $expires if defined $expires;
    return $self->{_expires};
}

sub ident
{
    my ( $self, $ident ) = @_;
    $self->{_ident} = $ident if defined $ident;
    return $self->{_ident};
}

sub wanted
{
    return if ( scalar @_ > 1 );
    my ($self) = shift;
    return "any" if ( $self->requested eq "any" );
    return "error" if ( $self->requested !~ /^\d+$/ );

    return $self->requested - $self->bought;
}

sub reserve
{
    my ( $self, $num, $buyer, $descrip, $when ) = @_;

    return unless ( $self->ok_to_buy($num) );

    my $new_purchase = Christmas::Wishlist::Purchase->new(
        num   => $num,
        note  => $descrip,
        buyer => $buyer,
        when  => $when,
    );

    return unless defined $new_purchase;

    push ( @{ $self->{_purchases} }, $new_purchase );

    return $num;

}

sub ok_to_buy
{
    my ( $self, $num ) = @_;

    ( $self->requested =~ /^any$/ ) and return 1;
    ( $self->wanted >= $num ) and return 1;
    return;
}

sub purchased_by
{
    my ( $self, $caller ) = @_;

    foreach my $purchase ( @{ $self->{_purchases} } ) {
        return 1 if $purchase->buyer eq $caller;
    }
    return;
}

sub user_units_purchased
{
    my ( $self, $caller ) = @_;
    my $total = 0;

    foreach my $purchase ( @{ $self->{_purchases} } ) {
        $total += $purchase->num if $purchase->buyer eq $caller;
    }
    return $total;
}

sub user_purchases
{
    my ( $self, $caller ) = @_;

    my @purchases = grep { $_->buyer eq $caller } @{ $self->{_purchases} };

    return @purchases;

}

sub purchases
{
    my ($self) = @_;
    return @{ $self->{_purchases} };
}

sub notes
{
    my ($self) = @_;

    my @notearray;

    foreach my $purchase ( @{ $self->{_purchases} } ) {
        push ( @notearray, $purchase->note ) if defined $purchase->note;
    }
    return @notearray;
}

sub obsolete
{
    my ($self) = @_;
    return 0 if ( $self->expiration_date() eq "never" );
    my $secs = $self->expiration_seconds();
    return unless defined $secs;
    return ( $self->expiration_seconds() < time() );
}

sub deleted
{
    my ( $self, $delete ) = @_;
    if ( defined $delete ) {
        $self->{_deleted} = $delete;
        $self->requested(0);
    }
    return $self->{_deleted};
}

sub bought
{
    my ($self) = @_;

    my $bought = 0;
    foreach my $purchase ( @{ $self->{_purchases} } ) {
        $bought += $purchase->num;
    }
    return $bought;
}

sub delete_nth_purchase_by_user
{
    my ( $self, $which, $user ) = @_;

    # Deletes the $which purchase by $user
    for ( my $i = 0 ; $i < @{ $self->{_purchases} } ; $i++ ) {

        # Increment the number by this user if it matches
        --$which if ( @{ $self->{_purchases} }[$i]->buyer eq $user );

        # If we got to the right one, delete it, returning the note
        if ( !$which ) {

            # Delete it using splice
            my $purchase = splice( @{ $self->{_purchases} }, $i, 1 );
            return $purchase->note;
        }
    }

}

sub delete_purchase
{
    my ( $self, $purchase ) = @_;

    for ( my $pnum = 0 ; $pnum <= $#{ $self->{_purchases} } ; $pnum++ ) {
        if ( @{ $self->{_purchases} }[$pnum] == $purchase ) {
            return splice @{ $self->{_purchases} }, $pnum, 1;
        }
    }
    return;
}

sub max { my ( $a, $b ) = @_; return ( $a > $b ) ? $a : $b; }

sub days_since_purchased
{
    my ($self) = @_;

    # Returns days elapsed since the last purchase of this item
    my $last_purchase = 0;
    for my $purchase ( @{ $self->{_purchases} } ) {
        $last_purchase =
          max( $last_purchase, _time_from_date( $purchase->created ) );
    }
    return unless $last_purchase > 0;
    return ( time - $last_purchase ) / ( 24 * 60 * 60 );
}

sub release_purchase
{
    my ( $self, $num, $buyer, $descrip ) = @_;

    foreach my $purchase ( $self->user_purchases($buyer) ) {
        last unless ($num);
        # Bug fix to deal with undefined purchase notes 20050210
        next unless ( 
            (!defined $purchase->note and !defined $descrip) or 
            ( defined $purchase->note and  defined $descrip and $purchase->note eq $descrip )
        );

        if ( $purchase->num > $num ) {
            $purchase->num( $purchase->num - $num );
            return 1;
        } elsif ( $purchase->num <= $num ) {
            $num -= $purchase->num;
            $self->delete_purchase($purchase);
        }
    }
    return ( $num == 0 );
}

1;

#_____________________________________________________________________________

__END__

=head1 NAME

WishItem.pm - module to manage a WishItem

=head1 VERSION

This document refers to version 0.80 of WishItem.pm, released Jan 1, 2003.

=head1 SYNOPSIS

    include Christmas::Wishlist::WishItem;

    $wi = Christmas::Wishlist::WishItem->new( 
            for=><recipient>, 
            by=><creator>, 
            created=><creation-date>,
            [description=><descript>]
            [ident=><identifier>]
            [requested=><number>]
            [bought=><number>]
            [expires=><date>]
    );

    $by   = $wi->by([<newcreator>];
    $for  = $wi->for([<newrecipient>]);
    $cre  = $wi->created([<creation-date>]);
    $req  = $wi->requested([<newnumber>]);
    $dsc  = $wi->description([<newdescription>]);
    $exp  = $wi->expiration_date([<date>|never]);
    $exp  = $wi->expiration_seconds([<epochseconds>]);
    $id   = $wi->ident([<newidentifier]);
    $bool = $wi->deleted([<booldelete>]);

    $wtd  = $wi->wanted();
    $bool = $wi->purchased_by(<buyertocheck>);
    $int  = $wi->user_units_purchased(<user>);
    @prch = $wi->user_purchases(<user>);
    @note = $wi->notes();
    $bool = $wi->obsolete();
    $num  = $wi->bought();
    $bool = $wi->eq($wi2);

=head2 Deprecated

    $buy  = $wi->buy(<howman>, [<note>,] <buyer>);


=head1 DESCRIPTION

=head2 Overview

=head2 Constructor and initialization

=head2 Class and object methods

=head2 Any other information that's important

=head1 ENVIRONMENT

=head1 DIAGNOSTICS

=over 4

=item "error message that may appear"

Explanation of error message

=back

=head1 ENHANCEMENTS

Make Notes specific to the Noter.

Make a Purchase an Included object. (Create a new Object Type.)

=head1 REFACTORINGS

=head1 BUGS

=head1 FILES

=head1 SEE ALSO

=head1 AUTHOR

Michael G. Birdsall

=head1 COPYRIGHT

Copyright (c) 2002, Michael G. Birdsall. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

