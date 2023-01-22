# Installation

These instructions cover a fresh install of Guiprep. If you are upgrading,
see [UPGRADE.md](UPGRADE.md) before beginning.

Please direct any help requests to the
[DP forum PERL: guiprep - Markup extraction and pre-processing toolkit](https://www.pgdp.net/phpBB3/viewtopic.php?f=13&t=2237).

See also https://www.pgdp.net/wiki/PPTools/Guiguts/Install (The infrastructure
needed for Guiprep is a subset of what is necessary to run Guiguts.)

## Windows

Using Guiprep on Windows requires installing the following pieces:

* Perl
* Guiprep
* [Perl modules](#perl-modules)

These instructions walk you through using
[Strawberry Perl](http://strawberryperl.com/). Strawberry Perl is the
recommended Perl interpreter as that is what the developers have tested, it
supports the latest version of Perl, and includes all necessary Perl modules.
It can coexist along side other interpreters.

This also uses [BAWT Tcl](https://www.tcl3d.org/bawt/download.html#tclbi), which
is a freely-available and open source version of Tcl for Windows. As of January
2023, a bug in the Tcl installer causes a configuration file to have an
error. The script to install CPAN modules below attempts to detect if this error
is present, and adjusts the file accordingly. If you change the location of your
Tcl installation away from the default, you may need to adjust the CPAN
modules install script as well.

_If you have an existing Perl distribution installed (including if you are
hoping to use the Perl distributed with a previous release of other tools),
read [Other Perl distributions](#other-perl-distributions) before following
the Recommended installation procedure below, as it describes edits you may
need to make if not using the standard setup. If following the standard
procedure below, there is no need to remove your old version of Guiprep - it
should continue to use its own bundled Perl._

### Recommended installation procedure

Unless you are confident with editing `.bat` files and altering the system
PATH variable, please use the recommended instructions and directory names
below. 

_Note that you must do step 8, even if you have done it previously, as
the version of Guiprep you are installing may require additional Perl modules
to any previous versions._

1. Download [Strawberry Perl](http://strawberryperl.com/).
2. Double click the downloaded file to install Strawberry Perl. It is
   recommended that you install in the default folder `c:\Strawberry`.
3. Download [BAWT Tcl](https://www.tcl3d.org/bawt/download.html#tclbi). You will
   need to choose the latest non-alpha version of the "batteries included"
   edition. As of January 2023, this is the Tcl 8.6.13 Batteries Included
   version, either 32 or 64 bit. Your computer is most likely 64-bit, but if
   that version does not work, you can uninstall it and retry with the 32-bit
   version.
4. Double click the downloaded file to install Tcl. It is
   recommended that you install in the default folder `C:\Tcl`.
5. Download the latest release (the zip file) from the [Guiprep
   releases](https://github.com/DistributedProofreaders/guiprep/releases) page.
6. Unzip guiprep zip file to some location on your computer (double
   click the zip file). A common place for this is `c:\guiprep` although it can
   be placed anywhere.
7. Using File Explorer, navigate to the `guiprep` folder you unzipped earlier.
8. Double click the file `install_cpan_modules.pl`. This should display a
   command window listing the Perl modules as it installs them. Note that this
   can take several minutes to complete.
   If instead, Windows says it does not know how to run that file, or it opens
   the file in a text editor like Notepad, you will need to re-associate `.pl` 
   files with the Perl program/app. Follow the steps in the footnote below[^1],
   then return to re-try this step.
9. Double click the `run_guiprep.bat` file in the same folder, and Guiprep
   should start up and be ready for use.
10. See the [Guiguts Windows Installation](https://www.pgdp.net/wiki/PPTools/Guiguts/Install)
   wiki page for information on installing an image viewer to display scans
   during search or header and footer removal. Aspell is not used by this program.
   
[^1]: _Only needed if double-clicking `install_cpan_modules.pl` was
unsuccessful,_ (may vary slightly for different versions of Windows):
   1. Right-click `install_cpan_modules.pl` in File Explorer, and choose
      `Open with`.
   2. Choose `More apps` (may say "Choose Default Program" on some systems)
   3. Scroll to the bottom then choose `Look for another app on this PC`
      (may say "Browse" on some systems)
   4. Navigate to `c:\Strawberry\perl\bin` and choose `perl.exe`.
   5. Return to re-attempt the "Double-click `install_cpan_modules.pl`" step.


### Other Perl distributions

_This section is for advanced users only. Most Guiprep Windows users should follow the
[Recommended installation procedure](#recommended-installation-procedure) above and
can skip this section._

When installing the Perl modules, either with the helper script or manually
running `cpanm`, ensure that the Strawberry Perl versions of `perl` and `cpanm`
are the ones being run. Both programs have a `--version` argument you can use
to see which version of perl is being run. Ensure the version matches that of
Strawberry Perl you installed. Note that ActiveState Perl puts its directories
at the front of the path and Strawberry Perl puts its directories at the end
of the path.

If you have multiple Perl distributions installed you should edit the
`run_guiguts.bat` file and adjust the PATH to the version you want to run
Guiguts. The batch file prepends the default Strawberry Perl directories to the
path and will preferentially use it if available. If your setup is complex, it
may be easiest to clear your path in `run_guiguts.bat` before directories are
added. To do this, directly below the line which saves your existing path,
`set OLDPATH=%PATH%`
add the following line
`set PATH=`

Other Perl distributions, such as
[ActiveState Perl](https://www.activestate.com/products/perl/), may be used
to run Guiprep after installing additional [Perl modules](#perl-modules). Note
that ActiveState Perl versions after 5.10 will not successfully install Tk and
cannot be used with Guiprep.

The bundled perl interpreter included with Guiguts 1.0.25 may also work but
is no longer maintained. The bundled perl includes the required modules
used in 1.0.25 which may not be the full set needed by later versions. 
Many Guiprep users installed Guiguts first and relied on the Perl bundled
with Guiguts. There may be a technique for running Guiprep under the Perl 
bundled with older versions of Guiguts, however it is not recommended, and
will not be documented here.

## MacOS

I don't know if Guiprep will work on MacOS, but if it works it will be analogous
to the way Guiguts runs on MacOS. What follows is the instructions for running 
Guiguts on MacOS, but adapted to Guiprep.

To use Guiprep you need to be running macOS High Sierra (10.13) or higher.
Running Guiprep on MacOS requires installing the following pieces of software.
The list may seem intimidating but it's rather straightforward and only needs
to be done once. These instructions walk you through it.

* Guiprep code
* [Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
* [Homebrew](https://brew.sh/)
* Perl & [Perl modules](#perl-modules)
* [XQuartz](https://www.xquartz.org/)

This is necessary because the version of Perl that comes with MacOS does not
have the necessary header files to build the Perl package dependencies that
Guiprep requires.

### Extracting Guiprep

Download and unzip the most recent guiprep distribution zip file from the
[Guiprep releases](https://github.com/DistributedProofreaders/guiprep/releases) page
to some location on your computer (double click the zip file in Finder). You
can move the `guiprep` directory it creates to anywhere you want. A common place
for this is your home directory.

### XCode Command Line Tools

Homebrew requires either the
[Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
or full [Xcode](https://apps.apple.com/us/app/xcode/id497799835). If you
have the full Xcode installed, skip this step. Otherwise, install the Xcode
Command Line tools by opening Terminal.app and running:

```
xcode-select --install
```

### Homebrew

[Homebrew](https://brew.sh/) is a package manager for MacOS that provides the
version of Perl and relevant Perl modules that Guiprep needs. To install it,
your user account must have Administrator rights on the computer.

Open Terminal.app and install Homebrew with:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

You will be prompted for your password and walked through the installation.
You can accept the defaults it presents to you.

### Perl & Perl modules

Using Terminal.app, use Homebrew to install Perl, cpanm, and Tcl: 

```
brew install perl
brew pin perl
brew install cpanm
brew install tcl-tk
```

After running this last command, homebrew will note that `tcl-tk is keg only`,
and then tell you, based on your specific computer's settings, the command you
need to run if you need to have `tcl-tk` first in your `PATH`. It will be
something like the following, and you need to run that in your terminal next.

```
echo 'export PATH="/opt/homebrew/opt/tcl-tk/bin:$PATH"' >> ~/.zshrc
```

From there, you need one more homebrew package. 

*Note that the bwidget package, required here, is pending acceptance into
upstream homebrew. Once that is completed, there will be no need to use the
willcohen/core tap. For anyone who adds this tap, at that point you can simply
untap using* `brew untap willcohen/core`, *then reinstall from main homebrew
with* `brew uninstall bwidget` *and* `brew install bwidget`.

```
brew tap willcohen/core
brew install bwidget
```

Close Terminal.app and reopen it to ensure that the brew-installed perl is on
your path. Then install all the necessary [Perl modules](#perl-modules). This is
most easily done by running the helper script:

```
perl install_cpan_modules.pl
```

*Note that XQuartz.app is no longer necessary.*

### Starting Guiprep

Start Guiprep with:
```
perl guiprep.pl &
```

### Helper applications

Guiprep does not use any of the "Helper applications"
that Guiguts uses.

## Other

For other platforms, you will need to install Perl and the necessary
[Perl modules](#perl-modules). Then extract the Guiprep directory and run
```
perl guiprep.pl
```

## Using Guiprep from a Git checkout

_This section is for advanced users who want to run the latest in-development
version of Guiprep and are comfortable with git._

You can run Guiguts directly from the git repo with no significant changes.

1. Clone the [Guiguts repo](https://github.com/DistributedProofreaders/guiguts)
   somewhere.
2. Install the necessary system dependencies (perl, perl modules, etc) as
   specified in the sections above.


You can now run Guiprep from the top level directory.

## Perl Modules

Guiguts requires the following Perl modules to be installed via CPAN. Guiprep
requires some of these, but possibly not all of them. For compatibility, we install
all of them.

* Tcl 
* Tk
* Tk::ToolBar
* Tcl::pTk
* Text::LevenshteinXS
* File::Which
* Image::Size
* LWP::UserAgent
* WebService::Validator::HTML::W3C
* XML::XPath

The required Perl modules can be installed with the included helper script:
```
perl install_cpan_modules.pl
```

*Or* you can install them individually using `cpanm`. For example:
```
cpanm --notest --install LWP::UserAgent
```
