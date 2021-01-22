# --
# Copyright (C) 2021 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::ForwardMail;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::System::Log
    Kernel::System::Ticket
    Kernel::System::Ticket::Article
    Kernel::System::Time
    Kernel::System::TemplateGenerator
    Kernel::System::Email
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = { %Param };
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject            = $Kernel::OM->Get('Kernel::Config');
    my $LogObject               = $Kernel::OM->Get('Kernel::System::Log');
    my $TimeObject              = $Kernel::OM->Get('Kernel::System::Time');
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
    my $EmailObject             = $Kernel::OM->Get('Kernel::System::Email');
    my $TicketObject            = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ArticleObject           = $Kernel::OM->Get('Kernel::System::Ticket::Article');

    if ( $Self->{Debug} >= 1 ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => "starting Filter $Param{JobConfig}->{Name}",
        );
    }

    my %Mail = %{ $Param{GetParam} || {} };

    return 1 if !$Mail{'X-OTRS-ForwardMail-To'};

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1,
        UserID        => 1,
    );

    delete @Mail{qw/From To Cc Bcc EmailSecurity/};

    my $From = $TemplateGeneratorObject->Sender(
        QueueID => $Ticket{QueueID},
        UserID  => 1,
    );

    my $Subject = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Mail{Subject},
        Action       => 'Forward',
    );

    my $To = $Mail{'X-OTRS-ForwardMail-To'};

    if ( $To =~ m{\A<OTRS_TICKET_}xms ) {
        $To =~ s{<OTRS_TICKET_([^>]+)>}{$Ticket{$1}}xms;
    }

    return 1 if !$To;

    my %Opts;

    if ( $Mail{'X-OTRS-ForwardMail-Security-Type'} && (
        $Mail{'X-OTRS-ForwardMail-Security-SignKey'} ||
        $Mail{'X-OTRS-ForwardMail-Security-EncryptKey'} ) ) {

        $Opts{EmailSecurity}->{Backend} =  $Mail{'X-OTRS-ForwardMail-Security-Type'};

        if ( $Mail{'X-OTRS-ForwardMail-Security-SignKey'}  ) {
            $Opts{EmailSecurity}->{SignKey} =  $Mail{'X-OTRS-ForwardMail-Security-SignKey'};
        }

        if ( $Mail{'X-OTRS-ForwardMail-Security-EncryptKey'}  ) {
            $Opts{EmailSecurity}->{EncryptKey} = [$Mail{'X-OTRS-ForwardMail-Security-EncryptKey'}];
        }
    }

    my $Success = $EmailObject->Send(
        %Mail,
        %Opts,
        From    => $From,
        To      => $To,
        Subject => $Subject,
    );

    my $Message = sprintf "Mail %s forwarded to %s",
        ( $Success ? '' : ' not'),
        $To;

    $TicketObject->HistoryAdd(
        TicketID     => $Param{TicketID},
        HistoryType  => 'Misc',
        Name         => $Message,
        CreateUserID => 1,
    );

    return 1;
}

1;
