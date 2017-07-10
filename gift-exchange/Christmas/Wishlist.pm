#!/usr/local/bin/perl -w
# $Id: Wishlist.pm,v 1.22 2003/01/31 13:12:03 mbirdsal Exp $
# $Name:  $
#
# Module to manage user wishlist objects.
#
package Christmas::Wishlist;

use Christmas::Wishlist::WishItem;
use Christmas::Wishlist::Purchase;
use Time::Local;
use Data::Dumper;
use Carp;
use strict;

#_____________________________________________________________________________
# Ultimately, a repository will probably need to be an attribute of a wishlist,
# or an object all on its own.
# For now, we use a closure to make it a class attribute.
{
    my $defdir;

    # Common values on a bert or on mbirdsal are:
    # "/users/m/mbirdsal/apache/htdocs/family/data/";
    # "/big/dom/xkirkbird/www/mbirdsall/family/data/";

    sub set_repository
    {
        shift;
        $defdir = shift;
        return $defdir;
    }

    sub _get_repository
    {
        return $defdir;
    }
}

#_____________________________________________________________________________
# Create a wishlist object
#
# Attributes to add to the object: Last Updated
sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my $self = bless {}, $class;
    return $self->_init(@_);
}

#_____________________________________________________________________________
# Set the initial data
#
# Arguments: a hash contain the following keyed items:
#      userid => login id of the user whose wishlist is being initialized (req)
#      path   => a repository path for the wishlist (optional); defaults to the
#                directory set with set_repository
#      create => determines special create checks if defined (boolean)
#                false -> fail if the wishlist isn't already in existence
#                         (refuse to create a new wishlist)
#                true  -> fail if the wishlist is already in existence
#                         (refuse to use an existing wishlist
#      instance => an additional part of identifying this object, so that there
#                  can be two objects with the same userid and path, but in
#                  different files. This is used while copying and updating a
#                  particular wishlist.
#
sub _init
{
    my ( $self, %arg ) = @_;

    %$self = (
        _userid => $arg{userid} || croak("missing userid"),
        _path   => $arg{path}   || $self->_get_repository,
        _item   => [],
        _instance    => $arg{instance},
        _last_update => "unknown",
    );

    # form filename
    my $fname = $self->_filename();

    # If wishlist already exists
    if ( -f $fname && -s _ ) {
        return if ( defined $arg{create} and $arg{create} );

        # Read the file and initialize the object from the data
        $self->_read($fname);

        open( NEWTRANS, ">>$fname" );
    } else {
        return if ( defined $arg{create} and !$arg{create} );

        # Create the file
        open( NEWTRANS, ">" . $fname );
        $self->_write_header();

        #If this is a truly new file, this is the time of last update
        $self->{_last_update} = localtime;
    }

    return $self;
}

#_____________________________________________________________________________
#
# _numeric_time
#    returns the local (seconds from start of epoch) time for a time string
#    formatted like the return from scalar localtime
#
sub _numeric_time
{
    my ($time) = @_;

    my (%numericmonth) = (
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
        Dec => 11
    );

    my ( $mmm, $dd, $hh, $min, $sec, $yyyy ) =
      ( $time =~ /\w*\s+(\w{3})\s+(\d*)\s+(\d+):(\d+):(\d+)\s+(\d+)/ );

    # Code for timelocal inability to return 0
    return 0 if ($yyyy < 1970);
    return timelocal( $sec, $min, $hh, $dd, $numericmonth{$mmm}, $yyyy - 1900 );
}

#
# _date_parts
#    Breaks o date of the form:
#        Sat Jan 11 17:00:55 2003
#    out to get just the date information, e.g. qw(Jan 11 2003)
sub _date_parts
{
    my ($dstring) = @_;

    return ( $dstring =~ /\w*\s+(\w{3})\s+(\d*)\s+\d+:\d+:\d+\s+(\d+)/ );
}

