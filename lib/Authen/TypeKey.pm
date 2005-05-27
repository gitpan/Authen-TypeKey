# $Id: TypeKey.pm 1845 2005-05-27 18:41:32Z btrott $

package Authen::TypeKey;
use strict;
use base qw( Class::ErrorHandler );

use Math::BigInt lib => 'GMP,Pari';
use MIME::Base64 qw( decode_base64 );
use Digest::SHA1 qw( sha1 );
use LWP::UserAgent;
use HTTP::Status qw( RC_NOT_MODIFIED );

our $VERSION = '0.04';

sub new {
    my $class = shift;
    my $tk = bless { }, $class;
    $tk->skip_expiry_check(0);
    $tk->expires(600);
    $tk->key_url('http://www.typekey.com/extras/regkeys.txt');
    $tk->version(1.1);
    $tk->token('');
    $tk;
}

sub _var {
    my $tk = shift;
    my $var = shift;
    $tk->{$var} = shift if @_;
    $tk->{$var};
}

sub key_cache         { shift->_var('key_cache',         @_) }
sub skip_expiry_check { shift->_var('skip_expiry_check', @_) }
sub expires           { shift->_var('expires',           @_) }
sub key_url           { shift->_var('key_url',           @_) }
sub token             { shift->_var('token',             @_) }
sub version           { shift->_var('version',           @_) }
sub ua                { shift->_var('ua',                @_) }

sub verify {
    my $tk = shift;
    my($email, $username, $name, $ts, $sig);
    if (@_ == 1) {
        my $q = $_[0];
        if (ref $q eq 'HASH') {
            ($email, $username, $name, $ts, $sig) = map $_[0]->{$_},
                qw( email name nick ts sig );
        } else {
            ($email, $username, $name, $ts, $sig) = map $q->param($_),
                qw( email name nick ts sig );
        }
    } else {
        ## Later we could process arguments passed in a hash.
        return $tk->error("usage: verify(\$query)");
    }
    for ($email, $sig) {
        tr/ /+/;
    }
    return $tk->error("TypeKey data has expired")
        unless $tk->skip_expiry_check || $ts + $tk->expires >= time;
    my $key = $tk->_fetch_key($tk->key_url) or return;
    my($r, $s) = split /:/, $sig;
    $sig = {};
    $sig->{r} = Math::BigInt->new("0b" . unpack("B*", decode_base64($r)));
    $sig->{s} = Math::BigInt->new("0b" . unpack("B*", decode_base64($s)));
    my $msg = join '::', $email, $username, $name, $ts,
        $tk->version >= 1.1 ? ($tk->token) : ();
    unless ($tk->_verify($msg, $key, $sig)) {
        return $tk->error("TypeKey signature verification failed");
    }
    { name => $username,
      nick => $name,
      email => $email,
      ts => $ts };
}

sub _verify {
    my $tk = shift;
    my($msg, $key, $sig) = @_;
    my $u1 = Math::BigInt->new("0b" . unpack("B*", sha1($msg)));
    $sig->{s}->bmodinv($key->{q});
    $u1 = ($u1 * $sig->{s}) % $key->{q};
    $sig->{s} = ($sig->{r} * $sig->{s}) % $key->{q};
    $key->{g}->bmodpow($u1, $key->{p});
    $key->{pub_key}->bmodpow($sig->{s}, $key->{p});
    $u1 = ($key->{g} * $key->{pub_key}) % $key->{p};
    $u1 %= $key->{q};
    $u1 == $sig->{r};
}

sub _fetch_key {
    my $tk = shift;
    my($uri) = @_;
    my $cache = $tk->key_cache;
    ## If it's a callback, call it and return the return value.
    return $cache->($tk, $uri) if $cache && ref($cache) eq 'CODE';
    ## Otherwise, load the key.
    my $data;
    my $ua = $tk->ua || LWP::UserAgent->new;
    if ($cache) {
        my $res = $ua->mirror($uri, $cache);
        return $tk->error("Failed to fetch key: " . $res->status_line)
            unless $res->is_success || $res->code == RC_NOT_MODIFIED;
        open my $fh, $cache
            or return $tk->error("Can't open $cache: $!");
        $data = do { local $/; <$fh> };
        close $fh;
    } else {
        my $res = $ua->get($uri);
        return $tk->error("Failed to fetch key: " . $res->status_line)
            unless $res->is_success;
        $data = $res->content;
    }
    chomp $data;
    my $key = {};
    for my $f (split /\s+/, $data) {
        my($k, $v) = split /=/, $f, 2;
        $key->{$k} = Math::BigInt->new($v);
    }
    $key;
}

