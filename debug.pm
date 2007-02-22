package debug;
use vystupy;



#------------------------------------------------------------------------------
# Vypí¹e ladící informaci do souboru DBGLOG, jestli¾e je vypisování zapnuto.
#------------------------------------------------------------------------------
sub dbglog
{
    my $retezec = $_[0];
    vypsat("debug.log", $retezec);
}



1;
