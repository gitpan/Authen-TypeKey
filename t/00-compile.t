# $Id: 00-compile.t,v 1.2 2004/06/20 12:09:33 btrott Exp $

my $loaded;
BEGIN { print "1..1\n" }
use Authen::TypeKey;
$loaded++;
print "ok 1\n";
END { print "not ok 1\n" unless $loaded }
