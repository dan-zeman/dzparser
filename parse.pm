package parse; # Knihovní funkce parseru potøebné jak pøi tréninku, tak pøi analýze.
use vystupy;



#------------------------------------------------------------------------------
# Pøeète konfiguraèní soubor.
#------------------------------------------------------------------------------
sub precist_konfig
{
    my $jmeno_souboru = shift;
    my $konfig = shift; # odkaz na hash, kam ulo¾it konfiguraci
    my $konfig_log;
    open(SOUBOR, $jmeno_souboru);
    while(<SOUBOR>)
    {
        # V¹echny øádky konfiguraèního souboru si zatím pamatovat, aby bylo pozdìji mo¾né vypsat je do logu.
        # Nemù¾eme je vypsat hned, proto¾e zpùsob vypisování je konfigurací také ovlivnìn.
        $konfig_log .= $_;
        # Smazat z konfiguraèního souboru komentáøe.
        s/#.*//;
        # Zbytek má tvar "promìnná = hodnota".
        if(m/(\w+)\s*=\s*(.*)/)
        {
            $konfig->{$1} = $2;
        }
    }
    close(SOUBOR);
    # Konfiguraci ze souboru lze pøebít konfigurací z pøíkazového øádku.
    # Libovolný argument na pøíkazovém øádku mù¾e mít tvar jako øádek konfiguraèního souboru, napø. "stat=013.stat".
    # Kromì toho existuje zkratka "-q" za "ticho=1".
    for(my $i = 0; $i<=$#main::ARGV; $i++)
    {
        if($main::ARGV[$i] eq "-q")
        {
            $konfig->{"ticho"} = 1;
        }
        if($main::ARGV[$i] =~ m/(\w+)\s*=\s*(.*)/)
        {
            $konfig->{$1} = $2;
            $konfig_log .= "#ARGV\n$main::ARGV[$i]\n";
        }
    }
    # Zaznamenat konfiguraci do logu.
    # (Nemohlo se to udìlat rovnou, proto¾e samo zapisování do logu je konfigurací také ovlivnìno.)
    # Zalo¾it hlavní záznam o parametrech výpoètu.
    vypsat("konfig", ""); # zajistit zalozeni cisla instance
    my $pocitac = exists($ENV{HOST}) ? $ENV{HOST} : $ENV{COMPUTERNAME}; # HOST je v Linuxu, COMPUTERNAME je ve Windows.
    vypsat("konfig", "Výpoèet èíslo $vystupy::cislo_instance byl spu¹tìn v ".cas($::starttime)." na poèítaèi $pocitac jako proces èíslo $$.\n");
    vypsat("konfig", "\n$konfig_log\n");
}



#------------------------------------------------------------------------------
# Vrátí aktuální èas jako øetìzec s polo¾kami oddìlenými dvojteèkou. Délka
# øetìzce je v¾dy stejná (8 znakù), co¾ lze vyu¾ít pøi sloupcovém formátování.
#------------------------------------------------------------------------------
sub cas
{
    my($h, $m, $s);
    ($s, $m, $h) = localtime(time());
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}



#------------------------------------------------------------------------------
# Vypí¹e dobu, po kterou program bì¾el. K tomu potøebuje dostat èasové otisky
# zaèátku a konce.
#------------------------------------------------------------------------------
sub vypsat_delku_trvani_programu
{
    my $starttime = $_[0];
    my $stoptime = $_[1];
    my $soubor = $_[2];
    if($soubor eq "")
    {
        $soubor = "konfig";
    }
    my $cas = $stoptime-$starttime;
    my $hod = int($cas/3600);
    my $min = int(($cas%3600)/60);
    my $sek = $cas%60;
    vypsat($soubor, "Výpoèet skonèil v ".cas($stoptime).".\n");
    vypsat($soubor, sprintf("Program bì¾el %02d:%02d:%02d hodin.\n", $hod, $min, $sek));
}



1;
