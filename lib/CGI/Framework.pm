package CGI::Framework;

# $Header: /cvsroot/CGI::Framework/lib/CGI/Framework.pm,v 1.59 2003/06/02 16:44:59 mina Exp $

use strict;
use HTML::Template;
use CGI::Session qw/-api3/;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $LASTINSTANCE);
	$VERSION = 0.04;
	@ISA     = qw (Exporter);

	undef $LASTINSTANCE;

	@EXPORT      = qw ();
	@EXPORT_OK   = qw (add_error assert_form assert_session clear_session dispatch form  get_cgi_object get_cgi_session_object html html_push html_unshift initialize_cgi_framework remember session show_template);
	%EXPORT_TAGS = ('nooop' => [@EXPORT_OK],);
}

=head1 NAME

CGI::Framework - A simple-to-use, lightweight web CGI framework

It is primarily a glue between HTML::Template, CGI::Session, CGI, and some magic :)

=head1 SYNOPSIS

  use CGI::Framework;
  use vars qw($f);
  
  #
  # Setup the initial framework instance
  #
  $f = new CGI::Framework (
	  sessions_dir		=>	"/tmp",
	  templates_dir		=>	"/home/stuff/myproject/templates",
	  initial_template	=>	"enterusername",
  )
  || die "Failed to create a new CGI::Framework instance: $@\n";

  #
  # Get the instance to "do it's magic", including handling the verification of the
  # just-submitting form, preparing the data for the upcoming template to be sent, and any cleanup
  #
  $f->dispatch();

  #
  # This sub is automatically called after the "enterusername" template is submitted by the client
  #
  sub validate_enterusername {
	  my $f = shift;
	  if (!$f->form("username")) {
		  $f->add_error("You must enter a username");
	  }
	  elsif (!$f->form("password")) {
		  $f->add_error("You must enter your password");
	  }
	  else {
		  if ($f->form("username") eq "mina" && $f->form("password") eq "verysecret") {
			  $f->session("username", "mina");
			  $f->session("authenticated", "1");
		  }
		  else {
			  $f->add_error("Authentication failed");
		  }
	  }
  }

  #
  # This sub is automatically called before the "mainmenu" template is sent
  #
  sub pre_mainmenu {
	  my $f = shift;
	  $f->assert_session("authenticated");
	  $f->html("somevariable", "somevalue");
	  $f->html("name", $f->session("username"));
  }

  #
  # This sub is automatically called after the "logout" template is sent
  #
  sub post_logout {
	  my $f = shift;
	  $f->clear_session();
  }

=head1 DESCRIPTION

CGI::Framework is a simple and lightweight framework for building web-based CGI applications.  It features complete code-content separation by utilizing the HTML::Template library, stateful sessions by utilizing the CGI::Session library, form parsing by utilizing the CGI library, (optional) multi-lingual templates support, and an extremely easy to use methodology for the validation, pre-preparation and post-cleanup associated with each template.

=head1 CONCEPTUAL OVERVIEW

Before we jump into the technical details, let's skim over the top-level philosophy for a web application:

=over 4

=item *

The client sends an initial GET request to the web server

=item *

The CGI recognizes that this is a new client, creates a new session, sends the session ID to the client in the form of a cookie, followed by sending a pre-defined initial template

=item *

The user interacts with the template, filling out any form elements, then re-submits the form back to the CGI

=item *

The CGI reloads the session based on the client cookie, validates the form elements the client is submitting.  If any errors are found, the client is re-sent the previous template along with error messages.  If no errors were found, the form values are either acted on, or stored into the session instance for later use.  The client is then sent the next template.

=item *

The flow of templates can either be linear, where there's a straight progression from template 1 to template 2 to template 3 (such as a simple ordering form) or can be non-linear, where the template shown will be based on one of many buttons a client clicks on (such as a main-menu always visible in all the templates)

=item *

Sessions should automatically expire if not loaded in X amount of time to prevent unauthorized use.

=back

=head1 IMPLEMENTATION OVERVIEW

Implementing this module usually consists of:

=over 4

=item *

Writing the stub code as per the SYNOPSIS.  This entails creating a new CGI::Framework instance, then calling the dispatch() method.

=item *

Creating your templates in the templates_dir supplied earlier.  Templates should have the .html extension and can contain any templating variables, loops, and conditions described in the L<HTML::Template> documentation.

=item *

For each template created, you can optionally write none, some or all of the needed perl subroutines to interact with it.  The possible subroutines that, if existed, will be called automatically by the dispatch() method are:

=over 4

=item validate_templatename()

This sub will be called after a user submits the form from template templatename.  In this sub you should use the assert_session() and assert_form() methods to make sure you have a sane environment populated with the variables you're expecting.

After that, you should inspect the supplied input from the form in that template.  If any errors are found, use the add_error() method to record your objections.  If no errors are found, you may use the session() method to save the form variables into the session for later utilization.

=item pre_templatename()

This sub will be called right before the template templatename is sent to the browser.  It's job is to call the html() method, giving it any dynamic variables that will be interpolated by L<HTML::Template> inside the template content.

=item post_templatename()

This sub will be called right after the template templatename has been sent to the browser and right before the CGI exits.  It's job is to do any clean-up necessary after displaying that template.  For example, on a final-logout template, this sub could call the clear_session() method to delete any sensitive information.

=back

If any of the above subroutines are found and called, they will be passed 1 argument, the CGI::Framework instance itself.

=back

=head1 STARTING A NEW PROJECT

If you're impatient, skip to the STARTING A NEW PROJECT FOR THE IMPATIENT section below, however it is recommended you at least skim-over this detailed section, especially if you've never used this module before.

The following steps should be taken to start a new project:

=over 4

=item SETUP DIRECTORY STRUCTURE

