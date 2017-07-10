#!/usr/local/bin/perl
# File: userlist.pl

# This CGI-BIN perl script is the standard user script for group Chrismas Gift lists.
# It allows users to create new gift lists, and to view whom they have drawn
use CGI ':standard',':html3';
use CGI::Carp;
use Fcntl;

$debug = 0;

# Set the initial data
$user = param('user') || remote_user();
$title = 'Christmas List Menu for '.ucfirst $user;
my $repos =  ( $ENV{HOME} || $ENV{LOGDIR} || ( getpwuid($>) )[7] ) . "/wishlistdata/family";

# Read person file. Further processing is dependent on user definition.

print header,
    start_html($title),
    h1($title),
    hidden(-name=>'user', -value=>"$user");

read_person($user);

# Make sure that group is determined or chosen. 
# Set group doesn't always return
$group = param('group') || set_group();
    
if ($debug) {
    foreach $name ( param() ) { 
        print "The value for $name is ", param($name), br;
    }
}


$_ = param('action');

CASE: {
    /^check list/i        and do {check_list(); last CASE; };
    /^create giftlist/i   and do {define_giftlist(); last CASE; };
    # default
}
print_menu($user, $group);

print end_html;

#
# The members routine returns all the members of a group,
# which it determines by reading the group file. 
#
# Parameters:
#      $group_name - A string containing the name of the group.
#                     Group files are defined as $repos/group.$group_name
# Returns:
#      An array containing a string for each member of the group
#
# Forms or affect on screen:
#      None, except for error messages
#
#
sub members {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $group_name = shift;
    my @group = ();

    if ($debug) {print "Reading the $group_name File.", br();}
    open FAMILY, "<$repos/group.$group_name" or die ("Cannot open $group_name file.");
    while (<FAMILY>) {
        chomp;
        s/#.*//;              # Ignore comments
        s/^\s+//;             # Ignore leading spaces
        next unless length;   # Ignore blank lines
        push @group, $_;
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
    return @group;
}
#
# Routine to create a giftlist for a group and write it to disk
#
# Parameters: 
#      $name - the basename of the new giftlist
#      $group - The basename of the group to put it in
#
# Returns:
#      None
#
# Forms and affects on screen:
#      Debug messages only
#
#      The routine gets all the needed information
#         (All people in group and hash of those excluded)
#      Generates a permutation of the people, and checks to
#      See if it fits the Christmas List rules
#         (No one draws those on exclude list)
#      Prints the list to the file 
#           The form of the file is:
#                 # Header Line
#                 FromID1 ToID1
#                 FromID2 ToID2
#                   ...
sub create_giftlist {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my ($name, $group) = @_;

    # open the file, checking that it does not already exist
    $listfile = "$repos/list.$group.$name";
    if ($debug) {print h2("Opening file $listfile using", O_WRONLY|O_EXCL|O_CREAT) }
    if (!sysopen(LIST, "$listfile", O_WRONLY|O_EXCL|O_CREAT)) {
        print h2("Could not create giftlist $name, $!");
        return;
    }

    # Read in all the person files and store those excluded in the hash
    # %exclude
    @group = members $group;
    if($debug) {print "Members of $group are @group", br;};
    foreach my $person (@group) {
        if($debug) {print "Reading the $person file", br};
        ($exclude{$person}) = attributes_for($person, 'exclude');
    }


    if ($debug) {print "Creating a permutation of @group", br(); };
    my $num_permutations = factorial(scalar @group);

    # Choose random purmutations until you hit a legal one
    # There is a problem if there are no legal permutations 
    # Don't allow more than 1000 tries.

    PERM: until ($found) {
        # Generate a random Permutation
        if (++$tries > 20000) {
            print ("Could not form a legal list for $group.", br);
            close(LIST);
            print ("Deleting $listfile", br);
            unlink($listfile);
            last PERM;
        }
        $i = int rand($num_permutations);
        my @permutation = @group[n2perm($i, $#group)];

        # Check legality; not self; not exclude
        for (my $j=0; $j <= $#group; $j++) {
            # Create the list of people to be excluded
            my %toexclude = map {$_, 1} split(" ",$exclude{$group[$j]});
            if ($toexclude{$permutation[$j]}) {
                if ($debug) {print("$tries: Retrying draw - $group[$j] drew $permutation[$j].", br)} 
            }
            next PERM if $toexclude{$permutation[$j]};
        }

        $found=1;
        # found a legal permutation; write it out
        for (my $j=0; $j <= $#group; $j++) {
            print LIST "$group[$j] $permutation[$j]\n";
        }
        close(LIST);
        print ("After $tries tries.", br);
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}

#
# This starts a section of Routines used to create permutations.
# Utility function: factorial with memorizing
BEGIN {
    my @fact = (1);
    sub factorial($) {
        my $n = shift;
        return $fact[$n] if defined $fact[$n];
        $fact[$n] = $n * factorial($n-1);
    }
}



# n2pat($N, $len) : produce the $Nth pattern of length $len
sub n2pat {
    my $i    = 1;
    my $N    = shift;
    my $len  = shift;
    my @pat;
    while ($i <= $len +1) { 
        push @pat, $N % $i;
        $N = int($N/$i);
        $i++;
    }
    return @pat;
}




# pat2perm(@pat) : turn pattern returned by n2pat() into 
# permutation of integers. XX: splice is already O(N)
sub pat2perm {
    my @pat    = @_;
    my @source  = (0 .. $#pat);
    my @perm;
    push @perm, splice(@source, (pop @pat), 1) while @pat;
    return @perm;
}




# n2perm($N, $len) : generate the Nth permutation of S objects
sub n2perm {
    pat2perm(n2pat(@_));
}

#
# Routine to create a form asking for the name of the giftlist
# and to create the list when the name is available
sub define_giftlist {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if(!param('newlist')) {
        print
            start_form(),
            textfield(-name=>'newlist', -size=>30),
            submit(-name=>'action', -value=>'Create Giftlist'),
            hidden(-name=>'group'),
            endform(), br;
    } else {
        create_giftlist(param('newlist'), $group);
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
#
# Routine to print a message indicating who this user drew from the
# selected list.
#
# Parameters: 
#      None
#
# Returns:
#      None
#
# Forms and affects on screen:
#      Prints a message indicating who the user drew.
#
sub check_list {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    # Read in the list chosen, and print the one whose giver is the user
    $list = param('list');
    ($label = $list) =~ s[$repos/list\.][];
    open LIST, "<$list" or print p("I can't open the list -$list-");
    while (<LIST>) { 
        chomp;
        s/#.*//;
        s/^\s+//;
        next unless length;
        ($from, $to) = split;
        if ($from eq $user) { 
            ($name) = attributes_for($to, 'name');
            print "You drew $name from $label";
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
            return;
        }
    }
    print "You were apparently left out of the drawing.", br;
    if ($debug) {print h2("Leaving ", (caller(0))[3])}

}
#
# Routine to return the string indicating what group this user is a member of
# or which one the user selected, if they are a member of more than one.
#
# Parameters: 
#      None
#
# Returns:
#      String with value of group
#
# Forms and affects on screen:
#      If the user is a member of more than one group, and has not yet picked
#      which one they are working with, creates a form to ask.
#
# Currently, the routine depends on the fact that read_person has already read
# the users file, and set the values of $UserValues. This should be changed to
# call a routine and get the value. That routine can read the file if necessary.
#
sub set_group {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if ( (@groups = split(/\s+/,$UserValues{group})) <= 0){
        print p("You are not in a group, so I don't know what to do with you.");
        print "Gift Group value is $UserValues{group}";
        print @groups;
        if ($debug) {print h2("Leaving ", (caller(0))[3])}
        print end_html();
        exit;
    }
    elsif (scalar(@groups) == 1) {
        if ($debug) { print p("Setting the group to $UserValues{group}") };
        hidden(-name=>'group',-value=>$UserValues{group});
        if ($debug) { print p("Set the group to ", param('group'))};
        $group = $UserValues{group};
        if ($debug) {print h2("Leaving ", (caller(0))[3])}
        return $group;
    }
    elsif (scalar(@groups) > 1) {
        print startform(),
            radio_group(-name=>'group',
                        -values=>\@groups,
            ),
            br(),
            submit(-name=>'action', -value=>'Choose Gift Group'),
            hidden(-name=>'user', -value=>"$user"),
            reset(),
            endform();
            if ($debug) {print h2("Leaving ", (caller(0))[3])}
            print end_html();
        exit;
    }
    else
    {
        print p("You are in an illegal number of groups, so I don't know what to do with you.");
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
        exit;
    }
}
#
# Routine to print the common menu for users 
#
sub print_menu {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my ($user, $group) = @_;
    if ($debug) { print "Presenting list for $group", br};
    foreach $list (glob("$repos/list.$group.*")) {
        if ($debug) {print "Found $list", br};
        ($lists{$list} = $list) =~ s[$repos/list\.][];
        if ($debug) {print "Found $lists{$list}", br};
    }
    if(scalar(%lists)) {
        print h2("Query or Create a List.");
        print 
            startform(), 
            hidden(-name=>'user', -value=>"$user"),
            hidden(-name=>'group'),
            radio_group(-name=>'list',
                        -linebreak=>1,
                        -values=>[(keys %lists)],
                        -labels=>\%lists,
                        ),
            submit(-name=>'action', -value=>'Check List'), 
            submit(-name=>'action', -value=>'Create Giftlist'), 
            endform();
            if ($debug) {print h2("Leaving ", (caller(0))[3])}
            print br;
    }
    else
    {
        print h2("Query or Create a List.");
        print 
            startform(), 
            hidden(-name=>'user', -value=>"$user"),
            hidden(-name=>'group'),
            submit(-name=>'action', -value=>'Create Giftlist'), 
            endform();
            if ($debug) {print h2("Leaving ", (caller(0))[3])}
            print br;
        if ($debug) {print h2("Leaving ", (caller(0))[3])}
    }
}
#
#
sub read_person {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $person = shift;

    open PERSON, "$repos/person.$person" or print "I don't have any information on $person",br;
    while (<PERSON>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        next unless length;
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $UserValues{$var} = $value;
        if ($debug) { print "Put ", $value, " into $var. $UserValues{$var}", br };
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
#
# Routine to read any needed attributes for a particular user.
# The routine should cache any attributes it does get, and return them
# without reading the file.
#
sub attributes_for {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my ($person, @atts) = @_;
    my %UserValues = ();
    my @response;

    open PERSON, "$repos/person.$person" or print "I don't have any information on $person",br;
    while (<PERSON>) {
        chomp;
        s/#.*//;
        s/^\s+//;
        next unless length;
        my ($var, $value) = split(/\s*=\s*/, $_, 2);
        $temp = $UserValues{$var} = $value;
        if ($debug) { print "Put ", $value, " into $var. $temp", br(); };
    }
    foreach (@atts) {
        unshift @response, $UserValues{$_};
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
    return @response;
}
