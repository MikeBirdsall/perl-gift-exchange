#!/usr/local/bin/perl
# $Id: ibought.pl,v 1.6 2002/09/20 21:47:55 mbirdsal Exp $

# This CGI-BIN perl script is part of the suite for Wish lists.
# This script reports to a specific person all of the gifts they have marked for buying
# in every wish list.
#
# The following line is useful to cut and paste for debugging purposes. 
#if ($debug) {print h2({-class=>'Debug'}, "Line " , __LINE__, " module " , (caller(0))[3])}

use lib '/big/dom/xkirkbird/lib/perl5/site_perl/5.005/';
use CGI ':standard', ':html3';
use CGI::Carp;
use CGI qw/escapeHTML unescapeHTML/;
use POSIX 'strftime';
use Fcntl;
use Christmas::Wishlist;
use strict;

my $debug = param('debug');

#my $debug = 1;

#_____________________________________________________________________________
# Closure for style definitions - these all manipulate styles
{
    my $style_prefix = "/css/wls_";

    #
    # paint_style_menu
    #     prints the html for the menu to choose styles
    sub paint_style_menu
    {

        print br, p("Choose style for pages");
        print popup_menu(
            -name   => 'style',
            -values => [
                "",
                map { m[\.\.${style_prefix}(\w+)\.css] }
                  glob("..${style_prefix}*.css")
            ],
        );
    }

    #
    # stylefile
    #     Returns a string containing the file with the css style for the style
    #     parameter chosen
    sub stylefile
    {
        return $style_prefix . ( param('style') || 'default' ) . '.css';
    }
}

#_____________________________________________________________________________
# Set the initial data
# The following two variables, $gltitle and $glrepository, are actually used as
# global variables. They are the only two in this program. Consider getting rid
# of them, and maybe making a closure to get rid of all globals.

my $glrepository =
  ( $ENV{HOME} || $ENV{LOGDIR} || ( getpwuid($>) )[7] )
  . "/wishlistdata/family/";

my $gluser = remote_user()
  || error_page("You are not properly logged in.");

my $gltitle = 'Hello '
  . display_name($gluser)
  . '! You Are On the Page To View Items You have Bought';

Christmas::Wishlist->set_repository($glrepository)
  or error_page("Repository $glrepository does not exist.");

print header,
  start_html(
    -title => $gltitle,
    -style => { -src => stylefile() }
  );

if ($debug) { print h2( { -class => 'Debug' }, "Repository at $glrepository" ) }

# Set $owner to all possible wishlists, so we check them all
my @owner = all_wishlists($gluser);

paint_wishlist( $gluser, @owner );
paint_style_menu();
print end_form();
print end_html;

#_____________________________________________________________________________
#
# display_name
#     returns the display name given the login-id
sub display_name
{

    return attributes_for( $_[0], 'name' );
}

#_____________________________________________________________________________
#
# paint_footer
#    paints a set of submits (normally) at the bottom of the screen
#    which does the standard control for a screen
sub paint_footer
{
    my ( $command, @command ) = @_;

    print hidden( -name => 'lastaction', -value => $command, -override => 1 )
      if defined $command;

    foreach $command (@command) {
        print submit( -name => 'action', -value => $command );
    }
    print submit( -name => 'dummy', -value => 'Redraw the screen' );
    print button(
        -value   => "Family Page",
        -onClick => "window.location='index.html'"
    );
    print button( -value => "Print Page", -onClick => "window.print()" );
}

#_____________________________________________________________________________
#
# error_page fills in the html page with an error message when there is an error
# which prevents further processing
#
sub error_page
{
    my ($error) = @_;

    print header,
      start_html(
        -title => "Wishlist Error Notification",
        -style => { -src => stylefile() }
      );
    print h1( { -class => 'Warning' }, $error );
    print end_html;

    exit;

}

#_____________________________________________________________________________
#
# push_item
# pushes a table entry for an item formatted for the owner of the list to view
sub push_item(\@$$)
{
    my ( $rowref, $item, $who ) = @_;
    return unless defined $item;
    return if $item->deleted();

    my $id = $item->ident();
    push (
        @{$rowref},
        td( [ display_name($who), escapeHTML( $item->description() ), ] )
    );
}

