#!/usr/bin/env perl

my @modules = (

    # Needed for locating tools
    "File::HomeDir",

    # Needed for user interface
    "Tcl",
    "Tk",
    "Tk::ToolBar",
    "Tcl::pTk",

    # Needed for word frequency harmonics
    "Text::LevenshteinXS",

    # Needed to check if a tool is on the path
    "File::Which",

    # Needed to determine the dimensions of images for HTML
    "Image::Size",

    # Needed for update checking
    "LWP::UserAgent",
);

# Windows-specific modules and file editing
if ( $^O eq 'MSWin32' ) {
    push @modules, "Win32::Unicode::Process";

    # If your Tcl location is non-default, please adjust this path here!
    my $filename = 'C:/Tcl/lib/tclConfig.sh';

    my $data = read_file($filename);
    my $regex = qr/([A-Z_=]+[']+[{]*[-L]*[-I]*)([\/]*[A-Z]+[:]*[\\\/]+BawtBuilds\/TclDistribution\/TclDistribution\-[\d.a]*\/Windows\/[x64|x86]+\/Release\/[Install|Build]+\/Tcl)/mp;
    # If your Tcl location is non-default, please adjust this path here!
    $data =~ s/$regex/$1C:\/Tcl/g;
    write_file($filename, $data);
}

sub read_file {
    my ($filename) = @_;

    open my $in, '<:encoding(UTF-8)', $filename or die "Could not open '$filename' for reading $!";
    local $/ = undef;
    my $all = <$in>;
    close $in;

    return $all;
}

sub write_file {
    my ($filename, $content) = @_;

    open my $out, '>:encoding(UTF-8)', $filename or die "Could not open '$filename' for writing $!";;
    print $out $content;
    close $out;

    return;
}

# Command to use to run cpanm, default to the command directly
$cpanm = "cpanm";

# On Mac, we want to run cpanm with the version of perl on the path -- which
# should be the homebrew-installed version -- not whatever version cpanm is
# pointing to which might be the one that came with macOS.
if ( $^O eq 'darwin' ) {

    # Intel
    if ( -e "/usr/local/bin/cpanm" ) {
        $cpanm = "perl /usr/local/bin/cpanm";
    }

    # Apple Silicon
    elsif ( -e "/opt/homebrew/bin/cpanm" ) {
        $cpanm = "perl /opt/homebrew/bin/cpanm";
    }

    # fall-through to using cpanm directly
}

foreach my $module (@modules) {
    system("$cpanm --notest $module") == 0
      or die("Failed trying to install $module\n");
}