This is the recommended directory structure for a new project:

=over 4

=item cgi-bin/

This is where your CGI that use()es CGI::Framework will be placed.  CGIs placed there will be very simple, initializing a new CGI::Framework instance and calling the dispatch() method.  The CGIs should also add lib/ to their 'use libs' path, then require pre_post and validate.

=item lib/

This directory will contain 2 important files require()ed by the CGIs, pre_post.pm and validate.pm.  pre_post.pm should contain all pre_templatename() and post_templatename() routines, while validate.pm should contain all validate_templatename() routines.

=item templates/

This directory will contain all the templates you create.  Templates should end in the .html extension to be found by the show_template() method.  More on how you should create the actual templates in the CREATE TEMPLATES section

=item sessions/

This directory will be a temporary holder for all the session files.  It's permissions should allow the user that the web server runs as (typically "nobody") to write to it.

=item public_html/

This directory should contain any static files that your templates reference, such as images, style sheets, static html links, multimedia content, etc...

=back

=item CONFIGURE YOUR WEB SERVER

How to do this is beyond this document due to the different web servers out there, but in summary, you want to create a new virtual host, alias the document root to the above public_html/ directory, alias /cgi-bin/ to the above cgi-bin/ directory and make sure the server will execute instead of serve files there, and in theory you're done.

=item CREATE TEMPLATES

You will need to create a template for each step you want your user to see.  Templates are regular HTML pages with the following additions:

=over 4

=item CGI::Framework required tags

The CGI::Framework absolutely requires you insert these tags into the templates.  No ands, iffs or butts about it.  The framework will NOT work if you do not place these tags in your template:

=over 4

=item <cgi_framework_header>

Place this tag right under the <body> tag

=item <TMPL_INCLUDE NAME="errors.html">

Place this tag wherever you want errors added with the add_error() method to appear

=item <cgi_framework_footer>

Place this tag right before the </body> tag

=back

It is recommended that you utilize HTML::Template's powerful <TMPL_INCLUDE> tag to create base templates that are included at the top and bottom of every template (similar to Server-Side Includes, SSIs).  This has the benefit of allowing you to change the layout of your entire site by modifying only 2 files, as well as allows you to insert the above 3 required tags into the shared header and footer templates instead of having to put them inside every content template.

=item HTML::Template tags

All tags mentioned in the documentation of the HTML::Template module may be used in the templates.  This allows dynamic variable substitutions, conditionals, loops, and a lot more.

To use a variable in the template (IFs, LOOPs, etc..) , it must either:

=over 4

=item *

Have just been added using the html() method, probably in the pre_templatename() routine.

=item *

Has just been submitted from the previous template

=item *

Has been added in the past to the session using the session() method.

=item *

Has been added automatically for you by CGI::Framework. See the DEFAULT TEMPLATE VARIABLES section.

=back

=item CGI::Framework language tags

If you supplied a "valid_languages" arrayref to the new() constructor of CGI::Framework, you can use any of the languages in that arrayref as simple HTML tags.  This allows you to easily write multi-lingual templates, simply by surrounding each language with the appropriate tag.  Depending on the client's chosen language, all other languages will not be served.

For example, if your new() constructor included:

	valid_languages	=>	['en', 'fr']

You can then use in the template something like this:

	<en>Good morning</en>
	<fr>Bonjour</fr>

And the user will be served the right one.

"The right one" needs some elaboration here: By default, the first language supplied in the valid_languages arrayref will be set as the default language.  The user could then change their default language at any point by submitting a form element named "_lang" and a value set to any of the values in the arrayref.

=item The process() javascript function

This javascript function will become available to all your templates and will be sent to the client along with the templates.  Your templates should call this function whenever the user has clicked on something that indicates they'd like to move on to the next template.  For example, if your templates offer a main menu at the top with 7 options, each one of these options should cause a call to this process() javascript function.  Every next, previous, logout, etc.. button should cause a call to this function.

This javascript function accepts the following parameters:

=over 4

=item templatename

B<MANDATORY>

This first parameter is the name of the template to show.  For example, if the user clicked on an option called "show my account info" that should load the accountinfo.html template, the javascript code could look like this:

	<a href="#" onclick="process('accountinfo');">Show my account info</a>

=item item

B<OPTIONAL>

If this second parameter is supplied to the process() call, it's value will be available back in your perl code as key "_item" through the form() method.

This is typically used to distinguish between similar choices.  For example, if you're building a GUI that allows the user to change the password of any of their accounts, you could have something similar to this:

	bob@domain.com   <input type="button" value="CHANGE PASSWORD" onclick="process('changepassword', 'bob@domain.com');">
	<br>
	mary@domain.com  <input type="button" value="CHANGE PASSWORD" onclick="process('changepassword', 'mary@domain.com');">
	<br>
	john@domain.com  <input type="button" value="CHANGE PASSWORD" onclick="process('changepassword', 'john@domain.com');">

=item skipvalidation

B<OPTIONAL>

If this third parameter is supplied to the process() call with a true value such as '1', it will cause CGI::Framework to send the requested template without first calling validate_templatename() on the previous template and forcing the correction of errors.

=back

=back

=over 4

=item The errors template

It is mandatory to create a special template named errors.html.  This template will be included in all the served pages, and it's job is to re-iterate over all the errors added with the add_error() method and display them.  A simple errors.html template looks like this:

=over 4

=item errors.html sample:

	<TMPL_IF NAME="_errors">
		<font color=red><b>The following ERRORS have occurred:</b></font>
		<blockquote>
			<TMPL_LOOP NAME="_errors">
				* <TMPL_VAR NAME="error"><br>
			</TMPL_LOOP>
		</blockquote>
		<font color=red>Please correct below and try again.</font>
		<p>
	</TMPL_IF>

