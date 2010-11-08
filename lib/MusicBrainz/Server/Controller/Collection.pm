package MusicBrainz::Server::Controller::Collection;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller' };

with 'MusicBrainz::Server::Controller::Role::Load' => {
    entity_name => 'collection',
    model       => 'Collection',
};

sub base : Chained('/') PathPart('collection') CaptureArgs(0) { }
after 'load' => sub
{
    my ($self, $c) = @_;
    my $collection = $c->stash->{collection};

    # Load editor
    $c->model('Editor')->load($collection);
};

sub add : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $collection = $c->stash->{collection};
    my $release_id = $c->request->params->{release};

    $c->model('Collection')->add_releases_to_collection($collection->id, $release_id);

    $c->response->redirect($c->req->referer);
    $c->detach;
}

sub remove : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $collection = $c->stash->{collection};
    my $release_id = $c->request->params->{release};

    $c->model('Collection')->remove_releases_from_collection($collection->id, $release_id);

    $c->response->redirect($c->req->referer);
    $c->detach;
}

sub show : Chained('load') PathPart('')
{
    my ($self, $c) = @_;

    my $collection = $c->stash->{collection};

    my $user = $collection->editor;
    $c->detach('/error_404')
        if ((!$c->user_exists || $c->user->id != $user->id) && !$collection->public);

    my $order = $c->req->params->{order} || 'date';

    my $releases = $self->_load_paged($c, sub {
        $c->model('Release')->find_by_collection($collection->id, shift, shift, $order);
    });
    $c->model('ArtistCredit')->load(@$releases);
    $c->model('Medium')->load_for_releases(@$releases);
    $c->model('MediumFormat')->load(map { $_->all_mediums } @$releases);
    $c->model('Country')->load(@$releases);
    $c->model('ReleaseLabel')->load(@$releases);
    $c->model('Label')->load(map { $_->all_labels } @$releases);

    $c->stash(
        collection => $collection,
        order => $order,
        releases => $releases,
        template => 'collection/index.tt'
    );
}

sub _form_to_hash
{
    my ($self, $form) = @_;

    return map { $form->field($_)->name => $form->field($_)->value } $form->edit_field_names;
}

sub create : Local RequireAuth
{
    my ($self, $c) = @_;

    my $form = $c->form( form => 'Collection' );

    if ($c->form_posted && $form->submitted_and_valid($c->req->params)) {
        my %insert = $self->_form_to_hash($form);

        my $collection = $c->model('Collection')->insert($c->user->id, \%insert);

        $c->response->redirect(
            $c->uri_for_action($self->action_for('show'), [ $collection->gid ]));
    }
}

sub edit : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $collection = $c->stash->{collection};

    my $user = $collection->editor;
    $c->detach('/error_404') if ($c->user->id != $user->id);

    my $form = $c->form( form => 'Collection', init_object => $collection );

    if ($c->form_posted && $form->submitted_and_valid($c->req->params)) {
        my %update = $self->_form_to_hash($form);

        $c->model('Collection')->update($collection->id, \%update);

        $c->response->redirect(
            $c->uri_for_action($self->action_for('show'), [ $collection->gid ]));
    }
}

sub delete : Chained('load') RequireAuth
{
    my ($self, $c) = @_;

    my $collection = $c->stash->{collection};

    my $user = $collection->editor;
    $c->detach('/error_404') if ($c->user->id != $user->id);

    if ($c->form_posted) {
        $c->model('Collection')->delete($collection->id);

        $c->response->redirect(
            $c->uri_for_action('/user/collections', [ $c->user->name ]));
    }
}

1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky
Copyright (C) 2010 Sean Burke

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
