# $Id: Makefile.PL,v 1.3 2004/06/20 13:23:46 btrott Exp $

use inc::Module::Install;

name('Authen-TypeKey');
abstract('TypeKey Authentication');
author('Six Apart <cpan@sixapart.com>');
version_from('lib/Authen/TypeKey.pm');
license('perl');
no_index(directory => 't');
sign(1);

include('ExtUtils::AutoInstall');

requires('Crypt::DSA');
requires('MIME::Base64');
requires('LWP');

auto_include();
auto_install();

&WriteAll;
