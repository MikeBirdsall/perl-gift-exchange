#!/usr/local/bin/perl
# File: picklist.pl
# This CGI-BIN perl script provides admin functions 
# for a set of group Chrismas Gift lists.
use CGI ':standard',':html3';
use CGI::Carp;
use Fcntl;

$debug = 0;

# Set the initial data
$user = param('user') || remote_user();
$title = 'Administration Menus for Gift Lists';
my $repos =  ( $ENV{HOME} || $ENV{LOGDIR} || ( getpwuid($>) )[7] ) . "/wishlistdata/family";

# Read person file. Further processing is dependent on user definition.

print header,
    start_html($title),
    h1($title),
    hidden(-name=>'user', -value=>"$user");

# Check that the person has admin rights
($admin) = attributes_for($user, 'admin');
if ($admin) {

    #read_person($user);

    if ($debug) {
        foreach $name ( param() ) { 
            print "The value for $name is ", param($name), br;
        }
    }


    if ($debug) {
        print "Doing action ", param('action'), br;
    }

    $_ = param('action');

    CASE: {
        /^show member/i       and do {show_member(); last CASE; };
        /^add member/i        and do {add_member(); last CASE; };
        /^modify member/i     and do {modify_member(); last CASE; };
        /^delete member/i     and do {delete_member(); last CASE; };

        /^show giftlist/i     and do {show_giftlist(); last CASE; };
        /^create giftlist/i   and do {define_giftlist(); last CASE; };
        /^remove giftlist/i   and do {remove_giftlist(); last CASE; };
        /^display giftlist/i  and do {display_giftlist(); last CASE; };

        /^show group/i       and do {show_group(); last CASE; };
        /^create group/i     and do {create_group(); last CASE; };
        /^remove group/i     and do {remove_group(); last CASE; };
        # default
    }

    print_menu();
} 
else
{
    print h1("You are not an administrator.");
}
print end_html;

