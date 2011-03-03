package MusicBrainz::Server::Controller::ReleaseEditor::Import;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller' }

__PACKAGE__->config( namespace => 'release/import' );

sub freedb : Path('/release/import/freedb') RequireAuth {
    my ($self, $c) = @_;
    my $query_form  = $c->form( query => 'Search::Query', name => 'search' );
    my $import_form = $c->form( freedb => 'Search::Query', name => 'freedb' );

    if ($import_form->submitted_and_valid($c->req->query_params)) {
        die 'Looks like I have an ID';
    }

    if ($query_form->submitted_and_valid($c->req->query_params)) {
        die 'I should search';
    }
}

1;
