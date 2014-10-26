# $Id: EndnoteStyle.pm,v 1.1.1.1 2007/01/23 09:26:00 mike Exp $

package Biblio::EndnoteStyle;

use 5.008;
use strict;
use warnings;

our $VERSION = 0.01;

=head1 NAME

Biblio::EndnoteStyle - reference formatting using Endnote-like templates

=head1 SYNOPSIS

 use Biblio::EndnoteStyle;
 $style = new Biblio::EndnoteStyle();
 ($text, $errmsg) = $style->format($template, \%fields);

=head1 DESCRIPTION

This small module provides a way of formatting bibliographic
references using style templates similar to those used by the popular
reference management software Endnote (http://www.endnote.com/).  The
API is embarrassingly simple: a formatter object is made using the
class's constructor, the C<new()> method; C<format()> may then be
repeatedly called on this object, using the same or different
templates.

(The sole purpose of the object is to cache compiled templates so that
multiple C<format()> invocations are more efficient than they would
otherwise be.  Apart from that, the API might just as well have been a
single function.)

=head1 METHODS

=head2 new()

 $style = new Biblio::EndnoteStyle();

Creates a new formatter object.  Takes no arguments.

=cut

# The object is vacuous except that it knows its class, so that
# subclasses can be made that override some of the methods.
#
sub new {
    my $class = shift();

    return bless {
	compiled => {},		# cache of compiled templates
    }, $class;
}


=head2 format()

 ($text, $errmsg) = $style->format($template, \%fields);

Formats a reference, consisting of a hash of fields, according to an
Endnote-like template.  The template is a string essentially the same
as those used in Endnote, as documented in the Endnote X User Guide at
http://www.endnote.com/support/helpdocs/EndNoteXWinManual.pdf
pages 390ff.  In particular, pages 415-210 have details of the recipe
format.  Because the templates used in this module are plain text, a
few special characters are used:

=over 4

=item ¬

Link Adjacent words.  This is the "non-breaking space"
described on page 418 of the EndNote X

=item |

Forced Seperation of elements that would otherwise be dependent.

=item ^

Separator for singular/plural aternatives.

=back

In addition to these special characters, backquotes may be used to
prevent literal text from being interpreted as a fieldname.
(### Is this in fact true?  If not, I ought to implement it.)

The hash of fields is passed by reference: keys are fieldnames, and
the corresponding values are the data.  PLEASE NOTE AN IMPORTANT
DIFFERENCE.  Keys that do not appear in the hash at all are not
considered to be fields, so that if they appear in the template, they
will be interpreted as literal text; keys that appear in the hash but
whose values are undefined or empty are considered to be fields with
no value, and will be formatted as empty with dependent text omitted.
So for example:

 $style->format(";Author: ", { Author => "Taylor" }) eq ":Taylor: "
 $style->format(";Author: ", { Author => "" }) eq ";"
 $style->format(";Author: ", { xAuthor => "" }) eq ";Author: "

C<format()> returns two values: the formatted reference and an
error-message.  The error message is defined if and only if the
formatted reference is not.

=cut

sub format {
    my $this = shift();
    my($text, $data) = @_;

    #use Data::Dumper; print Dumper($data);
    my $template = $this->{compiled}->{$text};
    if (!defined $template) {
	my $errmsg;
	($template, $errmsg) = Biblio::EndnoteStyle::Template->new($text);
	return (undef, $errmsg) if !defined $template;
	#print "template '$text'\n", $template->render();
	$this->{compiled}->{$text} = $template;
    }

    return $template->format($data);
}


package Biblio::EndnoteStyle::Template;

sub new {
    my $class = shift();
    my($text) = @_;

    my @sequences;
    while ($text ne "") {
	$text =~ s/^(\s*[^\s|]+\s?)//;
	my $sequence = $1;
	my $obj = Biblio::EndnoteStyle::Sequence->new($sequence);
	push @sequences, $obj;
	$text =~ s/^\|//;
    }

    return bless {
	text => $text,
	sequences => \@sequences,
    }, $class;
}

sub render {
    my $this = shift();

    return join("", map { $_->render() . "\n" } @{ $this->{sequences} });
}

sub format {
    my $this = shift();
    my($data) = @_;

    my $result = "";
    foreach my $sequence (@{ $this->{sequences} }) {
	my($substr, $errmsg) = $sequence->format($data);
	return (undef, $errmsg) if !defined $substr;
	$result .= $substr;
    }

    return $result;
}


# ----------------------------------------------------------------------------

package Biblio::EndnoteStyle::Sequence;

sub WORD { 290168 }
sub LITERAL { 120368 }
sub typename {
    my($type) = @_;
    return "WORD" if $type == WORD;
    return "LITERAL" if $type == LITERAL;
    return "???";
}

sub new {
    my $class = shift();
    my($text) = @_;

    my $tail = $text;
    my @tokens;
    while ($tail =~ s/(.*?)([a-z_]+)//i) {
	my($head, $word) = ($1, $2);
	push @tokens, [ LITERAL, $head ] if $head ne "";
	push @tokens, [ WORD, $word ];
    }
    push @tokens, [ LITERAL, $tail ] if $tail ne "";

    return bless {
	text => $text,
	tokens => \@tokens,
    }, $class;
}

sub render {
    my $this = shift();

    return (sprintf("%24s: ", ("'" . $this->{text} . "'")) .
	    join(", ", map {
		my($type, $val) = @$_;
		typename($type) . " '$val'";
	    } @{ $this->{tokens} }));
}

sub format {
    my $this = shift();
    my($data) = @_;

    my $gotField = 0;
    my $result = "";
    foreach my $token (@{ $this->{tokens} }) {
	my($type, $val) = @$token;
	if ($type == LITERAL) {
	    $result .= $val;
	} elsif ($type != WORD) {
	    die "unexpected token type '$type'";
	} else {
	    my $dval = $data->{$val};
	    $dval = $data->{lc($val)} if !defined $dval;
	    if (!defined $dval) {
		# The word is not a fieldname at all: treat as a literal
		#print "!defined \$dval\n";
		$result .= $val;
	    } elsif (!$gotField && $dval eq "") {
		#print "\$dval is empty\n";
		# Field is empty, so whole dependent sequence is omitted
		return "";
	    } else {
		#print "$dval eq '$dval'\n";
		$gotField = 1;
		$result .= $dval;
	    }
	}
    }

    return $result;
}


=head1 AUTHOR

Mike Taylor, E<lt>mike@miketaylor.org.ukE<gt>

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2007 by Mike Taylor.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut


1;