=back

=item The missing info template

It is recommended, although not mandatory, to create a special template named missinginfo.html.  This template will be shown to the client when an assertion made through the assert_form() or assert_session() methods fail.  It's job is to explain to the client that they're probably using a timed-out session, and invites them to start from the beginning.

If this template is not found, the above error will be displayed to the client in a text mode.

=back

=item ASSOCIATE THE CODE WITH THE TEMPLATES

For each template you created, you might need to write a pre_templatename() sub, a post_templatename() sub and a validate_templatename() sub as described earlier.  None of these subs are mandatory.

For clarity and consistency purposes, the pre_templatename() and post_templatename() subs should go into the pre_post.pm file, and the validate_templatename() subs should go into the validate.pm file.

=item WRITE YOUR CGI

Copying the SYNOPSIS into a new CGI file in the cgi-bin/ directory is usually all that's needed unless you have some advanced requirements such as making sure the user is authenticated first before allowing them access to certain templates.

=item TEST, FINE TUNE, ETC . . .

Every developer does this part, right :) ?

=back

=head1 STARTING A NEW PROJECT FOR THE IMPATIENT

=over 4

=item *

Install this module

=item *

Run: perl -MCGI::Framework -e 'CGI::Framework::INITIALIZENEWPROJECT "/path/to/your/project/base"'

=item *

cd /path/to/your/project/base

Customize the stubs that were created there for you.  Refer back to the not-so-impatient section above for clarifications of anything you see there.

=back

=head1 OBJECT-ORIENTED VS. FUNCTION MODES

This module allows you to use an object-oriented or a function-based approach when using it.  The only drawback to using the function-based mode is that there's a tiny bit of overhead during startup, and that you can only have one instance of the object active within the interpreter (which is not really a logical problem since that is never a desirable thing. It's strictly a technical limitation).

=over 4

=item THE OBJECT-ORIENTED WAY

As the examples show, this is the object-way of doing things:

	use CGI::Framework;

	my $instance = new CGI::Framework (
		this	=>	that,
		foo	=>	bar,
	);

	$instance->dispatch();

	sub validate_templatename {
		my $instance = shift;
		if (!$instance->form("country")) {
			$instance->add_error("You must select a country");
		}
		else {
			$instance->remember("country");
		}
	}

	sub pre_templatename {
		my $instance = shift;
		$instance->html("country", [qw(CA US BR)]);
	}

=item THE FUNCTION-BASED WAY

The function-based way is very similar (and slightly less cumbersome to use due to less typing) than the OO way. The differences are: You have to use the ":nooop" tag in the use() line to signify that you want the methods exported to your namespace, as well as use the initialize_cgi_framework() method to initialize the instance instead of the new() method in OO mode.  An example of the function-based way of doing things:

	use CGI::Framework ':nooop';

	initialize_cgi_framework (
		this	=>	that,
		foo	=>	bar,
	);

	dispatch();

	sub validate_templatename {
		if (!form("country")) {
			add_error("You must select a country");
		}
		else {
			remember("country");
		}
	}

	sub pre_templatename {
		html("country", [qw(CA US BR)]);
	}

=back

=head1 THE CONSTRUCTOR / INITIALIZER

=over 4

=item new(%hash)

This is the standard object-oriented constructor.  When called, will return a new CGI::Framework instance.  It accepts a hash (or a hashref) with the following keys:

=over 4

=item callbacks_namespace

B<OPTIONAL>

This key should have a scalar value with the name of the namespace that you will put all the validate_templatename(), pre_templatename() and post_templatename() subroutines in.  If not supplied, it will default to the caller's namespace.  Finally if the caller's namespace cannot be determined, it will default to "main".

The main use of this option is to allow you, if you so choose, to place your callbacks subs into any arbitrary namespace you decide on (to avoid pollution of your main namespace for example).

=item cookie_name

B<OPTIONAL>

This key should have a scalar value with the name of the cookie to use when communicating the session ID to the client.  If not supplied, will default to "sessionid_" and a simplified representation of the URL.

=item initial_template

B<MANDATORY>

This key should have a scalar value with the name of the first template that will be shown to the client when the dispatch() method is called.

=item importform

B<OPTIONAL>

This variable should have a scalar value with the name of a namespace in it.   It imports all the values of the just-submitted form into the specified namespace.  For example:

	importform	=>	"FORM",

You can then use form elements like:

	$error = "Sorry $FORM::firstname, you may not $FORM::action at this time.";

It provides a more flexible alternative to using the form() method since it can be interpolated inside double-quoted strings, however costs more memory.  I am also unsure about how such a namespace would be handled under mod_perl and if it'll remain persistent or not, possibly causing problems.

=item sessions_dir

B<OPTIONAL>

This key should have a scalar value holding a directory name where the session files will be stored.  If not supplied, a suitable temporary directory will be picked from the system.

Note: You may not supply this if you supply the sessions_mysql_dbh key.

=item sessions_mysql_dbh

B<OPTIONAL>

This key should have a value that's a MySQL DBH (DataBase Handle) instance created with the DBI and DBD::Mysql modules.  If supplied then the session data will be stored in the mysql table instead of text files.  For more information on how to prepare the database, refer to the L<CGI::Session::MySQL> documentation.

Note: You may not supply this if you supply the sessions_dir key.

=item templates_dir

B<OPTIONAL>

This key should have a scalar value holding a directory name which contains all the template files.  If not supplied, it will be guessed based on the local directory.

=item valid_languages

B<OPTIONAL>

This key should have an arrayref value.  The array should contain all the possible language tags you've used in the templates.

=back

=item initialize_cgi_framework(%hash)

Just like the above new() constructor, except used in the function-based approach instead of the object-oriented approach.

=back