# Show Group
# Display all of the groups defined
sub show_group {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my @groups = glob("data/group.*");
    grep {s[data/group.][]} @groups;
    print h2("Available Groups are:");
    print ul(
        li(\@groups)
    );
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
# Create Group
# Allow the user to select any set of existing people
# Create a group file with those people in it
# Add the group to the end of the Group parameter for those people
sub create_group {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if(!param('userid')){
        # First Pass, choose members for this group
        # by printing the form to select them
        @userid = choose_members_and_name("Create Gift Group"); # doesn't actually set @userid
    } else {
        # Second Pass, members and name are selected
        @userid = param('userid');
        $group = param('group_name');

        if($debug) {print h2("Creating group -$group_name- with members @userid")};

        # Create the group file
        open FAMILY, ">>data/group.$group_name";
        foreach my $person(@userid) {
            print FAMILY "$person\n";
        }
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}

# Remove Group
# This shouldn't be used very often, but perhaps I may wish to remove a test group
sub remove_group {
# Pick the group
# Remove the group name from any members
# Remove the group file
# Remove any list files

    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if(!param('group_name')) {
        choose_group('Remove Gift Group');
    } else {
        # Second Pass
        $group_name = param('group_name');

        # Remove the group name from any members
        my @members = `grep -l $group_name data/person.*`;
        if($debug) {print h1("Removing @members from $group_name.")}
        foreach $member (@members) {
            open PERSON, "+< $member"              or die "Opening: $!";
            @lines = <PERSON>;
            foreach (@lines) {
                s[^(group.*)$group_name(.*)$][$1$2];
            }

            seek(PERSON,0,0)                      or die "Seeking: $!";
            print PERSON @ARRAY                   or die "Printing: $!";
            truncate(PERSON,tell(PERSON))         or die "Truncating: $!";
            close(PERSON)                         or die "Closing: $!";
        }

        # Remove the group file
        unlink("data/group.$group_name");

        # Remove any list files
        my @lists = glob("data/list.$group_name.*");
        unlink @lists;
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
sub members {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $group_name = shift;
    my @group = ();
    local $_;

    if ($debug) {print "Reading the $group_name File.", br();}
    open FAMILY, "<data/group.$group_name" or die ("Cannot open $group_name file.");
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
# Routine to Delete a particular person; not specific to group
sub delete_member {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if(!param('userid')){
        # First Pass, the person to delete is not yet selected
        # Print the form to select them
        choose_member("Delete Member");
    }
    else
    {
        # Second Pass, Delete User param('userid')

        #   Check if they are in any gift lists - problems there
        $userid = param('userid');
        @problems = `grep -l $userid data/list.$group.*`;
        grep {s[data/list.][ ]} @problems;
        print("$userid is in the giftlist(s) @problems", br) if (scalar @problems);

        #   Remove them from group files
        foreach $fam (`grep -l $userid data/group.*`) {
            $fam =~ s/\s+//;
            `grep -v $userid $fam > $fam.temp; mv $fam.temp $fam`;
        }
        #   Delete the person file (or rename it?)
        unlink "data/person.$userid";
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
# Routine to dump a giftlist to the web page
#
sub display_giftlist {
    if ($debug) {print h2("Entering ", (caller(0))[3])}

    if(param('list')) {
        my $list = param('list');
        print h2("Displaying giftlist $list");
        open LIST, $list;
        while (<LIST>) {
            s/ / drew /;
            print;
            print br;
        }
    }
    else 
    {
        my @lists = glob("data/list.*");
        if(scalar(@lists)) {
            print h2("Pick a list to remove.");
            print 
                startform(), 
                hidden(-name=>'user', -value=>"$user"),
                hidden(-name=>'group'),
                radio_group(-name=>'list',
                            -linebreak=>1,
                        -value=>\@lists,
                        ),
            submit(-name=>'action', -value=>'Display Giftlist'), 
            endform(), 
            br;
        }
        else
        {
            print h2("There are no lists to Display"); 
        }
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
    

# Routine to create a giftlist for a group and write it to disk
#
#      The routine gets all the needed information
#         (All people in group and hash of their spouses)
#      Generates a permutation of the people, and checks to
#      See if it fits the Christmas List rules
#         (No one draws themselves or their spouse)
#         (New rule: no one draws anyone on their exclude list)
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
    if ($debug) {print h2("Opening file data/list.$group.$name using", O_WRONLY|O_EXCL|O_CREAT) }
    if (!sysopen(LIST, "data/list.$group.$name", O_WRONLY|O_EXCL|O_CREAT)) {
        print h2("Could not create giftlist $name, $!");
        return;
    }

    # Read in all the person files and store the spouse in the hash %spouse
    @group = members $group;
    if($debug) {print "Members of $group are @group", br;};
    foreach my $person (@group) {
        if($debug) {print "Reading the $person file", br};
        ($spouse{$person}) = attributes_for($person, 'spouse');
        ($exclude{$person}) = attributes_for($person, 'exclude');
    }


    if ($debug) {print "Creating a permutation of @group", br(); };
    my $num_permutations = factorial(scalar @group);

    # Choose random purmutations until you hit a legal one
    # There is a problem if there are no legal permutations 
    # Don't allow more than 50 tries.

    PERM: until ($found) {
        # Generate a random Permutation
        $i = int rand($num_permutations);
        if (++$tries > 50) {
            print "Could not form a legal list for $group.";
            last PERM;
        }
        my @permutation = @group[n2perm($i, $#group)];

        # Check legality; not self; not spouse
        for (my $j=0; $j <= $#group; $j++) {
            # Create the list of people to be excluded
            my %toexclude = map {$_, 1} split(" ",$exclude{$group[$j]});
            next PERM if $toexclude{$permutation[$j]};
        }

        $found=1;
        # found a legal permutation; write it out
        for (my $j=0; $j <= $#group; $j++) {
            print LIST "$group[$j] $permutation[$j]\n";
        }
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}

# This starts a section of Routines used to create permutations.
#Utility function: factorial with memorizing
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

sub remove_giftlist {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if(param('list')) {
        my @list = param('list');
        print h2("Removing giftlist @list");
        unlink @list;
    }
    else 
    {
        my @lists = glob("data/list.*");
        if(scalar(@lists)) {
            print h2("Pick a list to remove.");
            print 
                startform(), 
                hidden(-name=>'user', -value=>"$user"),
                hidden(-name=>'group'),
                checkbox_group(-name=>'list',
                            -linebreak=>1,
                        -value=>\@lists,
                        ),
            submit(-name=>'action', -value=>'Remove Giftlist'), 
            endform(), 
            br;
        }
        else
        {
            print h2("There are no lists to remove.");
        }
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
#
# Show Giftlist
sub show_giftlist {
    my @lists = glob("data/list.*");
    grep {s[data/list.][]} @lists;
    if(scalar(@lists)) {
        print ul( li(\@lists));
    }
    else
    {
        print h2("There are no Giftlists.");
    }
}
sub define_giftlist {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if (!param('group_name')) {
        print h2("Pick the Gift Group for the Giftlist:");
        choose_group('Create Giftlist');
    } 
    elsif (param('list')) {
        create_giftlist(param('list'), param('group_name'));
    } else {
        print
            start_form(),
            textfield(-name=>'list', -size=>50),
            submit(-name=>'action', -value=>'Create Giftlist'),
            hidden(-name=>'group'),
            hidden(-name=>'group_name'),
            endform(), br;
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
sub create_person_file {
    # Write the person file
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my %attrib = ( userid          => 'anonymous',   # default
                   @_,
                );
     
    open PERSON, ">data/person.$attrib{userid}" or die("Cannot create the person.$userid file");
    print PERSON  "# Mgb Xmas list utility\n";
    print PERSON  "# Person Definition File V1.0\n";
    foreach $key (keys %attrib) {
        next if ($key eq userid);
        next if (!$attrib{$key});
        print h3("Writing $key = $attrib{$key}");
        print PERSON $key, "=$attrib{$key}\n";
    }
    close PERSON;
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
# Routine to create a form to choose a group
sub choose_group {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $actionvalue = shift;
    my @groups = glob("data/group.*");
    grep {s[data/group.][]} @groups;
    print
        startform(),
        hidden(-name=>'user' -value=>"$user"),
        hidden(-name=>'group'),
        radio_group(-name=>'group_name',
                    -linebreak=>1,
                    -value=>\@groups,
                    ),
        submit(-name=>'action', -value=>$actionvalue),
        endform(), br;
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}

sub choose_members_and_name {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $actionvalue = shift;
    my @members = glob("data/person.*");
    grep {s[data/person.][]} @members;
    if ($debug) {print h2("Choosing members from @members.")};
    print 
        startform(),
        hidden(-name=>'user', -value=>"$user"),
        hidden(-name=>'group');
    if(wantarray){
        print checkbox_group(-name=>'userid',
                    -linebreak=>1,
                    -value=>\@members,
                    -cols=>3,
                    ),
    } else {
        print radio_group(-name=>'userid',
                    -linebreak=>1,
                    -value=>\@members,
                    -cols=>3,
                    ),
    }
    print
        textfield(-name=>'group_name', -size=>30),
        submit(-name=>'action', -value=>$actionvalue), 
        endform(), br;
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
# Routine to create a form to choose a member or members
# if called as scalar, uses radio_group; 
# if called as array, uses checkbox_group
sub choose_member {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $actionvalue = shift;
    my @members = glob("data/person.*");
    grep {s[data/person.][]} @members;
    print 
        startform(),
        hidden(-name=>'user', -value=>"$user"),
        hidden(-name=>'group');
    if(wantarray){
        print checkbox_group(-name=>'userid',
                    -linebreak=>1,
                    -value=>\@members,
                    -cols=>3,
                    ),
    } else {
        print radio_group(-name=>'userid',
                    -linebreak=>1,
                    -value=>\@members,
                    -cols=>3,
                    ),
    }
    print
        submit(-name=>'action', -value=>$actionvalue), 
        endform(), br;
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
sub modify_member {
    # Just like adding a member, except that you read defaults, and don't add to group
    # Print a form to choose a member
    local $_;
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    if(!param('userid')){
        choose_member("Modify Member");
    }
    elsif (!param('picked')){
        $userid =param('userid');
        open PERSON, "<data/person.$userid" or die("Cannot access the person.$userid file");
        while (<PERSON>) {
            chomp;
            s/#.*//;
            s/^\s+//;
            next unless length;
            my ($var, $value) = split(/\s*=\s*/, $_, 2);
            param(-name=>$var, -value=>$value);
        }
        print
            start_form(),
            table({-border=>''},
            caption(strong('Enter Information')),
            Tr({-align=>LEFT},
            [
            th('UserID').td(textfield(-name=>'userid', -size=>50)),
            th('Name').td(textfield(-name=>'name',   -size=>50)),
            th('Spouse').td(textfield(-name=>'spouse', -size=>50)),
            th('Exclude').td(textfield(-name=>'exclude', -size=>50)),
            ]
            )),
            submit(-name=>'action', -value=>'Modify Member'),
            hidden(-name=>'picked', -value=>1),
            hidden(-name=>'admin'),
            hidden(-name=>'group'),
            end_form();
    }
    else
    {
    # need to find a way to write out the groups for a user
        create_person_file(
            userid=>param('userid'), 
            name=>param('name'), 
            spouse=>param('spouse'), 
            group=>param('group'),
            admin=>param('admin'),
            exclude=>param('exclude'),
        );
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}

#
# Add member
# Routine which prints out the current members
sub show_member {
    if ($debug) {print h2("Entering ", (caller(0))[3]), "\n";}
    my @members = glob("data/person.*");
    local $_;
    grep {s[data/person.][]} @members;
    my @list = map {join ("-", $_, attributes_for($_, 'name'))} @members;
    print ul( li(\@list));
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
sub add_member {
    # Subroutine to get all the information to add a member to a group
    # Assuming we are creating a completely new person
    # need to get user-id Name, Spouse, and Group
    if ($debug) {print h2("Entering ", (caller(0))[3]), "\n";}
    my @groups = glob("data/group.*");
    if ($debug) {print "@groups\n";}
    grep {s[data/group.][]} @groups;
    if ($debug) {print "@groups\n";}
    if(!param('userid')){
        print
            start_form(),
            table({-border=>''},
            caption(strong('Enter Information')),
            Tr({-align=>LEFT},
            [
            th('UserID').td(textfield(-name=>'userid', -size=>50)),
            th('Name').td(textfield(-name=>'name',   -size=>50)),
            th('Spouse').td(textfield(-name=>'spouse', -size=>50)),
            th('Exclude').td(textfield(-name=>'exclude', -size=>50)),
            ]
            )),
            checkbox_group(-name=>'group',
                        -linebreak=>1,
                        -value=>\@groups,
                        ),
            submit(-name=>'action', -value=>'Add Member'),
            end_form();
    }
    else
    {
        # Write the group and person files
        $userid = param('userid');
        @group = param('group');
        foreach $group (@group) {
            open FAMILY, ">>data/group.$group" or die("Cannot write out to group.$group");
                print FAMILY "$userid\n";
            close FAMILY;
        }
        print h2("Creating a person for groups @group");
        create_person_file(
            userid=>$userid, 
            name=>param('name'), 
            spouse=>param('spouse'), 
            exclude=>param('exclude'),
            group=>@group
        );
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
sub set_group {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    ($temp) = attributes_for($user, 'group');
    if ((@fams = split(/\s+/, $temp)) <= 0){
        print p("You are not in a group, so I don't know what to do with you.");
        print "Gift Group value is $UserValues{group}";
        print @fams;
        print end_html();
        exit;
    }
    elsif (scalar(@fams) == 1) {
        if ($debug) { print ("The group is @fams");}
        $group = $fams[0];
        if ($debug) { print p("Setting the group to $group") };
        hidden(-name=>'group',-value=>$group);
        if ($debug) { print p("Set the group to ", param('group'))};
        return $group;
    }
    elsif (scalar(@fams) > 1) {
        print startform(),
            radio_group(-name=>'group',
                        -values=>\@fams,
            ),
            br(),
            submit(-name=>'Choose Gift Group'),
            hidden(-name=>'user', -value=>"$user"),
            reset(),
            endform(),
            end_html();
        if ($debug) {print h2("Leaving ", (caller(0))[3])}
        exit;
    }
    else
    {
        print p("You are in an illegal number of groups, so I don't know what to do with you.");
        if ($debug) {print h2("Leaving ", (caller(0))[3])}
        exit;
    }
}
sub print_menu {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    print startform(), 
        submit(-name=>'action', -value=>'Show Members'), 
        submit(-name=>'action', -value=>'Add Member'), 
        submit(-name=>'action', -value=>'Modify Member'), 
        submit(-name=>'action', -value=>'Delete Member'), 
        br,
        br,
        submit(-name=>'action', -value=>'Show Giftlists'), 
        submit(-name=>'action', -value=>'Create Giftlist'), 
        submit(-name=>'action', -value=>'Remove Giftlist'), 
        submit(-name=>'action', -value=>'Display Giftlist'), 
        hr,
        submit(-name=>'action', -value=>'Show Groups'),
        submit(-name=>'action', -value=>'Create Gift Group'),
        submit(-name=>'action', -value=>'Remove Gift Group'),
        hidden(-name=>'group'), 
        endform();
    print hidden(-name=>'user', -value=>"$user");
}
sub print_group {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $group = shift;
    local $_;

    print h2("Your current group consists of");
    foreach (members $group) { 
        print $_, br;
    }
    if ($debug) {print h2("Leaving ", (caller(0))[3])}
}
sub read_person {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my $person = shift;
    local $_;

    open PERSON, "data/person.$person" or print "I don't have any information on $person",br;
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
sub attributes_for {
    if ($debug) {print h2("Entering ", (caller(0))[3])}
    my ($person, @atts) = @_;
    my %UserValues = ();
    my @response;
    local $_;

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

