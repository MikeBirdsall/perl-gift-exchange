#!/usr/local/bin/perl -w
use Test::More 'no_plan';
use Christmas::Wishlist::WishItem;

my %item1 = (
    for         => 'test1',
    by          => 'test1',
    requested   => '1',
    description => 'The very first item',
    ident       => '905',
);

my %item2 = (
    for         => 'test1',
    by          => 'test1',
    description => 'The very first item',
    ident       => '905',
);

can_ok('Christmas::Wishlist::WishItem', qw(new for requested description ident buy wanted));
my $wi = Christmas::Wishlist::WishItem->new(%item1);

# Create a new item; check that it is correctly defined
ok( defined $wi, "new(%item1)" );
ok( $wi->isa('Christmas::Wishlist::WishItem'), "and it's the right class" );

is( $wi->for(),                    $item1{for},         "for the right person" );
is( $wi->for('test3'),             'test3',             "modify the for value");
is( $wi->for(),                    'test3',             "and it is permanaently changed");
is( $wi->requested(),              $item1{requested},   "the correct number" );
is( $wi->requested(2),             2,                   "modified" );
is( $wi->requested(),              2,                   "permanently" );
is( $wi->description(),            $item1{description}, "the correct description" );
is( $wi->description("A new one"), "A new one",         "modified" );
is( $wi->description(),            "A new one",         "permanently" );
is( $wi->ident(),                  '905',               "the correct identifier" );
is( $wi->ident(400),               '905',               "doesn't change it" );
is( $wi->ident(),                  '905',               "at all" );

# Create a new item with defaultes requested number
$wi = Christmas::Wishlist::WishItem->new(%item2);

ok( defined $wi,                   "new(%item2)");
ok( $wi->isa('Christmas::Wishlist::WishItem'),          "and it's the right class" );
is( $wi->requested(),              "any",               "defaulted requested to any" );

# Test purchasing

$wi = Christmas::Wishlist::WishItem->new(
    for => 'test1',
    by  => 'test2',
    requested => 1, 
    description => 'Gift we only want one of',
);


ok( defined $wi, "new item to buy" );
ok( $wi->isa('Christmas::Wishlist::WishItem'), "and it's the right class" );

is ($wi->requested(), 1, "we requested 1");
is ($wi->wanted(),  1, "we still want 1");
ok (!$wi->buy(2), "we cannot buy 2");
is ($wi->buy(1), 1, "but we can buy 1");
is ($wi->requested(), 1, "1 is still requested");
is ($wi->wanted(), 0, "but now none are wanted");
ok (!$wi->buy(1), "so we cannot buy it");