=head1 METHODS / FUNCTIONS

=over 4

=item add_error($scalar)

This method accepts a scalar error and adds it to the list of errors that will be shown to the client.  It should only be called from a validate_templatename() subroutine for each error found during validating the form.  This will cause the dispatch() method to re-display the previous template along with all the errors added.

=item assert_form(@array)

This method accepts an array of scalar values.  Each element will be checked to make sure that it has been submitted in the just-submitted form and has a true value.  If any elements aren't found or have a false value, the missinginfo template is shown to the client.

=item assert_session(@array)

Just like the assert_form() method, except it checks the values against the session instead of the submitted form.

=item clear_session

This method deletes all the previously-stored values using the session() method.

=item dispatch

This method is the central dispatcher.  It calls validate_templatename on the just-submitted template, checks to see if any errors were added with the add_error() method.  If any errors were added, re-sends the client the previous template, otherwise sends the client the template they requested.

=item form($scalar)

This method accepts an optional scalar as it's first argument, and returns the value associated with that key from the just-submitted form from the client.  If no scalar is supplied, returns all entries from the just-submitted form.

=item get_cgi_object

Returns the underlying CGI object.  To be used if you'd like to do anything fancy this module doesn't provide methods for, such as processing extra cookies, etc...

=item get_cgi_session_object

Returns the underlying CGI::Session object.  To be used if you'd like to do anything fancy this module doesn't provide methods for.

=item html($scalar, $scalar)

This method accepts a scalar key as it's first argument and a scalar value as it's second.  It associates the key with the value in the upcoming template.  This method is typically called inside a pre_template() subroutine to prepare some dynamic variables/loops/etc in the templatename template.

=item html_push($scalar, $scalar)

Very similar to the above html() method, except it treats the key's value as an arrayref (creates it as an arrayref if it didn't exist), and push()es the value into that array.  This method is typically used to append to a key that will be used in a template loop with HTML::Template's <TMPL_LOOP> tag, the value in which case is normally a hashref.

=item html_unshift($scalar, $scalar)

Very similar to the above html_push() method, except it unshift()s instead of push()es the value.

=item remember($scalar)

This method accepts a mandatory scalar as it's first argument.  It then treats that scalar as a key in the just-submitted form, and saves that key-value pair into the session.  This method is simply shorthand for saying:

	$instance->session($keyname, $instance->form($keyname));

It is frequently used to premanently save a submitted form key+value inside the validate_templatename() sub.

=item session($scalar [, $scalar])

This method accepts a scalar key as it's first argument and an optional scalar value as it's second.  If a value is supplied, it saves the key+value pair into the session for future retrieval.  If no value is supplied, it returns the previously-saved value associated with the given key.

=item show_template($scalar)

This method accepts a scalar template name, calls the pre_templatename() sub if found, sends the template to the client, calls the post_templatename() sub if found, then exists.  While sending the template to the client it also takes care of the <cgi_framework_header>, <cgi_framework_footer> tags, as well as the language substitutions.

=back

=head1 DEFAULT TEMPLATE VARIABLES

Aside from variables added through the html() method, the submitted form and the current session, these pre-defined variables will be automatically set for you to use in your templates:

=over 4

=item _formaction

This variable will contain the URL to the current CGI

=back

=head1 BUGS

I do not (knowingly) release buggy software.  If this is the latest release, it's probably bug-free as far as I know.  If you do find a problem, please contact me and let me know.

=head1 AUTHOR

	Mina Naguib
	CPAN ID: MNAGUIB
	mnaguib@cpan.org
	http://www.topfx.com

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

Copyright (C) 2003 Mina Naguib.


=head1 SEE ALSO

L<HTML::Template>, L<CGI::Session>, L<CGI::Session::MySQL>, L<CGI>.

=cut

#
# Takes a scalar
# Adds it to the errors que
#
sub add_error {
	my $self = _getself(\@_);
	$self->{_allow_add_error} || croak "Cannot call add_error at this time";
	my $error = shift || croak "Error not supplied";
	my $existing_errors = $self->{_html}->{_errors} || [];
	push (@$existing_errors, { error => $error, });
	$self->{_html}->{_errors} = $existing_errors;
	return 1;
}

#
# This sub asserts that the key(s) supplied to it exists in the submitted form
# If the value is not true, it calls show_template with "missinginfo"
# It's mostly used by the subs in pre_post* to validate that the values they need exist
#
sub assert_form {
	my $self = _getself(\@_);
	foreach (@_) {
		$self->form($_) || $self->_missinginfo();
	}
	return 1;
}

#
# This sub asserts that the key(s) supplied to it exists in the session
# If the value is not true, it calls show_template with "missinginfo"
# It's mostly used by the subs in pre_post* to validate that the values they need exist
#
sub assert_session {
	my $self = _getself(\@_);
	foreach (@_) {
		$self->session($_) || $self->_missinginfo();
	}
	return 1;
}

#
# Clears the session
#
sub clear_session {
	my $self = _getself(\@_);
	$self->{_session}->delete();
	return 1;
}

#
# This sub takes care of calling any validate_XYZ methods, displaying old page or requested page
# based on whether there were errors or not
#
sub dispatch {
	my $self = _getself(\@_);

	no strict 'refs';

	#
	# Validate the data entered:
	#
	#	if ($self->form("sv") && !grep { $_ eq $self->form("action") } @FORCEVALIDATEACTION) {
	if ($self->form("_sv")) {

		#We skip validation as per requested
	}
	elsif (defined &{ "$self->{callbacks_namespace}::validate_" . $self->session("_lastsent") }) {
		$self->{_allow_add_error} = 1;
		&{ "$self->{callbacks_namespace}::validate_" . $self->session("_lastsent") }($self);
		$self->{_allow_add_error} = 0;
		if ($self->{_html}->{_errors}) {

			#
			# There's an error in the info they supplied for the current step
			# so let's show the last step presented to them
			#
			$self->show_template($self->session("_lastsent"));
		}
	}

	#
	# If we reached here, we're all good and present the action they requested
	#
	$self->show_template($self->form("_action") || $self->{initial_template});

	# Should not reach here
	die "Something's wrong.  You should not be seeing this.\n";
}

