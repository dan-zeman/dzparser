package parse; # Knihovní funkce parseru potřebné jak při tréninku, tak při analýze.
use utf8;
use vystupy;



#------------------------------------------------------------------------------
# Přečte konfigurační soubor.
#------------------------------------------------------------------------------
sub precist_konfig
{
    my $jmeno_souboru = shift;
    my $konfig = shift; # odkaz na hash, kam uložit konfiguraci
    my $konfig_log;
    open(SOUBOR, $jmeno_souboru);
    while(<SOUBOR>)
    {
        # Všechny řádky konfiguračního souboru si zatím pamatovat, aby bylo později možné vypsat je do logu.
        # Nemůžeme je vypsat hned, protože způsob vypisování je konfigurací také ovlivněn.
        $konfig_log .= $_;
        # Smazat z konfiguračního souboru komentáře.
        s/#.*//;
        # Zbytek má tvar "proměnná = hodnota".
        if(m/(\w+)\s*=\s*(.*)/)
        {
            $konfig->{$1} = $2;
        }
    }
    close(SOUBOR);
    # Konfiguraci ze souboru lze přebít konfigurací z příkazového řádku.
    # Libovolný argument na příkazovém řádku může mít tvar jako řádek konfiguračního souboru, např. "stat=013.stat".
    # Kromě toho existuje zkratka "-q" za "ticho=1".
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
    # (Nemohlo se to udělat rovnou, protože samo zapisování do logu je konfigurací také ovlivněno.)
    # Založit hlavní záznam o parametrech výpočtu.
    vypsat("konfig", ""); # zajistit zalozeni cisla instance
    my $pocitac = exists($ENV{HOST}) ? $ENV{HOST} : $ENV{COMPUTERNAME}; # HOST je v Linuxu, COMPUTERNAME je ve Windows.
    vypsat("konfig", "Výpočet číslo $vystupy::cislo_instance byl spuštěn v ".cas($::starttime)." na počítači $pocitac jako proces číslo $$.\n");
    vypsat("konfig", "\n$konfig_log\n");
    # Upravit hodnoty atributů, které závisí na jiných atributech.
    if($konfig->{ukecanost}<0)
    {
        if($konfig->{rezim} eq "normal")
        {
            if($konfig->{ukecanost}==-1)
            {
                $konfig->{ukecanost} = 1;
            }
            elsif($konfig->{ukecanost}==-2)
            {
                $konfig->{ukecanost} = 0;
            }
        }
        else
        {
            $konfig->{ukecanost} = 2;
        }
    }
}



#------------------------------------------------------------------------------
# Vrátí aktuální čas jako řetězec s položkami oddělenými dvojtečkou. Délka
# řetězce je vždy stejná (8 znaků), což lze využít při sloupcovém formátování.
#------------------------------------------------------------------------------
sub cas
{
    my($h, $m, $s);
    ($s, $m, $h) = localtime(time());
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}



#------------------------------------------------------------------------------
# Vypíše dobu, po kterou program běžel. K tomu potřebuje dostat časové otisky
# začátku a konce.
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
    vypsat($soubor, "Výpočet skončil v ".cas($stoptime).".\n");
    vypsat($soubor, sprintf("Program běžel %02d:%02d:%02d hodin.\n", $hod, $min, $sek));
}



1;
