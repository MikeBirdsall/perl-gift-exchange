#!/usr/local/bin/perl
# $Id: wishlist.pl,v 1.48 2003/01/30 22:17:29 mbirdsal Exp $
# $Name:  $

# This CGI-BIN perl script is the standard user script for Wish lists.
# It has been modified to use the Wishlist.pm objects, and should only manage
# the web access to using those objects.
# A wish list is a list for each person to keep track of gifts they would like
# and gifts that people have bought them.
#
# Uses Wishlist objects and WishItem objects to manipulate and interrogate
# a wishlist (which is actually stored as file of all transactions).
#
# The following two lines are useful to cut and paste for debugging purposes.
#if ($debug) {print h2({-class=>'Debug'},
#                   "Line ",__LINE__," module ",(caller(0))[3])}

use lib '/big/dom/xkirkbird/lib/perl5/site_perl/5.005/';
use CGI ':standard', ':html3';
use CGI::Carp;
use CGI qw/escapeHTML unescapeHTML/;
use POSIX 'strftime';
use Time::Local;
use Fcntl;
use Christmas::Wishlist;
use strict;

my $debug = param('debug');

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
  . '! You Are On the Page To Change or Display Wish Lists';

Christmas::Wishlist->set_repository($glrepository)
  or error_page("Repository $glrepository does not exist.");

print header,
  start_html(
    -title => $gltitle,
    -style => { -src => stylefile() }
  );

if ($debug) { print h2( { -class => 'Debug' }, "Repository at $glrepository" ) }

# paint_owner_choice_form does not return, but re-enters with param('owner') set
my $glowner = param('owner') || paint_owner_choice_form($gluser);

# Now that we have an owner; get the wishlist for that owner
my $glwishlist = Christmas::Wishlist->new( userid => $glowner );

#_____________________________________________________________________________
# Do the specific actions for this invocation

$_ = param('action') || param('lastaction');

print start_form( -method => "GET" );

