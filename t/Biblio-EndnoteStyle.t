# $Id: Biblio-EndnoteStyle.t,v 1.1.1.1 2007/01/23 09:26:00 mike Exp $

use strict;
use warnings;
use Test::More tests => 5;

BEGIN { use_ok('Biblio::EndnoteStyle') };

my $style = new Biblio::EndnoteStyle();
ok(1, "made style object");

#print("[", $style->format(";Author: ", { Author => "Taylor" }), "]\n");
ok($style->format(";Author: ", { Author => "Taylor" }) eq ";Taylor: ",
   "author provided");

#print("[", $style->format(";Author: ", { Author => "" }), "]\n");
ok($style->format(";Author: ", { Author => "" }) eq "",
   "author empty");

#print("[", $style->format(";Author: ", { xAuthor => "" }), "]\n");
ok($style->format(";Author: ", { xAuthor => "" }) eq ";Author: ",
   "author absent");
