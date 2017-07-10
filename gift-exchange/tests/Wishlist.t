#!/usr/local/bin/perl -w
use Test::More 'no_plan';
use Christmas::Wishlist;

# Test setup; Set all the values needed to set it up
my $repository = ($ENV{HOME} || $ENV{LOGDIR} || (genpwuid($>))[7]) . "/wishlisttestdata/";
my @testfiles = qw/wishlist.test1/;

# Create the directory and needed files.
if(-e $repository) {
    if (-d _) {
        # Directory already exists; remove the testfiles;
        unlink(map {$repository . $_} @testfiles); 
    } else {
        die ("There is a file blocking the creation of the test directory $repository\n");
    }
} else {
    mkdir($repository, 0777) or die "Could not create directory $repository\n"; 
}

# Set up the repository
TODO: {
    local $TODO = 'set_repository not yet implemented';

    ok( Christmas::Wishlist->set_repository($repository));
}

# Try to open a non-existant wishlist
my $wl = Christmas::Wishlist->open(userid=>"test1");
ok( defined $wl,           "new(mbirdsall)"                        );
ok( $wl->isa('Christmas::Wishlist'),       "and it's the right class"); 

# Create a wishlist

# Open the existing wishlist

# Close the wishlist

# Add an item to the wishlist 

# Delete an item

# Buy an item

# Modify an item

# Get a list of all items

# Get a list of all still desired items

