package debug;
use vystupy;



#------------------------------------------------------------------------------
# Vyp�e lad�c� informaci do souboru DBGLOG, jestli�e je vypisov�n� zapnuto.
#------------------------------------------------------------------------------
sub dbglog
{
    my $retezec = $_[0];
    vypsat("debug.log", $retezec);
}



1;