1;
__END__

=head1 NAME

Authen::TypeKey - TypeKey authentication verification

=head1 SYNOPSIS

    use CGI;
    use Authen::TypeKey;
    my $q = CGI->new;
    my $tk = Authen::TypeKey->new;
    $tk->token('typekey-token');
    my $res = $tk->verify($q) or die $tk->errstr;

=head1 DESCRIPTION

I<Authen::TypeKey> is an implementation of verification for signatures
generated by TypeKey authentication. For information on the TypeKey
protocol and using TypeKey in other applications, see
I<http://www.sixapart.com/typekey/api>.

=head1 USAGE

=head2 Authen::TypeKey->new

Create a new I<Authen::TypeKey> object.

=head2 $tk->token([ $typekey_token ])

Your TypeKey token, which you passed to TypeKey when creating the original
sign-in link. This is required to successfully validate the signature in
TypeKey 1.1 and higher, which includes the token in the plaintext.

This must be set B<before> calling I<verify>.

=head2 $tk->verify($query)

Verify a TypeKey signature based on the other parameters given. The signature
and other parameters are found in the I<$query> object, which should be
either a hash reference, or any object that supports a I<param> method--for
example, a I<CGI> or I<Apache::Request> object.

If the signature is successfully verified, I<verify> returns a reference to
a hash containing the following values.

=over 4

=item * name

The unique username of the TypeKey user.

=item * nick

The user's display name.

=item * email

The user's email address. If the user has chosen not to pass his/her
email address, this will contain the SHA-1 hash of the string
C<mailto:E<lt>emailE<gt>>.

=item * ts

The timestamp at which the signature was generated, expressed as seconds
since the epoch.

=back

If verification is unsuccessful, I<verify> will return C<undef>, and the
error message can be found in C<$tk-E<gt>errstr>.

=head2 $tk->key_cache([ $cache ])

Provide a caching mechanism for the TypeKey public key.

If I<$cache> is a CODE reference, it is treated as a callback that should
return the public key. The callback will be passed two arguments: the
I<Authen::TypeKey> object, and the URI of the key. It should return a
hash reference with the I<p>, I<g>, I<q>, and I<pub_key> keys set to
I<Math::BigInt> objects representing the pieces of the DSA public key.

Otherwise, I<$cache> should be the path to a local file where the public
key will be cached/mirrored.

If I<$cache> is not set, the key is not cached. By default, no caching
occurs.

=head2 $tk->skip_expiry_check([ $boolean ])

Get/set a value indicating whether I<verify> should check the expiration
date and time in the TypeKey parameters. The default is to check the
expiration date and time.

=head2 $tk->expires([ $secs ])

Get/set the amount of time at which a TypeKey signature is intended to expire.
The default value is 600 seconds, i.e. 10 minutes.

=head2 $tk->key_url([ $url ])

Get/set the URL from which the TypeKey public key can be obtained. The
default URL is I<http://www.typekey.com/extras/regkeys.txt>.

=head2 $tk->ua([ $user_agent ])

Get/set the LWP::UserAgent-like object which will be used to retrieve the
regkeys from the network.  Needs to support I<mirror> and I<get> methods. 
By default, LWP::UserAgent is used, and this method as a getter returns
C<undef> unless the user agent has been previously set.

=head2 $tk->version([ $version ])

Get/set the version of the TypeKey protocol to use. The default version
is C<1.1>.

=head1 LICENSE

I<Authen::TypeKey> is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, I<Authen::TypeKey> is Copyright 2004 Six Apart
Ltd, cpan@sixapart.com. All rights reserved.

=cut