#
# Takes a scalar key
# Returns the value for that key from the just-submitted form
#
sub form {
	my $self = _getself(\@_);
	my $key  = shift;
	return length($key) ? $self->{_cgi}->param($key) : $self->{_cgi}->param();
}

#
# Returns the CGI object
#
sub get_cgi_object {
	my $self = _getself(\@_);
	return $self->{_cgi};
}

#
# Returns the CGI::Session object
#
sub get_cgi_session_object {
	my $self = _getself(\@_);
	return $self->{_session};
}

#
# Takes a scalar key and a scalar value
# Adds them to the html que
#
sub html {
	my $self  = _getself(\@_);
	my $key   = shift || croak "key not supplied";
	my $value = shift;
	$self->{_html}->{$key} = $value;
	return 1;
}

#
# Takes a scalar key and a scalar value
# Pushes the value into the html element as an array
#
sub html_push {
	my $self           = _getself(\@_);
	my $key            = shift || croak "key not supplied";
	my $value          = shift;
	my $existing_value = $self->{_html}->{$key} || [];
	if (ref($existing_value) ne "ARRAY") {
		croak "Key $key already exists as non-array. Cannot push into it.";
	}
	push (@{$existing_value}, $value);
	$self->{_html}->{$key} = $existing_value;
	return 1;
}

#
# Takes a scalar key and a scalar value
# Unshifts the value into the html element as an array
#
sub html_unshift {
	my $self           = _getself(\@_);
	my $key            = shift || croak "key not supplied";
	my $value          = shift;
	my $existing_value = $self->{_html}->{$key} || [];
	if (ref($existing_value) ne "ARRAY") {
		croak "Key $key already exists as non-array. Cannot unshift into it.";
	}
	unshift (@{$existing_value}, $value);
	$self->{_html}->{$key} = $existing_value;
	return 1;
}

#
# An alias to new(), to be used in nooop mode
#
sub initialize_cgi_framework {
	return new("CGI::Framework", @_);
}

#
# The constructor.  Initializes pretty much everything, returns a new bless()ed instance
#
sub new {
	my $class = shift || "CGI::Framework";
	my %para = ref($_[0]) eq "HASH" ? %{ $_[0] } : @_;
	my $self = {};
	my $cookie_value;
	my $temp;
	local (*FH);

	#
	# Backwards compatability support
	#
	foreach (qw(callbacks_namespace cookie_name initial_template sessions_dir templates_dir valid_languages)) {
		$temp = $_;
		$temp =~ s/_//g;
		if (!exists $para{$_} && exists $para{$temp}) {
			$para{$_} = $para{$temp};
			delete $para{$temp};
		}
	}

	#
	# Some initial setup
	#
	$para{_html} = {};

	#
	# We set some defaults if unsupplied
	#
	$para{valid_languages} ||= [];
	$para{callbacks_namespace} ||= (caller)[0] || "main";
	if (!$para{cookie_name}) {
		$para{cookie_name} = "sessionid_$ENV{SCRIPT_NAME}";
		$para{cookie_name} =~ s/[^0-9a-z]//gi;
	}
	if (!$para{sessions_mysql_dbh} && !$para{sessions_dir}) {

		#
		# They didn't supply any sessions stuff, so let's take a guess at some directories for file-based storage:
		#
		foreach (qw(/tmp /var/tmp c:/tmp c:/temp c:/windows/temp)) {
			if (-d $_) {
				$para{sessions_dir} = $_;
				last;
			}
		}
	}
	if (!$para{templates_dir}) {
		foreach (qw(./templates ../templates)) {
			if (-d $_) {
				$para{templates_dir} = $_;
				last;
			}
		}
	}

	#
	# Now we do sanity checking
	#
	ref $para{valid_languages} eq "ARRAY" || croak "valid_languages must be an array ref";
	$para{sessions_dir} && $para{sessions_mysql_dbh} && croak "Only one of sessions_dir and sessions_mysql_dbh may be supplied";
	if ($para{sessions_dir}) {

		#
		# Supplied (or determined) file-based sessions storage
		#
		-e $para{sessions_dir} && !-d $para{sessions_dir} && croak "$para{sessions_dir} exists but is not a directory";
		-d $para{sessions_dir} || mkdir($para{sessions_dir}, 0700) || croak "Failed to create $para{sessions_dir}: $!";
		open(FH, ">$para{sessions_dir}/testing") || croak "$para{sessions_dir} is not writable by me: $!";
		close(FH);
		unlink("$para{sessions_dir}/testing") || die "Failed to delete $para{sessions_dir}/testing : $!\n";
	}
	elsif ($para{sessions_mysql_dbh}) {

		#
		# Supplied mysql-based sessions storage
		# Should be a reference to mysql object - but I'll just make sure it's *a* reference to something
		#
		ref($para{sessions_mysql_dbh}) || croak "Invalid sessions_mysql_dbh supplied";
	}
	else {
		croak "Neither sessions_dir or sessions_mysql_dbh were supplied, and could not automatically determine a suitable sessions_dir";
	}
	$para{templates_dir} || croak "templates_dir must be supplied";
	-d $para{templates_dir} || croak "$para{templates_dir} does not exist or is not a directory";
	-f "$para{templates_dir}/errors.html" || croak "Templates directory $para{templates_dir} does not contain the mandatory errors.html template";
	$para{initial_template} || croak "initial_template not supplied";

	#
	# And now some initialization
	#
	$self->{valid_languages}     = $para{valid_languages};
	$self->{templates_dir}       = $para{templates_dir};
	$self->{initial_template}    = $para{initial_template};
	$self->{callbacks_namespace} = $para{callbacks_namespace};
	$self->{_cgi}                = new CGI || die "Failed to create a new CGI instance: $! $@\n";
	$cookie_value = $self->{_cgi}->cookie($para{cookie_name}) || undef;
	if ($para{sessions_dir}) {

		#
		# File-based sessions
		#
		$self->{_session} = new CGI::Session("driver:File", $cookie_value, { Directory => $para{sessions_dir} }) || die "Failed to create new CGI::Session instance with file-based storage: $! $@\n";
	}
	else {

		#
		# Mysql-based sessions
		#
		$self->{_session} = new CGI::Session("driver:MySQL", $cookie_value, { Handle => $para{sessions_mysql_dbh} }) || die "Failed to create new CGI::Session instance with MySQL-based storage: $! $@\n";
	}

	if ($para{"importform"}) {
		$self->{_cgi}->import_names($para{"importform"});
	}

	if (!$cookie_value || ($self->{_session}->id() ne $cookie_value)) {

		# We just created a new session - send it to the user
		print "Set-Cookie: $para{cookie_name}=", $self->{_session}->id(), "\n";
	}
	$self->{_session}->expire("+15m");
	$self->{_session}->param("_formaction", $ENV{SCRIPT_NAME});

	#
	# Language handling
	#
	if ($self->{_cgi}->param("_lang") && scalar @{ $self->{valid_languages} }) {
		if (grep { $self->{_cgi}->param("_lang") eq $_ } @{ $self->{valid_languages} }) {

			#
			# Override session language
			#
			$self->{_session}->param("_lang", $self->{_cgi}->param("_lang"));
		}
		else {
			print "Content-type: text/plain\n\n";
			print "Unsupported language\n";
			exit;
		}
	}
	elsif (scalar @{ $self->{valid_languages} } && !$self->{_session}->param("_lang")) {

		# Set default language
		$self->{_session}->param("_lang", $self->{valid_languages}->[0]);
	}

	#
	# We're done initializing !
	#
	$self = bless($self, ref($class) || $class);
	$LASTINSTANCE = $self;
	return ($self);
}