#_____________________________________________________________________________
#
# paint_wishlist is an "action" routine and the default action item.
# It displays a page with a table showing the list of suggestions
# either formatted for the owner or for anyone else.
#
sub paint_wishlist
{
    my ( $user, @owner ) = @_;

    my @rows;

    push ( @rows, th( [ 'For', 'Description' ] ) );

    foreach my $owner (@owner) {
        my $wl = Christmas::Wishlist->new( userid => $owner );
        my @items = $wl->get_items();

        foreach my $item (@items) {
            push_item( @rows, $item, $owner )
              if ( defined $item and $item->purchased_by($user) );
        }

    }

    print startform(),
      table(
        { -border => '' },
        caption(
            strong(
                "Wish List for ",
                join ( ", ", map { display_name($_) } @owner )
            )
        ),
        TR( \@rows )
      ),
      br, hidden( -name => 'owner' );
    paint_footer(undef);
}

#_____________________________________________________________________________
#
sub all_wishlists
{
    my ($user) = @_;
    my @lists;

    foreach my $person ( glob("$glrepository/person.*") ) {
        $person =~ s[$glrepository/person\.][];
        push @lists, $person;
    }
    return @lists;
}

#_____________________________________________________________________________
#
# Routine to read any needed attributes for a particular user.
# The routine should cache any attributes it does get, and return them
# without reading the file.

sub attributes_for
{
    my ( $person, @atts ) = @_;
    my %UserValues = ();
    my @response;

    open PERSON, "$glrepository/person.$person"
      or print "I don't have any information on $person", br;
    while (<PERSON>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        next unless length;
        my ( $var, $value ) = split ( /\s*=\s*/, $_, 2 );
        my $temp = $UserValues{$var} = $value;
    }
    foreach (@atts) {
        unshift @response, $UserValues{$_};
    }
    return wantarray() ? @response : $response[0];
}

#_____________________________________________________________________________

__END__

=head1 NAME

multilist - cgi-bin program for managing lists of gifts

=head1 VERSION

This document refers to version $Name:  $ 0.50 of wishlist, released Aug 24, 2002.

=head1 SYNOPSIS

    wishlist [user=<user>] [owner=<owner>] [action=<action>]

=head1 DESCRIPTION

=head2 Overview

=head2 Input paramters

    owner
    user
    action
    description
    wanted
    debug

=head2 Any other information that's important

=head1 ENVIRONMENT

REMOTE_USER - the login ID of the individual running the program.

=head1 DIAGNOSTICS

=over 4

=item "You are not properly logged in

This message will be printed on the page when we cannot detect the 
remote user environment form. That means that either the web site
was not set up with security, so the user is not logged in and 
is unidentified, or that the program is being run interactively
without the REMOTE_USER environment variable set.

=item "Repository <dirname> does not exist."

The repository for all of the data-files is expected in directory
<dirname> and the program cannot locate that directory.

=back

=head1 BUGS

=over 4

=item None currently identified

=back

=head1 REFACTORINGS

No refactorings currently identified

=head1 SUGGESTED ENHANCEMENTS

=over 4

=item Return Control

Add a control for each page to return to the main menu 
(back to mbirdsall.com? or back to mbirdsall.com/family/)

=item Redraw Control

Add a control to redraw the screen, and make the style immediately visible.

=item Edit or Undo Purchases

Allow a purchaser to renege on a purchase - putting it back in the list as
available - or to change their public or private note.

=item Expiration date

Allow a suggester (particularly the owner) to put an expiration date on the
item, after which time he is free to buy it himself.

=item Retrieving password

Send lost passwords out the stored e-mail address.

=item Personal Control Panel

Create a Control Panel for each user where the user can change such things as

    Screen color preferences
    Full Name
    email address
    Password
    Clothing Sizes
    Defaults
        expiration date
    Occasions
        Birthdays, Holidays, Anniversaries, ...
    Watch List
        People to be notified about

=item Change date-times to UTC

=item Help screens

=item Print Friendly Page and Print Button

=item URLs in suggestions

=item Public Suggestions

Allow suggestions to be marked as visible for owner

=item E-Mail Notifications

=back 

=head1 FILES

=head1 SEE ALSO

=head1 AUTHOR

Michael G. Birdsall

=head1 COPYRIGHT

Copyright (c) 2002, Michael G. Birdsall. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