#
# _noonify
#    Changes a date of the form:
#        Jan 11 2003
#    into a full date-time of noon on that date, e.g. Sat Jan 11 12:00:00 2003
sub _noonify
{
    my ($dstring) = @_;
    my ( $mmm, $dd, $yyyy ) = split " ", $dstring;

    return localtime( _numeric_time("XXX $mmm $dd 12:00:00 $yyyy") );
}

#_____________________________________________________________________________
#
# _read - reads the wishlist file whose name is passed and update the wishlist
#         items based on the log in that file

sub _read
{
    my ( $self, $fname ) = @_;

    open( NEWTRANS, "$fname" );

    while (<NEWTRANS>) {
        chomp;
        next if /^\s*#/;
        next if /^\s*$/;
        my ( $time, $author, $transcode, @oargs ) =
          split (/\t/);

        my ($update_time) = _numeric_time($time);

        # Handle the proper transactions
        # Perhaps I should set $_ to $transcode to make the switch simpler?
      SWITCH: {
            if ( $transcode =~ /^add/ ) {
                my ( $itemnum, $descrip, $num, $expdate ) = @oargs;
                unless ( defined $expdate ) {

                    # Set an expiration date one year after the add
                    my ( $mmm, $dd, $yyyy ) = _date_parts($time);
                    $yyyy++;
                    $expdate = "$mmm $dd $yyyy";
                }
                $self->_update( $itemnum, $descrip, $num, $author, $update_time,
                    $expdate );
                last SWITCH;
            }
            if ( $transcode =~ /^del/ ) {
                my ( $itemnum, $descrip ) = @oargs;
                $self->_delete( $itemnum, $update_time );
                last SWITCH;
            }
            if ( $transcode =~ /^bou/ ) {
                my ( $itemnum, $descrip, $num ) = @oargs;
                $descrip = undef if ( $descrip eq '' );
                $self->_bought( $itemnum, $descrip, $num, $author,
                    join ( " ", _date_parts($time) ) );
                last SWITCH;
            }
            if ( $transcode =~ /^unbuy/ ) {
                my ( $itemnum, $descrip, $num ) = @oargs;
                $descrip = undef if ( $descrip eq '' );
                $self->_unbuy( $itemnum, $descrip, $num, $author );
                last SWITCH;
            }
            if ( $transcode =~ /^purge/ ) {
                my ($lastupdate) = @oargs;
                $self->_update_last_update( _numeric_time($lastupdate) );
                last SWITCH;
            }
        }
    }
}

#_____________________________________________________________________________
# Create the filename for a wishlist
# Uses the path and userid to create the full path to the wishlist file
sub _filename
{
    my ($self) = @_;
    if ( exists $self->{_instance} and defined $self->{_instance} ) {
        return $self->{_path}
          . "wishlist."
          . $self->{_instance} . "."
          . $self->{_userid};
    } else {
        return $self->{_path} . "wishlist." . $self->{_userid};
    }
}

#_____________________________________________________________________________
#
# write
#
# Writes a wishlist out as a new file
# Should get modified to indicate who purged the file
# perhaps a name change to purge_write, and maybe combine with purge
sub write
{
    my ( $self, $file ) = @_;
    my $userid = $self->{_userid};

    open( NEWFILE, "> $self->{_path}$file" );
    print NEWFILE _unindent(<<"    ENDHEADER");
        # Defining a wishlist for $userid
        # Local Day, Time, and Date\twho\top\tident\tdescription\tnum\texpires 
    ENDHEADER

    foreach my $item ( $self->get_items ) {

        # print the add for this item
        print NEWFILE join "\t",
          (
            $item->created, $item->by, "added", $item->ident,
            $item->description, $item->requested, $item->expiration_date,
          ),
          "\n";

        # print any purchases
        foreach my $purchase ( $item->purchases ) {
            print NEWFILE join "\t",
              (
                scalar _noonify( $purchase->created ),
                $purchase->buyer, "bought", $item->ident, 
		defined $purchase->note ? $purchase->note : '',
                $purchase->num,
              ),
              "\n";
        }

 # print any delete
 # For now, we are going to pretend it was deleted the same time it was created.
 # I'll have to modify the object to rectify that.
        if ( $item->deleted ) {
            print NEWFILE join "\t",
              (
                $item->created, $item->by, "deleted", $item->ident,
                $item->description,
              ),
              "\n";
        }

    }

    # Print a purge record to set the update time
    print NEWFILE join "\t",
      (
        scalar localtime(),
        $userid, "purge", scalar localtime( $self->last_update ),
      ),
      "\n";
    close NEWFILE;
    return 1;
}