CASE: {

    # Commands Issued from the Wishlist

    /^Delete/i and do {
        delete_item( $glwishlist, $gluser, $_ );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Buy Item/i and do {
        paint_purchase_form( $glwishlist, $gluser, $_ );
        last CASE;
    };

    # Added in for new "purchase object" based edits
    /^Modify Purchase/i and do {
        paint_release_form( $glwishlist, $gluser, $_ );
        last CASE;
    };

    /^Edit /i and do {
        paint_item_change_form( $glwishlist, $gluser, $_ );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^(Change Entry|Add Suggestion)/i and do {
        paint_s_form( $glwishlist, $gluser );
        last CASE;
    };

    # #   Other Commands

    /^Submit Modification/i and do {
        submit_purchase_modification( $glwishlist, $gluser, $_ );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Confirm Purchase/i and do {
        confirm_purch_or_rel( $glwishlist, $gluser, $_ );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Confirm Release/i and do {
        confirm_purch_or_rel( $glwishlist, $gluser, $_ );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Submit Edited Item/i and do {
        submit_edit_or_suggestion( $glwishlist, $gluser, param('item') );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Submit Suggestion/i and do {
        paint_s_conf( $glwishlist, $gluser );
        last CASE;
    };

    /^Confirm Entry/i and do {
        submit_edit_or_suggestion( $glwishlist, $gluser );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Release Purchase/i and do {
        submit_purchase_release( $glwishlist, $gluser, $_ );
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    /^Pick A/i and do {
        paint_owner_choice_form($gluser);
        last CASE;
    };

    /^Choose List/i and do {
        paint_wishlist( $glwishlist, $gluser );
        last CASE;
    };

    # default
    if ( defined $_ ) { print h2("Dont understand command $_") }
    paint_wishlist( $glwishlist, $gluser );
}
print end_form;
print end_html;

#_____________________________________________________________________________
#
# remove_tabs
sub remove_tabs
{
    my $description = shift;

    $description =~ tr/\t/ /;
    return $description;
}

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
# delete_item runs as an "action" command.
# It deletes the designated item.
# Only the owner should be allowed to delete it.

sub delete_item
{
    my ( $wishlist, $user, $which ) = @_;
    my $itemnum;
    ( $itemnum = $which ) =~ s/Delete //;

    $wishlist->remove( itemnum => $itemnum, by => $user, );
}

#_____________________________________________________________________________
#
# ppf_help_message
sub ppf_help_message
{
    my ( $wishlist, $user, $which ) = @_;
    return p(
        { -class => 'Help' },
        display_name($user),
        "this form lets you tell the world that you will be buying -",
        escapeHTML( $wishlist->item($which)->description() ),
        " - for ",
        display_name( $wishlist->userid() ),
      ),
      p( { -class => 'Help' },
        "Please help out by giving me a little more information." ),
      p(
        { -class => 'Help' },
        "Note: is where you put in a little information ",
        "for yourself or others about this purchase. If ",
        "you are buying a CD from several asked for, ",
        "you could list which CD you found. If you are ",
        "willing to let others go in on it with you, ",
        "you could say so."
      ),
      p(
        { -class => 'Help' },
        "How many are you buying? lets you choose how many ",
        "(of those still wanted) you are going to buy."
      );
}

#_____________________________________________________________________________
#
# Prints a help message on the "Release Form" to help a user fill it in.
# prf_help_message
sub prf_help_message
{
    my ( $wishlist, $user, $which ) = @_;
    return p(
        { -class => 'Help' },
        display_name($user),
        "You indicated that you would be buying",
        escapeHTML( $wishlist->item($which)->description() ),
        " - for ",
        display_name( $wishlist->userid() ),
      ),
      p(
        { -class => 'Help' },
        "This form lets you reverse that process, perhaps because ",
        "you could not buy it, perhaps because you got something else."
      ),
      p(
        { -class => 'Help' },
        "Note: Add some information. If you had put in some information ",
        "on the Note: field when you reserved it, you can tell everyone ",
        "if that is no longer true.",
      ),
      p(
        { -class => 'Help' },
        "How many are you releasing? lets you indicate how many ",
        "(of those you reserved) you are not going to buy."
      );
}

#_____________________________________________________________________________
#
# paint_command_bar
#    paints a set of submits (normally) at the bottom of the screen
#    which does the standard control for a screen
sub paint_command_bar
{
    my ( $command, @command ) = @_;

    print br, "\n";
    print hidden('owner'), "\n";
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
# paint_footer
#    paints a set of submits (normally) at the bottom of the screen
#    which does the standard control for a screen
sub paint_footer
{
    my ( $command, @command ) = @_;

    print br, "\n";

    # Flush owner back to a single value, if it has gotten larger
    print hidden(
        -name     => 'owner',
        -value    => ( scalar param('owner') ),
        -override => 1
      ),
      "\n";
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
    paint_style_menu();
}

#_____________________________________________________________________________
#
# descrip_menu
# Returns the Gift Description form segment for a number of pages
sub descrip_menu
{
    my ($header) = @_;

    return TR( { -align => "LEFT" },
        th('Note'), td( textfield( -name => 'description', -size => 90 ) ) );
}

#_____________________________________________________________________________
#
# paint_release_form
sub paint_release_form
{
    my ( $wishlist, $user, $which ) = @_;
    ( my $itemnum = $which ) =~ s/Modify Purchase //;

    # Pass along the itemnumber for subsequent commands
    print hidden( 'item', $itemnum );

    # Put up the headers
    print h1("Update Purchase Information"),
      h2( display_name($user), "Purchases of" ),
      h2( $wishlist->item($itemnum)->description ),
      h2( "for ", display_name( $wishlist->userid ) ), "\n";

    my $wanted = $wishlist->item($itemnum)->wanted;
    $wanted = 9 if $wanted eq 'any';

    if ( $wanted > 0 ) {
        print h2( { -align => "CENTER" }, "New Reservation or Purchase" ),
          table(
            Tr( { -align => "LEFT" }, th( [ 'How Many', 'Note', 'Confirm' ] ) ),
            Tr(
                { -align => "LEFT" },
                td(
                    [
                        popup_menu(
                            -name    => 'wanted',
                            -values  => [ 1 .. $wanted ],
                            -size    => 1,
                            -default => 1,
                        ),
                        textfield(
                            -name => 'description',
                            -size => '90',
                        ),
                        submit(
                            -name  => 'action',
                            -value => "Confirm Purchase $itemnum",
                        ),
                    ]
                ),
            ),
          ),
          ;
    }

    paint_mod_purch_form( $wishlist, $user, $itemnum );

    paint_footer( $which, "Pick Another List" );
}

#_____________________________________________________________________________
#
# paint_mod_purch_form
# Paints the Screen for a user to modify one of the purchases they have already
# made for a specific WishItem.
sub paint_mod_purch_form
{
    my ( $wishlist, $user, $which ) = @_;
    my @rows;
    my $purch_num = 0;

    # Prepare the entries for the number of purchases this user has
    push @rows, Tr( th( [ 'How Many', 'Date', 'Note', 'Update' ] ) );
    foreach my $purchase ( $wishlist->item($which)->user_purchases($user) ) {
        $purch_num += 1;
        push @rows, Tr(
            td(
                [
                    popup_menu(
                        -name    => 'wantarray',
                        -values  => [ 1 .. $purchase->num ],
                        -size    => 1,
                        -default => $purchase->num
                    ),
                    $purchase->when,
                    textfield(
                        -name    => 'notearray',
                        -size    => 90,
                        -default => $purchase->note,
                    ),

                   # Need buttons to say "Delete" or "Modify" and they need to
                   # indicate which purchase so the software can take care of it
                    submit(
                        -name  => 'action',
                        -value => "Submit Modification $purch_num"
                    ),
                    submit(
                        -name  => 'action',
                        -value => "Release Purchase $purch_num"
                    ),
                ],
            ),
        );
    }
    print h2( { -align => 'CENTER' }, "Modify a Purchase" ), "\n", table(@rows),
      "\n";

}

#_____________________________________________________________________________
#
# paint_purchase_or_release_form
# Paints the screen in the way those two actions need.
sub paint_purchase_or_release_form
{
    my ( $wishlist, $header, $prompt, $values, $default ) = @_;

    print h1( $header, display_name( $wishlist->userid() ) );
    print table(
        descrip_menu('Note'),
        quant_menu(
            prompt  => $prompt,
            values  => $values,
            default => $default,
        ),
    );
}

#_____________________________________________________________________________
#
# paint_purchase_form runs as an  "action" command.
# It creates the page which gets all the information for a purchase
#
# Make the wanted selection work
# limited the wanted selection to the number still wanted
sub paint_purchase_form
{
    my ( $wishlist, $user, $which ) = @_;
    my $itemnum;
    ( $itemnum = $which ) =~ s/(Buy|Release) Item //;

    paint_purchase_or_release_form(
        $wishlist,
        ( $which =~ /Buy/ )
        ? "Buying or Reserving a Gift for "
        : "Releasing a gift I Reserved for ",
        ( $which =~ /Buy/ )
        ? "How many are you buying?"
        : "How many are you releasing?",
        ( $which =~ /Buy/ )
        ? ( $wishlist->item($itemnum)->wanted() !~ /^[1-9]\d*/ )
        ? [ 1 .. 9 ]
        : [ 1 .. $wishlist->item($itemnum)->wanted() ]
        : [ 1 .. $wishlist->item($itemnum)->user_units_purchased($user) ],
        ( $which =~ /Buy/ )
        ? 1
        : $wishlist->item($itemnum)->user_units_purchased($user),
    );

    if ( $which =~ /Buy/ ) {
        print ppf_help_message( $wishlist, $user, $itemnum );
    } else {
        print prf_help_message( $wishlist, $user, $itemnum );
    }
    paint_footer(
        $which,
        ( $which =~ /Buy/ )
        ? "Confirm Purchase $itemnum"
        : "Confirm Release $itemnum",
        "Pick Another List"
    );

}

#_____________________________________________________________________________
#
# submit_purchase_modification runs as an "action" command
# It modifies a particular purchase
#
sub submit_purchase_modification
{
    my ( $wishlist, $user, $which ) = @_;

    ( my $purchnum = $which ) =~ s/Submit Modification //;
    print h2( "Modifying purchase $purchnum of item ",
        param('item'), " for user $user." );

    my ($newnum)  = ( param('wantarray') )[ $purchnum - 1 ];
    my ($newnote) = ( param('notearray') )[ $purchnum - 1 ];

    print h2("Changing number wanted to $newnum and description to :$newnote:");

    # I've got to change the values and also get it written out to the file
    # easiest is probably to delete it and then repurchase it with the new info?

    $wishlist->delete_purchase(
        itemnum  => param('item'),
        purchase => $purchnum,
        by       => $user,
    );

    $wishlist->purchase(
        itemnum     => param('item'),
        description => remove_tabs($newnote),
        how_many    => $newnum,
        by          => $user,
    );
}

#_____________________________________________________________________________
#
# submit_purchase_release runs as an  "action" command.
# It deletes a particular purchase
#
sub submit_purchase_release
{
    my ( $wishlist, $user, $which ) = @_;

    ( my $purchnum = $which ) =~ s/Release Purchase //;

    print h2( "Releasing purchase $purchnum of item ",
        param('item'), " for user $user." );
    print h2( "Notes from ", join ( ":", param('notearray') ) );

    $wishlist->delete_purchase(
        itemnum  => param('item'),
        purchase => $purchnum,
        by       => $user
    );
}

#_____________________________________________________________________________
#
# confirm_purch_or_rel runs as an  "action" command.
# It marks an instance of this item as being bought by the user
#
sub confirm_purch_or_rel
{
    my ( $wishlist, $user, $which ) = @_;
    ( my $itemnum = $which ) =~ s/Confirm\s+(Purchase|Release)\s+//;

    my $wanted = param('wanted') * ( ( $which =~ /Release/ ) ? -1 : 1 );

    $wishlist->purchase(
        itemnum     => $itemnum,
        description => remove_tabs( param('description') ) || '',
        how_many    => $wanted,
        by          => $user,
    );
}

#_____________________________________________________________________________
#
# validate_expiration returns a specific type of expiration date, i.e. either:
#     "MMM dd yyyy"  or  "never"  or  "invalid"
# For the moment, it is either the "MMM dd yyyy" form or "never"
sub validate_expiration
{
    my $x;

    my $xtype = param('expires_type');

    return "never" if $xtype =~ /never/i;
    return "never" if $xtype =~ /^\s*$/;

    if ( $xtype eq 'Date Selected' ) {
        $x = join " ", param('month_expires'), param('day_expires'),
          param('year_expires');
        return "never" if $x =~ /^\s*$/;
        return $x;
    }
    if ( $xtype eq 'Christmas' ) {

        # Compute the date of next Christmas, being careful of Dec 25-Dec 31.
        my ( $DAY, $MONTH, $YEAR ) = (localtime)[ 3, 4, 5 ];
        $YEAR++ if ( ( $MONTH == 11 ) and ( $DAY >= 25 ) );
        $YEAR += 1900;
        return "Dec 26 $YEAR";
    }

    if ( $xtype eq 'In A Year' ) {

        # Compute the date of a year from now.
        my ( $DAY, $MONTH, $YEAR ) = (localtime)[ 3, 4, 5 ];
        $DAY = 28 if ( ( $MONTH == 1 ) and ( $DAY >= 29 ) );
        $YEAR += 1901;
        $MONTH = (
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        )[$MONTH];
        return "$MONTH $DAY $YEAR";
    }

    return "The conversion routine from "
      . param('expires_type')
      . " is not yet implemented.";
}

#_____________________________________________________________________________
#
# submit_edit_or_suggestion is an "action" routine.
# which does the actual update of the wishlist for paint_item_change_form
# and paint_s_form
sub submit_edit_or_suggestion
{
    my ( $wishlist, $user, $itemnum ) = @_;

    my $validated_expiration = validate_expiration();

    # Note that "itemnum" is undefined if this is a new item
    # but always defined for an existing item. This is used
    # by suggest_update to determine the original date of an
    # item.
    # If there is both an itemnum and an expires, there is currently a bug.
    $wishlist->suggest_update(
        itemnum     => $itemnum,
        description => remove_tabs( param('description') ),
        by          => $user,
        requested   => param('wanted'),
        expires     => $validated_expiration,
    );
}

#_____________________________________________________________________________
#
# paint_item_change_form is an "action" routine.
# It sets up a form which lets the user edit an item and update the information
# The actual update is done by submit_edit_or_suggestion
#
sub paint_item_change_form
{
    my ( $wishlist, $user, $which ) = @_;
    my $itemnum;
    ( $itemnum = $which ) =~ s/Edit //;

    print h1("Modify a Suggestion"),
      table(
        TR(
            { -align => "LEFT" },
            th('Gift Description'),
            td(
                textfield(
                    -name    => 'description',
                    -size    => 75,
                    -default =>
                      escapeHTML( $wishlist->item($itemnum)->description() ),
                )
            )
        ),
        quant_menu(
            prompt  => 'Number wanted',
            values  => [ 'any', 1, 2, 3, 4, 5, 6, 7, 8 ],
            default => $wishlist->item($itemnum)->requested(),
        ),
        expires_menu( $wishlist->item($itemnum) ),
      ),
      hidden( -name => 'item', -value => $itemnum );

    # No need to paint_footer, as we are going to paint_wishlist, anyway.
    # Oops, we need the footer for our own commands. I forgot that.
    # Let's paint them as commands, not as a footer.
    paint_command_bar( $which, "Submit Edited Item", "Delete $itemnum" );
}

#_____________________________________________________________________________
#
# quant_menu
# returns the form segment for asking a quantity, typically the number wanted

sub quant_menu
{
    my (%args) = @_;
    return TR(
        { -align => "LEFT" },
        th( $args{prompt} ),
        td(
            popup_menu(
                -name    => 'wanted',
                -values  => $args{values},
                -size    => 5,
                -default => $args{default},
            )
        )
    );
}

#_____________________________________________________________________________
#
# expires_menu
# returns the form segment for specifying an expiration date
# used in paint_s_form and paint_item_change_form,
# Needs to set default to the items default date, if it exists.

sub expires_menu
{
    my ($item) = @_;
    my %default;

    if ( $item and ( $item->expiration_date ne 'never' ) ) {

        # We have an item with an existing expiration date to make the default
        $default{type} = 'Date Selected';
        ( $default{month}, $default{day}, $default{year} ) =
          split ( " ", $item->expiration_date );
    } else {
        $default{type} = 'In A Year';
    }

    return TR(
        { -align => "LEFT" },
        th('Expiration Date'),
        td(
            popup_menu(
                -name   => 'expires_type',
                -values =>
                  [ 'Never', 'Date Selected', 'Christmas', 'In A Year', ],
                -size    => 9,
                -default => $default{type},
            ),
            popup_menu(
                -name   => 'month_expires',
                -values => [
                    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ],
                -size    => 9,
                -default => $default{month}
            ),
            popup_menu(
                -name    => 'day_expires',
                -values  => [ 1 .. 31 ],
                -size    => 9,
                -default => $default{day}
            ),
            popup_menu(
                -name    => 'year_expires',
                -values  => [ 2010 .. 2020 ],
                -size    => 9,
                -default => $default{year}
            ),
        ),
    );
}

#_____________________________________________________________________________
#
# paint_s_form is an "action" routine
# It sets up the form to make a suggestion
# (Although it is called by both "add" and "change"?
# The actual update of the wishlist is done by paint_s_conf

sub paint_s_form
{
    my ( $wishlist, $user ) = @_;

    print h1(
        display_name($user),
        " is adding a suggestion for ",
        display_name( $wishlist->userid() )
      ),
      table(
        descrip_menu('Gift Description'),
        quant_menu(
            prompt  => 'Number Wanted',
            values  => [ 'any', 1, 2, 3, 4, 5, 6, 7, 8 ],
            default => 1,
        ),
      ),
      expires_menu();
    paint_footer( 'Add Suggestion', 'Submit Suggestion' );
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
# print_warning be used used when a form has required fields missing
# It is used to print a prompt prior to redrawing the partially completed form
#
sub print_warning
{

    print p(
        { -class => 'Warning' },
        'Please fill in the following fields: ',
        em( join ( ', ', map { ucfirst } @_ ) ), '.'
    );

}

#_____________________________________________________________________________
#
# paint_s_conf is an "action" routine
# Which prints a form repeating the suggestion information and checking with
# the user that it is right. If so, the wishlist will actually be updated by
# submit_edit_or_suggestion

sub paint_s_conf
{
    my ( $wishlist, $user ) = @_;

    my @REQUIRED = qw/description wanted/;
    my @missing  = check_missing(@REQUIRED);

    if (@missing) {
        print_warning(@missing);
        paint_s_form( $wishlist, $user );
        return;
    }
    my @rows;
    foreach (@REQUIRED) {
        push (
            @rows,
            TR(
                th( { -align => "LEFT" }, ucfirst $_ ),
                td( escapeHTML( param($_) ) )
            )
        );
    };
    if(param('expires_type') ne "Date Selected") {
        push (
            @rows,
            TR(
                th { -align => "LEFT" },
                'Expiration Date',
                td(
                    param('expires_type'), 
                )
            )
        )
    } else {
        push (
            @rows,
            TR(
                th { -align => "LEFT" },
                'Expiration Date',
                td(
                    param('expires_type'), param('month_expires'),
                    param('day_expires'),  param('year_expires'),
                )
            )
        )
    };
    print h1(
        display_name($user),
        " is adding a suggestion for ",
        display_name( $wishlist->userid() )
      ),
      "Here is your suggested gift. Press ", em('Confirm'), " to save it, or ",
      em('Change'), " to change it.", hr, table(@rows), hr;

    foreach (@REQUIRED) {
        print hidden( -name => $_ );
    }
    print hidden( -name => "expires_type" ), hidden( -name => "month_expires" ),
      hidden( -name     => "day_expires" ),  hidden( -name => "year_expires" );
    paint_footer( 'Submit Suggestion', 'Change Entry', 'Confirm Entry' );
}

#_____________________________________________________________________________
#
# check_missing is a utility routine which can be called by a form processing
# routine to check if required parameters are filled out.
# The parameters are passed and the required parameters are listed in the global
# array @REQUIRED

sub check_missing
{
    my (@REQUIRED) = @_;
    my (%p);

    # Check each parameter and find all those which actually have data
    grep ( param($_) ne '' && $p{$_}++, param() );

    # Return any required param which does not exist or does not have data
    return grep( !$p{$_}, @REQUIRED );

}

#_____________________________________________________________________________
#
# push_user_item
# format and push an item for someone other than the owner of the list to view
sub push_user_item(\@$$$)
{
    my ( $rowref, $item, $wl, $user ) = @_;
    my $note_string;

    return unless defined $item;
    return if ( $item->deleted()  and !$item->purchased_by($user) );
    return if ( $item->obsolete() and !$item->purchased_by($user) );
    my $id = $item->ident();

    my $action_string = (
        $item->purchased_by($user) ? submit(
            -name  => 'action',
            -value => "Modify Purchase $id"
          )
        : ( ( $item->wanted !~ /^-?\d+$/ ) || ( $item->wanted > 0 ) ) ? submit(
            -name  => 'action',
            -value => "Buy Item $id"
          )
        : "Gone",
    );

    # If the user suggested this item, let him edit it.
    if ( $item->by() eq $user ) {
        $note_string = submit( -name => 'action', -value => "Edit $id" );

        # If someone other than the owner or this user suggested the item
        # Display who did in the notes
    } elsif ( $item->by() ne $wl->userid() ) {
        $note_string = "Suggested by " . display_name( $item->by() ) . "\n";
    }

    # Create a string of the item notes,
    # including tsuggester part previously set.
    if ( scalar $item->notes ) {
        my @local_notes = $item->notes;
        $note_string .= join ( " ",
            map { p( { style => "margin-top: -0em" }, escapeHTML($_) ) }
              @local_notes );
    }

    my @cells = [
        $action_string,                     $item->wanted(),
        escapeHTML( $item->description() ), $item->bought,
        $item->expiration_date(),           $note_string,
    ];
    if ( ( $item->deleted() or $item->obsolete() )
        and $item->purchased_by($user) )
    {
        push ( @{$rowref}, "\n" . td( { -class => 'obsolete' }, @cells, ) );
    } else {
        push ( @{$rowref}, "\n" . td( @cells, ) );
    }
}

#_____________________________________________________________________________
#
# push_owner_item
# pushes a table entry for an item formatted for the owner of the list to view
sub push_owner_item(\@$$)
{
    my ( $rowref, $item, $wl ) = @_;
    return unless defined $item;
    return if $item->deleted();
    return if ( $item->by() ne $wl->userid() );

    my $id    = $item->ident();
    my @cells = [
        submit( -name => 'action', -value => "Delete $id" ),
        $item->requested(),
        submit( -name => 'action', -value => "Edit $id" ),
        escapeHTML( $item->description() ),
        $item->expiration_date(),
    ];
    if ( $item->obsolete() ) {
        push ( @{$rowref}, "\n" . td( { -class => 'obsolete' }, @cells, ), );
    } else {
        push ( @{$rowref}, "\n" . td(@cells), );
    }
}

#_____________________________________________________________________________
#
# paint_wishlist is an "action"routine and the default action item.
# It displays a page with a table showing the list of suggestions
# either formatted for the owner or for anyone else.
#
sub paint_wishlist
{
    my ( $wl, $user ) = @_;
    my @rows;
    my @items = $wl->get_items();
    my $owner = $wl->userid();

    # @items is an array of WishItem objects each giving a value for
    # for - Who this suggestion is for; in this case it should always be $owner
    # by  - Who created the suggestion
    # wanted - Number of this item currently desired
    #          (either an integer or a string)
    # description - Description of the item

    # Create the header
    push (
        @rows,
        th(
            ( $wl->userid() eq $user )
            ? [ 'Delete', 'Wanted', 'Edit', 'Description', 'Expires', ]
            : [
                'Buy',     'Needed', 'Description', 'Purchased',
                'Expires', 'Notes'
            ]
        )
    );

    if ( $wl->userid() eq $user ) {
        foreach my $item (@items) { push_owner_item( @rows, $item, $wl ) }
    } else {
        foreach my $item (@items) { push_user_item( @rows, $item, $wl, $user ) }
    }

    print h1( "Viewing the Wish List for ", display_name($owner) ), "\n",
      submit( -name => 'action', -value => "Add Suggestion" ),
      submit( -name => 'action', -value => 'Pick Another List' ), "\n",

      h3( "Last modified by owner "
          . display_name($owner) . " on "
          . localtime( $wl->last_update() ) ), "\n",

      table(
        { -border => '' },
        caption( strong("Wish List for $owner") ),
        TR( \@rows )
      );
    paint_footer( undef, "Add Suggestion", "Pick Another List" );
}

#_____________________________________________________________________________
#
# paint_owner_choice_form - utility routine used to display a form allowing
# the user to choose a wishlist to work on
#
sub paint_owner_choice_form
{
    my ($user) = @_;
    my %lists;

    foreach my $person ( glob("$glrepository/person.*") ) {
        $person =~ s[$glrepository/person\.][];
        ( $lists{$person} ) = attributes_for( $person, 'name' );
    }
    print h1($gltitle), start_form(),
      radio_group(
        -name    => 'owner',
        -values  => [ ( sort keys %lists ) ],
        -labels  => \%lists,
        -default => $user,
        -cols    => 4,
      );
    paint_footer( 'Pick Another List', 'Choose List' );
    print end_form();
    print end_html();
    exit;
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

wishlist.pl - cgi-bin program for managing lists of gifts

=head1 VERSION

This document refers to version 0.90 of wishlist, released Jan 1, 2003.

=head1 SYNOPSIS

 wishlist [<common-options>] [owner=<own> action=<act> <action-based-options>]
 
 <common-options> => [debug=<level>] [style=<sname>] [lastaction=<act>]

 <act>            => [Delete|Buy Item|Edit] <itemnum>
                     |Confirm Purchase|Confirm Release|Confirm Entry
                     |Submit Suggestion|Submit Edited Item|
                     |Change Entry|Add Suggestion

 <action-based-options>  

    (1) description=<text> 
    (2) wanted=<number>
    (3) <expiration-date>
    (4) item=<itemnum>
    (5) notearray=<note1> notearray=<note2> notearray=<note3>
   
   For action             Required    Optional
       Confirm Purchase   2           1
       Confirm Release    2           1
       Confirm Entry      1,2,3
       Submit Suggestion  1,2,3
       Submit Edited Item 1,2,4       3
       Release Purchase   4

 <expiration-date> => expires_type=[Never|Christmas|In A Year]
                   |  expires_type=Date Selected
                        month_expires=[0|1|2|3|4|5|6|7|8|9|10|11]
                        day_expires=[1|2|3| ... |29|30|31]
                        year_expires=<year>

=head1 DESCRIPTION

=head2 Overview

A wishlist is a record of a set of possible gifts that a wishlist owner
"wishes" for, or that someone else suggests for them, and purchases of 
those gifts by various people. 
The tool allows people who may not even know each other, to cooperate
in such gift giving without running the risk of buying duplicate gifts
while still keeping specific information secret from one another.

Before writing this tool for my family and my wife's, we used our
respective mothers as a trusted keeper of the information, but that did not
coordinate across families, and was a rather complex task for our mothers.

The program paints a number of "pages" each of which is composed of several
forms and other information. The pages ore selected by the "action" parameter
which is set in each form. Some of the actions modify the wishlist file.

The following actions modify the wishlist file:

 Delete
 Confirm Purchase
 Confirm Release
 Submit Edited Item
 Confirm Entry

=head2 Web Page State Diagram:

 >--------------------------------------------->Delete------------------->|
 |                                 '----------->Release Purchase--------->|
 |-->Modify Purchase*--------------|----------->Submit Modification------>|
 |                                 V                                      |
 |-->Buy Item*-------------------------------->{Confirm Purchase}-------->|
 |-->Release Item*---------------------------->{Confirm Release }-------->|
 |-->Edit*----------------------------------|                             |
 |                                          '->{Submit Edited Item}------>|
 |-->Add Suggestion---->Submit Suggestion----->{Confirm Entry     }------>|
 |                  ^                     |                               |
 |                  |                     |                               |
 |                  '---Change Entry<-----'                               |
 |                                                                        v
 '------------------------------------------------------------------------'
____________________________________________________________________________

 >--------------------------------------------->delete_item()------------>|
 |                                 '----------->submit_purchase_release-->|
 |-->paint_release_form()----------|----------->???????????????????------>|
 |                                 |                                      |
 |-->paint_purchase_form()---|     V                                      |
 |                           |----------------->confirm_purch_or_rel()--->|
 |-->paint_purchase_form()---|                                            |
 |-->paint_item_change_form()-----------|                                 |
 |                                      |-->submit_edit_or_suggestion()-->|
 |-->paint_s_form()--->paint_s_conf()-->|                                 |
 |                  ^                   |                                 |
 |                  |                   |                                 |
 |                  '--paint_s_form()<--'                                 |
 |                                                                        v
 '------------------------------------------------------------------------'

=head1 ENVIRONMENT

REMOTE_USER - the login ID of the individual running the program.

=head1 DIAGNOSTICS

=over 4

=item "You are not properly logged in"

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

=item 16Jan2003 Suggestion does not show up the first time

When you first create a suggestion and run it through 
submit_edit_or_suggestion, it doesn't show up on the screen. When
you refresh the screen, it shows up.
Ed noted this on his 19Jan2003 email, as well.

=item Expiration date inconsistencies

Shows obsolete items to the list owner.
Doesn't default an expiration date.
Named dates (like Christmas) are not implemented.

=item 2Feb2003 Problems with form starting and ending

In order to have the "Choose style for pages" menu work, it has to be in
the same form as the one where the "submit" button is pressed. That means either
the whole page must be a single form, or that "Choose style for pages" needs to
have all the hidden attributes needed, so that you can change the style and 
return to the same screen. That may be able to be done using the "last-action"
from the "Redraw the screen" area, and have the Choose style be in the footer.
Let's investigate that. 

This seems to work, but the style value is not being rewritten for the
"Modify Purchase" menu, and its actually being updated several times for the 
"Viewing Wishlist" screen.  We need to set the style back to the first style in 
each case. 

Now, make it one form for the trailer, (including the information in earlier
screen elements, while it may be a separate form for the screens that allow 
choosing an action out of a table.

This may mean separate footer which close the form, and footers which don't.

Regularize opening and closing the forms.

=item 3Feb2003 Extra values for parameters

I'm getting extra values for parameter like style= and owner= because it is
treating them as arrays when I put them in hidden lists. I need to overcome 
that with -force. 

=back

=head1 CHANGES FROM PREVIOUS VERSIONS

=over 4

=item Expiration date

Allow a suggester (particularly the owner) to put an expiration date on the
item, after which time he is free to buy it himself.

=item Edit or Undo Purchases

Allow a purchaser to renege on a purchase - putting it back in the list as
available - and to add to their note.

=back

=head1 REFACTORINGS

=head1 SUGGESTED ENHANCEMENTS

=over 4

=item Mark gifts as Received

Allow the giver or perhaps the recipient of a gift to mark it as received and
thus no longer on the list.

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

=item URLs in suggestions

=item Public Suggestions

Allow suggestions to be marked as visible for owner

=item E-Mail Notifications

=back 

=head1 FILES

=head1 SEE ALSO

multilist.pl, ibought.pl, Christmas::Wishlist.pm, 
Christmas::Wishlist::WishItem.pm 

=head1 AUTHOR

Michael G. Birdsall

=head1 COPYRIGHT

Copyright (c) 2002,2003,  Michael G. Birdsall. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

