package Yairc::Login;

use strict;
use warnings;

use Plack::Builder;
use FindBin;
use lib ("$FindBin::Bin/lib");

use Data::UUID; # TODO: don't use

sub new {
    my ( $class, @args ) = @_;
    return bless { @args }, $class;
}

sub data_storage { $_[0]->{ data_storage } } 

sub user_info_set {
    my ($self, $user_key,$nickname,$profile_image_url,$sns_data_cache) = @_;
    my $ug = new Data::UUID;
    my $token = $ug->create_str();

    $self->data_storage->add_or_replace_user({
        user_key => $user_key,
        nickname => $nickname,
        token    => $token,
        profile_image_url => $profile_image_url,
        sns_data_cache    => $sns_data_cache,
    });

    return $token;
}


1;
