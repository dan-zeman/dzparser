package parse; # Knihovní funkce parseru potřebné jak při tréninku, tak při analýze.
use utf8;
use vystupy;



#------------------------------------------------------------------------------
# Nastaví výchozí hodnoty parametrů, které jsou nezbytné pro chod programu.
#------------------------------------------------------------------------------
sub vychozi_konfig
{
    # Parametry lze rozdělit jednak podle míry závislosti na jazyku, použité
    # sadě morfologických a syntaktických značek, jednak podle toho, zda daný
    # parametr ovlivňuje pouze parsing, nebo zda je při změně jeho hodnoty
    # potřeba přetrénovat.
    # Následující hash neobsahuje všechny existující parametry. Vynechány byly
    # zejména parametry, jejichž výchozí hodnota má být prázdná nebo nulová.
    # Chcete-li komentovaný přehled parametrů, podívejte se do konfiguračního
    # souboru parser.ini.
    my %konfig =
    (
        # Obecné parametry volání programu.
        "train" => "-", # STDIN
        "test"  => "-", # STDIN
        "kodovani_data" => "utf8", # jinak train zkazí kódování při ukládání statistiky
        # Parametry nezávislé na značkách ani na jazyku.
        "vzdalenost" => 3,
        "vzdalenost_delitel" => 1,
        "komponentove" => 1,
        "vyberzav" => "relativni-cetnost",
        "model" => "ls*slova+lz*znacky",
        "ls" => 0.734375,
        "lokon" => 1,
        "krvety" => 1,
        "ntice" => 1,
        # Parametry závislé na sadě morfologických značek (při sadě odlišné od PDT nebudou fungovat správně).
        "upravovat_mzn" => 0,
#        "predlozky" => 1,
#        "pseudoval" => 1,
        "selex" => 0,
        "selex_predlozky" => 1,
        "selex_podradici_spojky" => 1,
        "selex_zajmena" => 1,
        # Parametry závislé na jazyku (ve zdrojáku jsou přímo uvedena některá česká slova).
        "selex_prislovce_100" => 1,
        "selex_byt" => 1,
        # Parametry závislé na sadě syntaktických značek nebo na pravidlech zavěšování uzlů.
#        "nevlastni_predlozky" => 1,
#        "pod_korenem_sloveso_misto_smeru" => 1,
#        "koordinace" => 1,
#        "nekoord" => 1,
#        "koncint" => 1,
#        "koren_2_deti" => 1,
#        "mezicarkove_useky" => 1,
#        "carka_je_list" => 1,
    );
    return %konfig;
}



#------------------------------------------------------------------------------
# Přečte konfigurační soubor.
#------------------------------------------------------------------------------
sub precist_konfig
{
    my $jmeno_souboru = shift;
    my $konfig = shift; # odkaz na hash, kam uložit konfiguraci
    my $konfig_log;
    open(SOUBOR, $jmeno_souboru);
    binmode(SOUBOR, ":utf8");
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
    vypsat("konfig", "Konfigurační soubor = $jmeno_souboru\n");
    if(! -f $jmeno_souboru)
    {
        vypsat("konfig", "Varování: Konfigurační soubor neexistuje!\n");
    }
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
