# --
# Copyright (C) 2021 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package var::packagesetup::ForwardMail;

use strict;
use warnings;

use utf8;

use List::Util qw(first);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::SysConfig
    Kernel::System::DB
    Kernel::System::Stats
);

=head1 NAME

ForwardMail.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    # create dynamic fields 
    $Self->_DoSysConfigChanges();

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    $Self->_DoSysConfigChanges();

    return 1;
}

=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item _DoSysConfigChanges()

=cut

sub _DoSysConfigChanges {
    my ($Self, %Param) = @_;

    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');

    my $Headers = $ConfigObject->Get('PostmasterX-Header') || [];
    my $Changed;

    my @NewHeaders = qw(
        X-OTRS-ForwardMail-To
        X-OTRS-ForwardMail-Security-Type
        X-OTRS-ForwardMail-Security-SignKey
        X-OTRS-ForwardMail-Security-EncryptKey
    );

    for my $Header ( @NewHeaders ) {
        if ( !first{ $_ eq $Header } @{ $Headers } ) {
            push @{$Headers}, $Header;
            $Changed = 1;
        }
    }

    my @Settings;
    if ( $Changed ) {
        push @Settings, {
            Name           => 'PostmasterX-Header',
            EffectiveValue => $Headers,
        };

        # update the sysconfig
        my $Success = $SysConfigObject->SettingsSet(
            UserID   => 1,
            Comments => 'Add new PostmasterX-Header',
            Settings => \@Settings,
        );
    }
}

1;