#
# Takes a scalar key
# Copies that key from the form to the session
#
sub remember {
	my $self = _getself(\@_);
	my $key = shift || croak "key not supplied";
	$self->session($key, $self->form($key));
}

#
# Takes a scalar key, and an optional value
# Gives them to the param() method of CGI::Session
#
sub session {
	my $self  = _getself(\@_);
	my $key   = shift || croak "key not supplied";
	my $value = shift;
	return defined($value) ? $self->{_session}->param($key, $value) : $self->{_session}->param($key);
}

#
# Takes a template name
# Shows it
# Calls pre_templatename and post_templatename appropriately
# THEN EXITS
#
sub show_template {
	my $self = _getself(\@_);
	my $template_name = shift || croak "Template name not supplied";
	my $template;
	my $content_type;
	my $filename;
	my $output;
	my ($key, $value);
	my $temp;
	my $header;
	my $footer;

	no strict 'refs';

	if (defined &{"$self->{callbacks_namespace}::pre_$template_name"}) {

		#
		# Execute a pre_ for this template
		#
		&{"$self->{callbacks_namespace}::pre_$template_name"}($self);
	}

	#
	# Prepare template
	#
	($filename, $content_type) = $self->_get_template_details($template_name);
	croak "Could not find template $template_name" if !$filename;

	$template = HTML::Template->new(
		filename          => $filename,
		path              => [ $self->{templates_dir} ],
		associate         => [ $self->{_session}, $self->{_cgi} ],
		die_on_bad_params => 0,
	  )
	  || die "Error creating HTML::Template instance: $! $@\n";
	$template->param($self->{_html});
	$output = $template->output();

	#
	# Implement language substitutions:
	#
	foreach (@{ $self->{valid_languages} }) {
		if ($self->session("_lang") eq $_) {
			$output =~ s#<$_>(.+?)</$_>#$1#gsi;
		}
		else {
			$output =~ s#<$_>(.+?)</$_>##gsi;
		}
	}

	print "Content-type: $content_type\n\n";
	if ($content_type eq "application/x-netscape-autoconfigure-dialer") {

		#
		# We're sending a netscape INS file. It needs to be formatted to binary first
		#
		($output) = ($output =~ /\[netscape\]\s*\n((?:.*=.*\n)+)/i);
		$temp = "";
		foreach ("STATUS=OK", split /\n/, $output) {
			($key, $value) = split (/=/);
			$temp .= pack("nA*nA*", length($key), $key, length($value), $value);
		}
		$output = $temp;
	}
	else {

		#
		# We're (probably) sending an html file. We need to substitute the cgi_framework_STUFF
		#
		foreach (qw(cgi_framework_header cgi_framework_footer)) {
			$output =~ /<$_>/i || croak "Error: Cumulative templates for step $template_name does not contain the required <$_> tag";
		}
		$header = <<"EOM";
	<!-- CGI::Framework BEGIN HEADER -->
	<script language="JavaScript">
	<!--
	function process(a,i,sv) {
		document.myform._action.value=a;
		if (i != null) {
			document.myform._item.value=i;
		}
		if (sv != null) {
			document.myform._sv.value=sv;
		}
		document.myform.submit();
	}
	function checksubmit() {
		if (document.myform._action.value == "") {
			return false;
		}
		else {
			return true;
		}
	}
	// -->
	</script>
	<form name="myform" method="POST" enctype="multipart/form-data" action="$ENV{SCRIPT_NAME}" onSubmit="return checksubmit();">
	<input type="hidden" name="_action" value="">
	<input type="hidden" name="_item" value="">
	<input type="hidden" name="_sv" value="">
	<!-- CGI::Framework END HEADER -->
EOM
		$footer = <<"EOM";
<!-- CGI::Framework BEGIN FOOTER -->
</form>
<!-- CGI::Framework END FOOTER -->
EOM
		$output =~ s/<cgi_framework_header>/$header/i;
		$output =~ s/<cgi_framework_footer>/$footer/i;
	}

	print $output;

	if (defined &{"$self->{callbacks_namespace}::post_$template_name"}) {

		#
		# Execute a post_ for this template
		#
		&{"$self->{callbacks_namespace}::post_$template_name"}($self);
	}
	$self->session("_lastsent", $template_name);
	exit;
}

