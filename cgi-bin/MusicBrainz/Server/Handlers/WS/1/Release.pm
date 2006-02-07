#!/home/httpd/musicbrainz/mb_server/cgi-bin/perl -w
# vi: set ts=4 sw=4 :
#____________________________________________________________________________
#
#   MusicBrainz -- the open internet music database
#
#   Copyright (C) 2004 Robert Kaye
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#   $Id$
#____________________________________________________________________________

use strict;

package MusicBrainz::Server::Handlers::WS::1::Release;

use Apache::Constants qw( );
use Apache::File ();
use MusicBrainz::Server::Handlers::WS::1::Common;

sub handler
{
	my ($r) = @_;
	# URLs are of the form:
	# http://server/ws/1/release or
	# http://server/ws/1/release/MBID 

	return bad_req($r, "Only GET is acceptable")
		unless $r->method eq "GET";

    my $mbid = $1 if ($r->uri =~ /ws\/1\/release\/([a-z0-9-]*)/);

	my %args; { no warnings; %args = $r->args };
    my ($inc, $bad) = convert_inc($args{inc});

    if ($bad)
    {
		return bad_req($r, "Invalid inc options: '$bad'. For usage, please see: http://musicbrainz.org/development/mmd");
	}
	if ((!MusicBrainz::IsGUID($mbid) && $mbid ne '') || $inc eq 'error')
	{
		return bad_req($r, "Incorrect URI. For usage, please see: http://musicbrainz.org/development/mmd");
	}

    if (!$mbid)
    {
		return bad_req($r, "Collections not supported yet.");
    }

	my $status = eval 
    {
		# Try to serve the request from the database
		{
			my $status = serve_from_db($r, $mbid, $inc);
			return $status if defined $status;
		}
        undef;
	};

	if ($@)
	{
		my $error = "$@";
        print STDERR "WS Error: $error\n";
        # TODO: We should print a custom 500 server error screen with details about our error and where to report it
		$r->status(Apache::Constants::SERVER_ERROR());
		return Apache::Constants::SERVER_ERROR();
	}
    if (!defined $status)
    {
        $r->status(Apache::Constants::NOT_FOUND());
        return Apache::Constants::NOT_FOUND();
    }

    $r->status(Apache::Constants::OK());
	return Apache::Constants::OK();
}

sub serve_from_db
{
	my ($r, $mbid, $inc) = @_;

	my $ar;
	my $al;

	require MusicBrainz;
	my $mb = MusicBrainz->new;
	$mb->Login;
	require Album;

	$al = Album->new($mb->{DBH});
    $al->SetMBId($mbid);
	return undef unless $al->LoadFromId(1);

    if ($inc & INC_ARTIST || $inc & INC_TRACKS)
    {
        $ar = Artist->new($mb->{DBH});
        $ar->SetId($al->GetArtist);
        $ar->LoadFromId();
    }

	my $printer = sub {
		print_xml($mbid, $ar, $al, $inc);
	};

	send_response($r, $printer);
	return Apache::Constants::OK();
}

sub print_xml
{
	my ($mbid, $ar, $al, $inc) = @_;

	print '<?xml version="1.0" encoding="UTF-8"?>';
	print '<metadata xmlns="http://musicbrainz.org/ns/mmd-1.0#">';
    xml_release($ar, $al, $inc);
	print '</metadata>';
}

1;
# eof Release.pm
