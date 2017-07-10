#!/usr/local/bin/perl -w
#
# Module to manage user wishlist purchase objects.
package Christmas::Wishlist::Purchase;

use strict;

my %valid_param = map { $_ => 1 } qw(num note buyer when);
my %req_param   = map { $_ => 1 } qw(num buyer);

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

    foreach my $param ( keys %req_param ) {
        return unless defined $arg{$param};
    }

    %$self = (
        _num   => $arg{num},
        _note  => $arg{note},
        _buyer => $arg{buyer},
        _when  => $arg{when},
    );

    return $self;
}

#_____________________________________________________________________________

sub diff
{
    my ( $self1, $self2 ) = @_;

    return join ( " ", "Number:", $self1->num, $self2->num )
      unless ( $self1->num eq $self2->num );
    return join ( " ", "Buyer:", $self1->buyer, $self2->buyer )
      unless ( $self1->buyer eq $self2->buyer );
    return join ( " ", "Note:", $self1->note, $self2->note )
      unless ( ( !defined $self1->note and !defined $self2->note )
        or ( $self1->note eq $self2->note ) );
    return join ( " ", "When:", $self1->when, $self2->when )
      unless ( ( !defined $self1->when and !defined $self2->when )
        or ( $self1->when eq $self2->when ) );
    return;
}

sub eq
{
    my ( $self1, $self2 ) = @_;

    return unless ( $self1->num   eq $self2->num );
    return unless ( $self1->buyer eq $self2->buyer );
    return
      unless ( ( !defined $self1->note and !defined $self2->note )
        or ( $self1->note eq $self2->note ) );
    return
      unless ( ( !defined $self1->when and !defined $self2->when )
        or ( $self1->when eq $self2->when ) );
    return 1;
}

sub buyer
{
    my ($self) = @_;
    return $self->{_buyer};
}

sub created
{
    my ( $self, $created ) = @_;
    $self->{_when} = $created if defined $created;
    return $self->{_when};
}

sub note
{
    my ( $self, $note ) = @_;
    $self->{_note} = $note if defined $note;
    return $self->{_note};
}

sub num
{
    my ( $self, $num ) = @_;
    $self->{_num} = $num if defined $num;
    return $self->{_num};
}

sub when
{
    my ( $self, $when ) = @_;
    $self->{_when} = $when if defined $when;
    return $self->{_when};
}

sub expiration_date
{
    my ( $self, $expires ) = @_;
    $self->{_expires} = $expires if defined $expires;
    return $self->{_expires};
}

1;

#_____________________________________________________________________________

__END__

=head1 NAME

Purchase.pm - module to manage a Purchase

=head1 VERSION

This document refers to version ?.?? of Purchase.pm, released ?.

=head1 SYNOPSIS

    include Christmas::Wishlist::Purchase;

    $wi = Christmas::Wishlist::WishItem->new( 
            num=><number>, 
            buyer=><buyer>, 
            [note=><descript>]
            [when=><date>]
    );

    $by   = $pu->note([<newnote>];
    $cre  = $pu->num([<number-bought>]);
    $req  = $pu->when([<date-reserved>]);

    $wtd  = $pu->buyer();
    $bool = $pu->eq($pu2);


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


=head1 REFACTORINGS

=head1 BUGS

=head1 FILES

=head1 SEE ALSO

=head1 AUTHOR

Michael G. Birdsall

=head1 COPYRIGHT

Copyright (c) 2003, Michael G. Birdsall. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