#_____________________________________________________________________________
#
# _write_header
#
# Writes the header lines at the top of a new wishlist file
sub _write_header
{
    my ($self) = @_;
    my $userid = $self->{_userid};
    print NEWTRANS _unindent(<<"ENDHEADER");
        #Defining a wishlist for $userid
        #Local Day, Time, and Date\twho\top\tident\tdescription\tnum\texpires 
ENDHEADER
}

#_____________________________________________________________________________
#
# _update
#     changes the object using the information in a logfile add transaction
#
# Part of the 'read" subsystem that deals with an existing wishlist.
# And called from suggest_update for updating existing items (in which case
# $update_time is always specified.
sub _update
{
    my ( $self, $itemnum, $descrip, $num, $author, $update_time, $expires ) =
      @_;

    if ( defined $self->item($itemnum) ) {
        $self->item($itemnum)->description($descrip);
        $self->item($itemnum)->requested($num);
        $self->item($itemnum)->expiration_date($expires);
    } else {

        # Can't use push here, as the file may insert one out of order
        $self->{_item}[ $itemnum - 1 ] = Christmas::Wishlist::WishItem->new(
            for         => $self->{_userid},
            by          => $author,
            when        => scalar localtime($update_time),
            requested   => $num,
            description => $descrip,
            ident       => $itemnum,
            expires     => $expires,
        );
    }
    $self->_update_last_update($update_time);
}

#_____________________________________________________________________________
#
# _tranlog
# Creates a properly formatted transaction line to the log for this transaction

sub _tranlog
{
    my (%args) = @_;

    $args{expires} ||= " ";

    return join (
        "\t",
        (
            scalar localtime, $args{by},          $args{transcode},
            $args{itemnum},   $args{description}, $args{how_many},
            $args{expires},
        )
    );
}

#_____________________________________________________________________________
#
# _print_log
#
sub _print_log
{
    my (%args) = @_;
    my $string = _tranlog(%args);
    print NEWTRANS "$string\n";
}

#_____________________________________________________________________________
#
sub purge
{
    my ($self) = @_;

    # Using the "grep" form

    $self->{_item} = [
        grep {
            my $days_old = $_->days_since_purchased
              if defined $_;
            (
                defined $_ and ( ( defined $days_old and ( $days_old < 31 ) )
                    or !( $_->obsolete or $_->deleted or !$_->wanted ) )
            );
          } @{ $self->{_item} }
    ];

    my $itemnum = 0;

    # Renumber the items
    for my $item ( $self->get_items ) {
        $item->ident( ++$itemnum );
    }

    return 1;
}

#_____________________________________________________________________________
#
sub remove
{
    my ( $self, %args ) = @_;

    $self->_delete( $args{itemnum}, time );
    $args{transcode} = "delete";
    _print_log(
        by          => $args{by},
        transcode   => "delete",
        itemnum     => $args{itemnum},
        description => $args{description},
        how_many    => $args{how_many},
    );
}

#_____________________________________________________________________________
# _delete - removes a deleted item from the wishlist object
# Both part of the 'read" subsystem that deals with an existing wishlist, and
# the subsystem that processes new requests.

sub _delete
{
    my ( $self, $itemnumber, $update_time ) = @_;

    # Note that the item index is 1 less than the item number
    return unless ( defined $self->{"_item"}[ $itemnumber - 1 ] );

    $self->{"_item"}[ $itemnumber - 1 ]->deleted(1);
    $self->_update_last_update($update_time);

    return $self;
}

