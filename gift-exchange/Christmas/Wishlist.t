#!/usr/local/bin/perl -w
use Test::More 'no_plan';
use Christmas::Wishlist;

use strict;

# Test setup; Set all the values needed to set it up
my $repository =
  ( $ENV{HOME} || $ENV{LOGDIR} || ( getpwuid($>) )[7] ) . "/wishlisttestdata/";
my @testfiles = qw/wishlist.test1 wishlist.test2/;

my @good_items = (
    { by => "test1", requested => 1,     description => "First test item" },
    { by => "test1", requested => 5,     description => "Second test item" },
    { by => "test1", requested => 1,     description => "Third test item" },
    { by => "test1", requested => "any", description => "Fourth test item" },
    { by => "test1", requested => 1000,  description => "Fifth test item" },
);

my %single_item = (
    by          => "test1",
    requested      => 1,
    description => "Desire only one item"
);

# Create the directory and needed files.
if ( -e $repository ) {
    if ( -d _ ) {

        # Directory already exists; remove the testfiles;
        unlink( map { $repository . $_ } @testfiles );
    } else {
        die (
"There is a file blocking the creation of the test directory $repository\n"
        );
    }
} else {
    mkdir( $repository, 0777 )
      or die "Could not create directory $repository\n";
}

# Set up the repository
is( Christmas::Wishlist->set_repository($repository),
    $repository, "set_repository($repository)" );

# Try to open a non-existant wishlist
my $wl = Christmas::Wishlist->new( create=>0, userid => "test1" );
ok( !defined $wl, "Try to open non-existent wishlist" );

# Create a wishlist
$wl = Christmas::Wishlist->new( create=>1, userid => "test1" );
ok( defined $wl, "Created new Wishlist" );
ok( $wl->isa('Christmas::Wishlist'), "and it's the right class" );

# ok, I'm testing an internal, implementation detail 
#    - where the files are created
# maybe I'll think of a better way to test this later 
#    - perhaps a method which returns the file name?
ok( ( -e "$repository/wishlist.test1" ), "File created" );
ok( ( -f _ ), "File normal" );
ok( ( -r _ ), "File accessible" );
ok( ( -w _ ), "File writable" );

my $fileage = ( -M _ );
sleep 1;    # Make sure the file age is changed.

# Reusing the wishlist name should close the wishlist
$wl = Christmas::Wishlist->new( create=>1, userid => "test2" );
ok( $fileage > ( -M "$repository/wishlist.test1" ), "File updated" );

# Open the existing wishlist
$wl = Christmas::Wishlist->new( create=> 0, userid => "test1" );
ok( defined $wl, "retrieve a stored wishlist" );
ok( $wl->isa('Christmas::Wishlist'), "and it's the right class" );

# Add an item to the wishlist 
my $new_item = $wl->suggest( %{ $good_items[0] } );
ok( defined $new_item, "new item in wishlist" );
is(
    $wl->item($new_item)->by(),
    $good_items[0]{"by"},
    "retrieve *by* as created"
);
is(
    $wl->item($new_item)->requested(),
    $good_items[0]{"requested"},
    "retrieve *requested* as created"
);
is(
    $wl->item($new_item)->description(),
    $good_items[0]{"description"},
    "retrieve *description* correctly"
);

# Retrieve the items - should only be one
my @all_items = $wl->get_items();
is( scalar(@all_items), 1, "retrieve single item" );

# Delete only item
ok(
    $wl->remove(
        itemnum     => 1,
        description => $good_items[0]{description},
        how_many    => $good_items[0]{requested},
        by          => "test1",
    ),
    "Deleted the only item",
);

ok( !defined $wl->item(1), "item removed" );

# Create a set of items
foreach my $item (@good_items) {
    $wl->suggest( %{$item} );
}

# Buy an item with 1 left
ok( $new_item = $wl->suggest(%single_item), "Create an item with 1 requested" );
ok(
    $wl->purchase(
        itemnum     => $new_item,
        description => $single_item{description},
        how_many    => 1,
        by => "test3",
    ),
    "Buying an item with 1 wanted"
);
ok(
    !$wl->purchase(
        itemnum     => $new_item,
        description => $single_item{description},
        how_many    => 1,
        by          => "test3"
    ),
    "Buying an item when 0 wanted"
);

# Get the last modified time, which should be close to the present 
ok( $wl->last_update() > time() - 10, "Modified in last 10 seconds");
ok( $wl->last_update() <= time(), "Not in the future.");

# Modify an item

# Get a list of all items
@all_items = $wl->get_items();