############################################################################
#
# PRIVATE SUBS START HERE

#
# Takes a templatename
# If found, returns templatefilename, contenttype if wantarray and just the filename in scalar mode
# otherwise, returns undef
sub _get_template_details {
	my $self = _getself(\@_);
	my $template_name = shift || croak "templatename not supplied";
	my $filename;
	my $content_type;

	if (-e "$self->{templates_dir}/$template_name.html") {
		$filename     = "$template_name.html";
		$content_type = "text/html";
	}
	elsif (-e "$self->{templates_dir}/$template_name.ins") {
		$filename = "$template_name.ins";
		if ($ENV{HTTP_USER_AGENT} =~ /MSIE/i) {
			$content_type = "application/x-internet-signup";
		}
		else {
			$content_type = "application/x-netscape-autoconfigure-dialer";
		}
	}
	else {
		return undef;
	}
	return wantarray ? ($filename, $content_type) : $filename;
}

#
# Shows the missinginfo template
# If the template doesn't exist, writes it as text
#
sub _missinginfo {
	my $self = _getself(\@_);
	if ($self->_get_template_details("missinginfo")) {
		$self->show_template("missinginfo");
	}
	else {
		print "Content-type: text/plain\n\n";
		print "You are trying to submit a form with some missing information.  Please start from the beginning.";
		exit;
	}
}

#
# THIS IS A SUB, NOT A METHOD
# Takes an arrayref which should be a reference to the @_ array from whatever sub's calling it
# If the first argument is an instance: of this class, shifts it from the arrayref
# else returns $LASTINSTANCE
# or die()s if lastinstance isn't set
#
sub _getself {
	my $arrayref = shift;
	my $self;
	ref($arrayref) eq "ARRAY" || die "Arrayref not provided to _getself\n";
	if (ref($arrayref->[0]) eq "CGI::Framework") {
		$self = shift @$arrayref;
		return $self;
	}
	elsif (ref($LASTINSTANCE) eq "CGI::Framework") {
		return $LASTINSTANCE;
	}
	else {
		croak "Cannot use this method/sub without creating an instance of CGI::Framework first";
	}
}

