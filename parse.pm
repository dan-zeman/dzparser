package parse; # Knihovn� funkce parseru pot�ebn� jak p�i tr�ninku, tak p�i anal�ze.
use vystupy;



#------------------------------------------------------------------------------
# P�e�te konfigura�n� soubor.
#------------------------------------------------------------------------------
sub precist_konfig
{
    my $jmeno_souboru = shift;
    my $konfig = shift; # odkaz na hash, kam ulo�it konfiguraci
    my $konfig_log;
    open(SOUBOR, $jmeno_souboru);
    while(<SOUBOR>)
    {
        # V�echny ��dky konfigura�n�ho souboru si zat�m pamatovat, aby bylo pozd�ji mo�n� vypsat je do logu.
        # Nem��eme je vypsat hned, proto�e zp�sob vypisov�n� je konfigurac� tak� ovlivn�n.
        $konfig_log .= $_;
        # Smazat z konfigura�n�ho souboru koment��e.
        s/#.*//;
        # Zbytek m� tvar "prom�nn� = hodnota".
        if(m/(\w+)\s*=\s*(.*)/)
        {
            $konfig->{$1} = $2;
        }
    }
    close(SOUBOR);
    # Konfiguraci ze souboru lze p�eb�t konfigurac� z p��kazov�ho ��dku.
    # Libovoln� argument na p��kazov�m ��dku m��e m�t tvar jako ��dek konfigura�n�ho souboru, nap�. "stat=013.stat".
    # Krom� toho existuje zkratka "-q" za "ticho=1".
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
    # (Nemohlo se to ud�lat rovnou, proto�e samo zapisov�n� do logu je konfigurac� tak� ovlivn�no.)
    # Zalo�it hlavn� z�znam o parametrech v�po�tu.
    vypsat("konfig", ""); # zajistit zalozeni cisla instance
    my $pocitac = exists($ENV{HOST}) ? $ENV{HOST} : $ENV{COMPUTERNAME}; # HOST je v Linuxu, COMPUTERNAME je ve Windows.
    vypsat("konfig", "V�po�et ��slo $vystupy::cislo_instance byl spu�t�n v ".cas($::starttime)." na po��ta�i $pocitac jako proces ��slo $$.\n");
    vypsat("konfig", "\n$konfig_log\n");
}



#------------------------------------------------------------------------------
# Vr�t� aktu�ln� �as jako �et�zec s polo�kami odd�len�mi dvojte�kou. D�lka
# �et�zce je v�dy stejn� (8 znak�), co� lze vyu��t p�i sloupcov�m form�tov�n�.
#------------------------------------------------------------------------------
sub cas
{
    my($h, $m, $s);
    ($s, $m, $h) = localtime(time());
    return sprintf("%02d:%02d:%02d", $h, $m, $s);
}



#------------------------------------------------------------------------------
# Vyp�e dobu, po kterou program b�el. K tomu pot�ebuje dostat �asov� otisky
# za��tku a konce.
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
    vypsat($soubor, "V�po�et skon�il v ".cas($stoptime).".\n");
    vypsat($soubor, sprintf("Program b�el %02d:%02d:%02d hodin.\n", $hod, $min, $sek));
}



1;
