#!/usr/local/bin/perl -w
use Test::More 'no_plan';
use Christmas::Wishlist::WishItem;

my %item1 = (
            for=>'test1', 
            creator=>'test1', 
            wanted=>'1', 
            description=>'The very first item',
            );

my $wi = Christmas::Wishlist::WishItem->new(%item1);

# Create a new item; check that it is correctly defined
ok( defined $wi,                                     "new(%item1)"             );
ok( $wi->isa('Christmas::Wishlist::WishItem'),       "and it's the right class"); 
is( $wi->for(), $item1{for},                         "for the right person"    );
is( $wi->wanted(), $item1{wanted},                    "the correct number"      );
is( $wi->discription(), $item1{description},          "the correct number"      );