#
# THIS IS A SUB, NOT A METHOD
# Takes a directory name
# Creates a skeleton of a new project under it
#
sub INITIALIZENEWPROJECT {
	my $dir = shift || die "\n\nError: You must supply a directory as the first argument\n\n";
	my $cgi_dir       = "$dir/cgi-bin";
	my $lib_dir       = "$dir/lib";
	my $sessions_dir  = "$dir/sessions";
	my $templates_dir = "$dir/templates";
	my $public_dir    = "$dir/public_html";
	local (*FH);
	my $filename;
	my $content;
	my $mode;

	$dir =~ m#^([/\\])|(\w:)# || die "\n\nYou must specify a fully-qualified, not a relative path\n\n";
	-d $dir && die "\n\n$dir already exists.  This is not recommended.  Please specify a non-existant directory\n\n";

	print "\n\nINITIALIZING A NEW PROJECT IN $dir\n\n";

	#
	# Create the directories
	#
	foreach ($dir, $cgi_dir, $lib_dir, $sessions_dir, $templates_dir, $public_dir) {
		print "Creating directory $_ ";
		mkdir($_, 0755) || die "\n\n:Error: Failed to create $_ : $!\n\n";
		print "\n";
	}
	print "Changing $sessions_dir mode ";
	chmod(0777, $sessions_dir) || die "\n\nError: Failed to chmod $sessions_dir to 777: $!\n\n";
	print "\n";

	#
	# Create the files
	#
	foreach (
		[
			"$templates_dir/header.html", 0644, <<"EOM"
	<html>
		<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<head>
		<title>Welcome to my page</title>
	</head>
	<body bgcolor=silver text=navy link=orange alink=orange vlink=orange>

	<cgi_framework_header>

	<TMPL_INCLUDE NAME="errors.html">
EOM
		],
		[
			"$templates_dir/footer.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<hr>
	<center><font size=1>Copyright (C) 2003 ME !!!</font></center>

	<cgi_framework_footer>

	</body>
	</html>
EOM
		],
		[
			"$templates_dir/login.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<TMPL_INCLUDE NAME="header.html">

	The time is now: <TMPL_VAR NAME="currenttime">
	<p>

	<b>Enter your username:</b>
	<br>
	<input type="text" name="username" value="<TMPL_VAR NAME="username" ESCAPE=HTML>">

	<p>

	<b>Enter your password:</b>
	<br>
	<input type="password" name="password" value="<TMPL_VAR NAME="password" ESCAPE=HTML>">

	<p>

	<input type="button" value=" login &gt;&gt; " onclick="process('mainmenu');">

	<TMPL_INCLUDE NAME="footer.html">
EOM
		],
		[
			"$templates_dir/mainmenu.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<TMPL_INCLUDE NAME="header.html">

	<b>Welcome <TMPL_VAR NAME="username"></b>
	<p>
	Please select from the main menu:
	<UL>
		<LI> <a href="#" onclick="process('youraccount');"> View your account details</a>
		<LI> <a href="#" onclick="process('logout');"> Log out</a>
	</UL>

	<TMPL_INCLUDE NAME="footer.html">
EOM
		],
		[
			"$templates_dir/youraccount.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<TMPL_INCLUDE NAME="header.html">

	<b>Your account details:</b>
	<p>
	Username: <b><TMPL_VAR NAME="username"></b>
	<p>
	Your services:
	<br>
	<table>
		<tr>
			<th align=left>Type</th>
			<th align=left>Details</th>
			<th align=left>Amount Due</th>
		</tr>
	<TMPL_LOOP NAME="services">
		<tr>
			<td><TMPL_VAR NAME="type"></td>
			<td><TMPL_VAR NAME="details"></td>
			<td><TMPL_VAR NAME="amount"></td>
		</tr>
	</TMPL_LOOP>
	</table>

	<p>

	<input type="button" value=" &lt;&lt; back to main menu " onclick="process('mainmenu');">

	<TMPL_INCLUDE NAME="footer.html">
EOM
		],
		[
			"$templates_dir/missinginfo.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<TMPL_INCLUDE NAME="header.html">

	<font color=red>PROBLEM:</font>

	It appears that your session is missing some information.  This is usually because you've just attempted to submit a session that has timed-out.  Please <a href="<TMPL_VAR NAME="_formaction" ESCAPE=HTML>">click here</a> to go to the beginning.

	<TMPL_INCLUDE NAME="footer.html">
EOM
		],
		[
			"$templates_dir/errors.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<TMPL_IF NAME="_errors">
		<center>
		<table width=80% border=0 cellspacing=0 cellpadding=5 style="border-style:solid;border-width:1px;border-color:#CC0000;">
		<tr>
			<td valign=top align=left>
				<font color=red><b>The following ERRORS have occurred:</b></font>
				<blockquote>
					<TMPL_LOOP NAME="_errors">
						* <TMPL_VAR NAME="error"><br>
					</TMPL_LOOP>
				</blockquote>
				<font color=red>Please correct below and try again.</font>
			</td>
		</tr>
		</table>
		</center>
		<p>
	</TMPL_IF>
EOM
		],
		[
			"$templates_dir/logout.html", 0644, <<"EOM"
	<!-- Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command -->
	<TMPL_INCLUDE NAME="header.html">

	<b>You have been successfully logged out.</b>

	<TMPL_INCLUDE NAME="footer.html">
EOM
		],
		[
			"$cgi_dir/hello.cgi", 0755, <<"EOM"
#!$^X

	# Stub CGI created by CGI::Framework's INITIALIZENEWPROJECT command

	use strict;
	use CGI::Framework;
	use lib "$lib_dir";
	require pre_post;
	require validate;

	my \$f = new CGI::Framework (
		sessions_dir		=>	"$sessions_dir",
		templates_dir		=>	"$templates_dir",
		initial_template	=>	"login",
	)
	|| die "Failed to create a new CGI::Framework instance: \$\@\\n";

	#
	# Unless they've successfully logged in, keep showing the login page
	#
	if (\$f->session("authenticated") || \$f->form("_action") eq "mainmenu") {
		\$f->dispatch();
	}
	else {
		\$f->show_template("login");
	}

EOM
		],
		[
			"$lib_dir/validate.pm", 0644, <<"EOM"

	# Stub module created by CGI::Framework's INITIALIZENEWPROJECT command

	sub validate_login {
		my \$f = shift;
		if (!\$f->form("username")) {
			\$f->add_error("You must supply your username");
		}
		if (!\$f->form("password")) {
			\$f->add_error("You must supply your password");
		}
		if (\$f->form("username") eq "goodusername" && \$f->form("password") eq "cleverpassword") {
			# Logged in fine
			\$f->remember("username");
			\$f->session("authenticated", 1);
		}
		elsif (\$f->form("username") && \$f->form("password")) {
			\$f->add_error("Login failed");
		}
	}

	1;
EOM
		],
		[
			"$lib_dir/pre_post.pm", 0644, <<"EOM"

	# Stub module created by CGI::Framework's INITIALIZENEWPROJECT command

	sub pre_login {
		my \$f = shift;
		\$f->html("currenttime", scalar localtime(time));
	}

	sub pre_youraccount {
		my \$f = shift;
		my \@services = (
			{
				type	=>	"Cell Phone",
				details	=>	"(514) 123-4567",
				amount	=>	'\$25.00',
			},
			{
				type	=>	"Laptop Rental",
				details	=>	"SuperDuper Pentium 4 3.01hz",
				amount	=>	'\$35.99',
			},
		);
		\$f->html("services", \\\@services);
	}

	sub post_logout {
		my \$f = shift;
		\$f->clear_session();
	}

	1;
EOM
		],
	  )
	{
		($filename, $mode, $content) = @$_;
		print "Creating file $filename ";
		open(FH, ">$filename") || die "\n\nError: Failed to open $filename for writing: $!\n\n";
		print FH $content;
		close(FH);
		print "Setting permission to ", sprintf("%o", $mode), " ";
		chmod($mode, $filename) || die "\n\nError: Failed to set mode on $filename to $mode: $!\n\n";
		print "\n";
	}

	print "\n\nDONE: Your stub project is now ready in $dir\n\n";
	exit;
}

############################################################################
#
# OLD COMPATABILITY SUBS START HERE

sub adderror {
	return add_error(@_);
}

sub clearsession {
	return clear_session(@_);
}

sub showtemplate {
	return show_template(@_);
}

1;
__END__