#_____________________________________________________________________________
#
sub _update_last_update
{
    my ( $self, $new_update ) = @_;

    return if ( !defined $new_update );
    if (   ( $self->last_update eq "unknown" )
        or ( $new_update > $self->last_update ) )
    {
        $self->{_last_update} = $new_update;
    }
}

#_____________________________________________________________________________
#
# purchase - updates item and writes transaction log
#            need to add record of who purchased
# Args: Hash with element keys:
#    itemnum
#    description
#    by
#    how_many

sub purchase
{
    my ( $self, %args ) = @_;
    return
      unless $args{itemnum}
      and defined $args{description}
      and $args{by}
      and $args{how_many};

    return
      if (
        !$self->_bought(
            $args{itemnum},  $args{description},
            $args{how_many}, $args{by},
            join ( " ", _date_parts( scalar localtime ) ),
        )
      );

    _print_log(
        by          => $args{by},
        transcode   => "bought",
        itemnum     => $args{itemnum},
        description => $args{description},
        how_many    => $args{how_many},
    );

    return 1;
}

#_____________________________________________________________________________
#
sub diff
{
    my ( $self, $self2 ) = @_;

    return "userid:" unless ( $self->userid eq $self2->userid );
    ( $self->last_update eq $self2->last_update )
      or return join " ", "last update", scalar localtime( $self->last_update ),
      scalar localtime( $self2->last_update );
    return "number of items:"
      unless ( scalar $self->get_items eq scalar $self2->get_items );
    foreach my $itemnum ( 1 .. scalar $self->get_items ) {
        my $itema    = $self->item($itemnum);
        my $itemb    = $self2->item($itemnum);
        my $itemdiff = $itema->diff($itemb);
        return "item $itemnum: $itemdiff" unless !$itemdiff;
    }
    return;
}

#_____________________________________________________________________________
#
sub eq
{
    my ( $self, $self2 ) = @_;

    # return unless ($self->userid eq $self2->userid);
    # Specifically don't check user-id at this point, as it will be different.
    return unless ( $self->last_update      eq $self2->last_update );
    return unless ( scalar $self->get_items eq scalar $self2->get_items );
    foreach my $itemnum ( 1 .. scalar $self->get_items ) {
        return unless ( $self->item($itemnum)->eq( $self2->item($itemnum) ) );
    }
    return 1;
}

#_____________________________________________________________________________
#
sub _unbuy
{
    my ( $self, $itemnum, $descrip, $num, $by, $when ) = @_;

    my $item = $self->item($itemnum);

    $item->release_purchase( $num, $by, $descrip );

    # Three possibilities
    #   - delete part of a purchase
    #   - delete all of a purchase
    #   - delete multiple (parts of) purchases
    # To handle all of those cases, lets call with
    # $num, $by, $descrip
    # delete pieces of purchases by $by with $descrip until $num is gone.

}

#_____________________________________________________________________________
#
sub delete_purchase
{
    my ( $self, %args ) = @_;

    my $itemnum = $args{'itemnum'};
    my $item    = $self->item($itemnum);
    my (@purchases_for_user) = $item->user_purchases( $args{'by'} );
    my $purchnum = $args{'purchase'};
    my $purchase = $purchases_for_user[ $purchnum - 1 ];
    my $units    = $purchase->num;

    # Delete it from the object
    $self->item($itemnum)
      ->delete_nth_purchase_by_user( $purchnum, $args{'by'} );

    # Write it out to the file
    _print_log(
        by          => $args{by},
        transcode   => 'unbuy',
        itemnum     => $itemnum,
        description => $purchase->note,
        how_many    => $units,
    );
}

#_____________________________________________________________________________
#
sub _bought
{
    my ( $self, $itemnum, $descrip, $num, $by, $when ) = @_;

    return unless $num > 0;
    my $item = $self->item($itemnum);
    return $item->reserve( $num, $by, $descrip, $when );
}

