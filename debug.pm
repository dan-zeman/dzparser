package debug;
use utf8;
use vystupy;



#------------------------------------------------------------------------------
# Vypíše ladící informaci do souboru DBGLOG, jestliže je vypisování zapnuto.
#------------------------------------------------------------------------------
sub dbglog
{
    my $retezec = $_[0];
    vypsat("debug.log", $retezec);
}



1;