#_____________________________________________________________________________
#
# suggest_update
# Creates or modifies a suggestion and writes it out to the transaction log
sub suggest_update
{
    my ( $self, %args ) = @_;

    return unless $args{by} and $args{requested} and $args{description};

    if ( $args{itemnum} ) {

        # Given that this is an existing item, the creation date is unchanged
        # from the original item.
        $self->_update(
            $args{itemnum}, $args{description}, $args{requested},
            $args{by},      $args{creation},    $args{expires},
        );
    } else {
        delete $args{itemnum};    # In case it exists but is undefined.
            # Should probably pass the arguments explicitely, rather than
            # pulling things like the previous line.

        # Given that this is a new item, the update will be the current time.
        my $newitem = Christmas::Wishlist::WishItem->new(
            %args,
            for   => $self->{_userid},
            ident => $#{ $self->{_item} } + 2,
            when  => scalar localtime,
        );
        $args{itemnum} = push @{ $self->{_item} }, $newitem;
    }

    _print_log(
        by          => $args{by},
        transcode   => "added",
        itemnum     => $args{itemnum},
        description => $args{description},
        how_many    => $args{requested},
        expires     => $args{expires},
    );
    return $args{itemnum};
}

#_____________________________________________________________________________
#
sub userid
{
    my ($self) = @_;

    return $self->{_userid};
}

#_____________________________________________________________________________
#
sub item
{
    my ( $self, $num ) = @_;

    # The item index is 1 less than the item number
    return unless $num > 0;
    return $self->{_item}[ $num - 1 ];
}

#_____________________________________________________________________________
#
sub last_update
{
    my ($self) = @_;

    return $self->{_last_update};
}

#_____________________________________________________________________________
#
sub get_items
{
    my $self = shift;

    return @{ $self->{_item} };
}

#_____________________________________________________________________________
#
sub _unindent
{
    my $string = shift;
    $string =~ s/^\s+//gm;
    return $string;
}

1;

#_____________________________________________________________________________

__END__

=head1 NAME

Wishlist.pm - Perl Module to manage Gift Wishlists

=head1 VERSION

This document refers to version 0.80 of Christmas::Wishlist,
released Jan 1, 2003.

=head1 SYNOPSIS

    include Christmas::Wishlist;

    $wl = Christmas::Wishlist->new(userid=>$user, create=[0|1], path=<dirpath>);
    $wl->suggest_update( by=>,[itemnum=>], 
                         description=>, requested=>, expires=>);
    $wl->remove(by=>, itemnum=>, description=>, howmany=>);
    $wl->purchase(by=>, itemnum=>, description=>, howmany=> );
    $wl->item(               );
    @itemlist = $wl->get_items(               );
    $wl->userid();
    $wl->last_update();
    $wl->write(<filename>);
    $wl->eq(<wishlist-object>);
    $wl->purge();

=head1 DESCRIPTION

=head2 Overview

Wishlist.pm manages Wishlists, which are lists of items that someone wants as 
gifts.  Each list is owned by a particular person, but may have suggestions 
made by any number of suggestors. 

=head1 ENVIRONMENT

No requirements or use beyond perl of environment variables.

=head1 DIAGNOSTICS

=over 4

=item "missing userid"

The constructor requires a userid argument, and croaks the whole program if 
there isn't one. Maybe this should be a little less catastrophic?

=back

=head1 ENHANCEMENTS

=head1 REFACTORINGS

 Move NEWTRANS into object.

 Change to explicit parameters to new in suggest_update

=head1 BUGS

Bad data in the file should be reported, not cause a failure to return. 
For instance, bad date fields should be appropriately reported as "Bad".

=head1 FILES

wishlist.<owner> in the repository.
wishlist.<copy>.<owner>?

 The file can have commentary records starting with a #
 or transaction records including:
  |<when> <whom> added  <item> <description> <needed> <expires>
  |<when> <whom> bought <item> <description> <num-bought>
  |<when> <whom> delete <item> <description>
  |<when> <whom> unbuy  <item> <description> <returned>

 where fields are separated by tabs.

=head1 SEE ALSO

=head1 AUTHOR

Michael G. Birdsall

=head1 COPYRIGHT

Copyright (c) 2002,2003, Michael G. Birdsall. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

