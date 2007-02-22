#!/usr/bin/perl
# Naète natrénované statistiky a s jejich pomocí analyzuje vìty na vstupu.
# Analýzy nikam nevypisuje, místo toho je rovnou porovnává se vzorovými
# a poèítá si úspì¹nost.
use debug;
use parse;
use csts;
use vystupy;
use rozebrat; # sub rozebrat_vetu
use model; # kvùli sub zjistit_nezkreslenou_pravdepodobnost()
use krvety;
use ntice;
use subkat;
use nepreskocv;
use plodnost;
use povol;



$starttime = time();
parse::precist_konfig("parser.ini", \%konfig);



# Naèíst natrénované statistiky.
# Výchozí: najít v pracovním adresáøi soubor s nejvy¹¹ím èíslem.
if($konfig{stat} eq "")
{
    opendir(DIR, $konfig{prac}) or die("Nelze otevøít pracovní slo¾ku $konfig{prac}: $!\n");
    my $maxstat;
    while(my $dir = readdir(DIR))
    {
        if($dir =~ m/^(\d+)\.stat\r?\n?$/)
        {
            if($maxstat eq "" || $1>$maxstat)
            {
                $maxstat = $1;
            }
        }
    }
    closedir(DIR);
    $konfig{stat} = $maxstat.".stat";
    vypsat("konfig", "Pou¾ita statistika $konfig{prac}/$konfig{stat}.\n");
    # Pokud najdeme záznam konfigurace, pod kterou statistika vznikla, opsat ji do na¹í konfigurace.
    if(-f "$konfig{prac}/$maxstat.konfig")
    {
        open(STATKONFIG, "$konfig{prac}/$maxstat.konfig");
        while(<STATKONFIG>)
        {
            vypsat("konfig", "stat.konfig> $_");
        }
        close(STATKONFIG);
    }
}
cist_statistiku($konfig{prac}."/".$konfig{stat}, \%stat)
    or die("Chyba: prázdná statistika");
$ls = $konfig{"ls"};
$lz = 1-$ls;
# Je mo¾né naèíst i druhou statistiku a porovnávat, jak se mìní úspì¹nost
# analýzy pøi pou¾ití jedné èi druhé. Volitelná statistika je stat1, základní
# je stat.
if($konfig{stat1})
{
    cist_statistiku($konfig{prac}."/".$konfig{stat1}, \%stat1);
}



# Naèíst seznam subkategorizaèních rámcù sloves.
if($konfig{valence} || $konfig{valence1})
{
    $konfig{nacteny_subkategorizacni_slovnik} = subkat::cist($konfig{subcat}); # vrátí odkaz na hash se subkategorizaèním slovníkem
}



# Naèíst seznam zákazù pøeskoèení slovesa urèitou závislostí.
if($konfig{nepreskocv})
{
    $konfig{nacteny_seznam_zakazu_preskoceni_slovesa} = nepreskocv::cist($konfig{nepreskocv_cesta}); # vrátí odkaz na hash
}



# Naèíst model plodnosti.
if($konfig{plodnost})
{
    if($konfig{plodnost_model} eq "ffm")
    {
        plodnost::pripravit_ffm(\%stat);
    }
    else
    {
        plodnost::cist($konfig{plodnost_cesta}); # plodnost_cesta se zatím nezohledòuje, ète se natvrdo plodnost.txt
    }
}



# Naèíst pomùcky pro model neprojektivit.
if($konfig{neproj})
{
    povol::cist_rematizatory();
}



# Naèíst vzory n-tic.
if($konfig{ntice})
{
    $ntice = ntice::cist("ntice.txt");
}



# Èíst testovací vìty a analyzovat je.

vypsat("csts", "<csts lang=cs><h><source>PDT</source></h><doc file=\"$konfig{analyza}\" id=\"1\"><a><mod>s<txtype>pub<genre>mix<med>nws<temp>1994<authname>y<opus>ln94206<id>3</a><c><p n=\"1\">\n");

$konfig{hook_zacatek_cteni} = sub
{
    my $maska = shift;
    my $soubory = shift;
    vypsat("prubeh", "Maska pro jména souborù s daty: $maska\n");
    vypsat("prubeh", "Nalezeno ".($#{$soubory}+1)." souborù.\n");
};
csts::projit_data($konfig{test}, \%konfig);

vypsat("csts", "</c></doc></csts>\n");



# Vytisknout výsledky srovnání.
$g = $spravne;
$b = $spatne;
$n = $spravne+$spatne;
$p = $g/$n unless $n==0;
$g0 = $vynechano_spravne;
$b0 = $vynechano_spatne;
$n0 = $g0+$b0;
$p0 = $g0/$n0 unless $n0==0;
$g1 = $nejiste_spravne;
$b1 = $nejiste_spatne;
$n1 = $g1+$b1;
$p1 = $g1/$n1 unless $n1==0;
$g5 = $jiste_spravne;
$b5 = $jiste_spatne;
$n5 = $g5+$b5;
$p5 = $g5/$n5 unless $n5==0;
my $predmet = sprintf("Parsing $vystupy::cislo_instance skoncil: %4.1f %% (G $g)", $p*100);
vystupy::kopirovat_do_mailu("vysledky", $predmet);
vypsat("vysledky", "A $n - G $g - B $b - P $p (vse)\n");
vypsat("vysledky", "A $n5 - G $g5 - B $b5 - P $p5 (>=5)\n");
vypsat("vysledky", "A $n1 - G $g1 - B $b1 - P $p1 (>=1)\n");
vypsat("vysledky", "A $n0 - G $g0 - B $b0 - P $p0 (==0)\n");
vypsat("vysledky", "vztazne: G $spravne_vztaz - B ".($celkem_vztaz-$spravne_vztaz)." - P ".($spravne_vztaz/$celkem_vztaz)."\n") if($celkem_vztaz>0);
$gv = $vyber_spravne;
$bv = $vyber_spatne;
$nv = $gv+$bv;
$pv = $gv/$nv unless $nv==0;
vypsat("vysledky", "A $nv - G $gv - B $bv - P $pv ($konfig{testafun})\n");
vypsat("vysledky", lokon::vytvorit_hlaseni());
vypsat("vysledky", "$vzor_lepsi_nez_navrh× mìl vzorový strom VY©©Í pravdìpodobnost ne¾ navrhovaný.\n");
vypsat("vysledky", "$vzor_horsi_nez_navrh× mìl vzorový strom NI®©Í pravdìpodobnost ne¾ navrhovaný.\n");
vypsat("vysledky", "$vzor_stejny_jako_navrh× mìl vzorový strom STEJNOU pravdìpodobnost jako navrhovaný.\n");
vypsat("vysledky", "Vybráno $nuly_navrh/$nuly_vzor závislostí s nulovou pravdìpodobností.\n");
vypsat("vysledky", ntice::vytvorit_hlaseni()) if($konfig{ntice});



$stoptime = time();
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "konfig");
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "vysledky");



###############################################################################
# PODPROGRAMY
###############################################################################



#------------------------------------------------------------------------------
# Analyzuje vìtu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a vìtì
    my $anot = shift; # pole hashù o jednotlivých slovech
    @anot = @{$anot}; # zatím se ukládá jako globální promìnná v main
    if(!$vynechat_vetu)
    {
        $veta++;
        # Ladící výpisy.
        my ($sek, $min, $hod) = localtime(time());
        my $jmeno_souboru_do_hlaseni = $stav_cteni->{soubor};
        $jmeno_souboru_do_hlaseni =~ s-^.*/([^/]*)$-$1-;
        $jmeno_souboru_do_hlaseni =~ s/\.(?:csts|amm)$//i;
        vypsat("prubeh", parse::cas()." $jmeno_souboru_do_hlaseni Analyzuje se veta $veta ...");
        # Povolit ladící výpisy jen u prvních 50 vìt.
        $dbglog = $veta<=50;
        ###############################################
        # TADY ZAÈÍNÁ VLASTNÍ ANALÝZA.
        ###############################################
        my $stav; # výstup parseru: kromì vlastní stromové struktury obsahuje i váhy a jiné doplòkové informace
        # Ke krátkým vìtám máme k dispozici celé stromy.
        if($#{$anot}<=8 && $konfig{krvety})
        {
            $stav = krvety::rozebrat(\%vzorstrom);
        }
        # Ostatní vìty rozebrat klasicky pìknì slovo za slovem.
        else
        {
            # Rozebrat vìtu pomocí statistického modelu závislostí dvou slov na sobì.
            $stav = rozebrat::rozebrat_vetu();
            if($konfig{ntice})
            {
                # Na závìr opravit nìkteré chyby pomocí modelu n-tic.
                # N-tice klidnì mohou pou¾ívat upravené morfologické znaèky z pole
                # @anot, proto¾e teï u¾ se do nich nepromítá dìdìní v rámci koordinace.
                my $rozbor_ntice = ntice::nasadit($ntice, \@anot);
                my @ana1 = @{$stav->{rodic}};
                for(my $i = 0; $i<=$#ana1; $i++)
                {
                    if($rozbor_ntice->[$i] ne "" && $rozbor_ntice->[$i]!=-1)
                    {
                        $ana1[$i] = $rozbor_ntice->[$i];
                    }
                }
                my @vzor = map{$_->{rodic_vzor}}(@anot);
                ntice::zhodnotit(\@vzor, $stav->{rodic}, \@ana1, $rozbor_ntice);
                # Po zhodnocení vlivu n-tic ulo¾it jimi ovlivnìný strom na
                # výstup, aby se poèítala jeho celková úspì¹nost.
                $stav->{rodic} = \@ana1;
            }
        }
        # Spoèítat chyby.
        zkontrolovat_strom($stav);
        # Vypsat výsledný strom.
        vypsat_strom($stav_cteni->{vetid}, $stav->{rodic});
        # Vymazat promìnné, aby bylo mo¾né èíst dal¹í vìtu.
        $spravne_strom = 0;
        $spatne_strom = 0;
    }
}



#------------------------------------------------------------------------------
# Naète statistický model závislostí na urèitých datech (napø. na znaèkách).
#------------------------------------------------------------------------------
sub cist_statistiku
{
    my $soubor = $_[0];
    my $statref = $_[1];
    open(STAT, $soubor);
    vypsat("prubeh", "Ète se statistika $soubor [");
    my $oznameno = 0;
    my %cuzl;
    my $celkem = 0;
    while(<STAT>)
    {
        chomp;
        m/(.*)\t(\d+)/;
        my $k = $1;
        my $c = $2;
        my $udalost = $k;
        $statref->{$udalost} = $c;
        # Pøièíst i do celkového poètu v¹ech událostí (jmenovatel).
        $celkem += $c;
        # Bohu¾el se musím alespoò doèasnì uchýlit k neèistému programování.
        # Nìkteré události je vhodné ukládat v jiném tvaru, a vzhledem
        # k obrovskému celkovému poètu událostí je nejefektivnìj¹í provádìt
        # úpravy u¾ tady.
        if($udalost =~ m/^VET (\S+) (\S+)/)
        {
            my $vzor = $1;
            my $strom = $2;
            # V evidenci lze ke ka¾dé dvojici vzor vìty - strom nalézt èetnost.
            # My chceme ke ka¾dému vzoru vìty znát právì jeden strom, a to ten
            # s nejvìt¹í èetností.
            if($c>$vzorstrom{$vzor}{cetnost})
            {
                $vzorstrom{$vzor}{strom} = $strom;
                $vzorstrom{$vzor}{cetnost} = $c;
                $vzorstrom{$vzor}{celkem} += $c;
            }
        }
        # Oznámit pokrok ve ètení.
        if($celkem>=$oznameno+10000)
        {
            vypsat("prubeh", ".");
            $oznameno = $celkem;
        }
    }
    close(STAT);
    vypsat("prubeh", "]\n");
    return $celkem;
}



#------------------------------------------------------------------------------
# Ovìøí shodu závislostí ve stromì se závislostmi ve vzorovém stromì.
#------------------------------------------------------------------------------
sub zkontrolovat_strom
{
    my $stav = shift; # odkaz na koncový stav analýzy
    my $navrh = $stav->{rodic};
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    #
    my $spravne_strom = 0;
    my $spatne_strom = 0;
    # Pravdìpodobnosti celých stromù pomù¾ou vyhodnotit, zda by nìco dokázal backtracking.
    my $pstrom_vzor = 1;
    my $pstrom_navrh = 1;
    # Projít vìtu a porovnávat navrhované závislosti se vzorovými.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        my $z = $i; # index závislého uzlu
        my $rvzo = $anot->[$i]{rodic_vzor}; # index øídícího uzlu podle vzorové anotace
        my $rnav = $navrh->[$i]; # index øídícího uzlu navr¾ený parserem
        # Pøidat pravdìpodobnost závislosti do pravdìpodobnosti stromu.
        my ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($rvzo, $z);
        if($c==0)
        {
            $nuly_vzor++;
        }
        $pstrom_vzor *= $p;
        ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($rnav, $z);
        if($c==0)
        {
            $nuly_navrh++;
        }
        $pstrom_navrh *= $p;
        # Porovnat navr¾enou závislost se vzorovou.
        if($rnav==$rvzo)
        {
            $spravne++;
            $spravne_strom++;
            if($stav->{maxc}[$i]>=5)
            {
                $jiste_spravne++;
            }
            elsif($stav->{maxc}[$i]>0)
            {
                $nejiste_spravne++;
            }
            else
            {
                $vynechano_spravne++;
            }
            if($anot->[$i]{afun}=~m/^($konfig->{"testafun"})$/)
            {
                $vyber_spravne++;
            }
        }
        else
        {
            $spatne++;
            $spatne_strom++;
            if($stav->{maxc}>=5)
            {
                $jiste_spatne++;
            }
            elsif($stav->{maxc}>0)
            {
                $nejiste_spatne++;
            }
            else
            {
                $vynechano_spatne++;
            }
            if($anot->[$i]{afun}=~m/^($konfig->{"testafun"})$/)
            {
                $vyber_spatne++;
            }
        }
    }
    if($pstrom_vzor>$pstrom_navrh)
    {
        $vzor_lepsi_nez_navrh++;
    }
    elsif($pstrom_vzor<$pstrom_navrh)
    {
        $vzor_horsi_nez_navrh++;
    }
    else
    {
        $vzor_stejny_jako_navrh++;
    }
    my $celkem_strom = $spravne_strom+$spatne_strom;
    my $uspesnost_strom;
    if($celkem_strom>0)
    {
        $uspesnost_strom = $spravne_strom/$celkem_strom;
    }
    if($uspesnost_strom==1)
    {
        $stovky++;
        if($celkem_strom>$stovky_max)
        {
            $stovky_max = $celkem_strom;
        }
        $stovky_sum += $celkem_strom;
    }
    # Do hlá¹ení na standardní výstup vypsat úspì¹nost analýzy této vìty.
    my $celkova_uspesnost = $spravne+$spatne>0 ? $spravne/($spravne+$spatne) : 0;
    vypsat("prubeh", sprintf(" %3d %% %3d %% (%2d/%2d) $anot->[1]{slovo} $anot->[2]{slovo} $anot->[3]{slovo}\n", $celkova_uspesnost*100, $uspesnost_strom*100, $spravne_strom, $celkem_strom));
#    vypsat("prubeh",
#    sprintf(" %3d %% (%2d/%2d) $anot->[1]{slovo} $anot->[2]{slovo} $anot->[3]{slovo}\n",
#    $uspesnost_strom*100, $spravne_strom, $celkem_strom));
    # Zapamatovat si oddìlenì úspì¹nost na vìtách rùzné délky.
    $spravne[$#{$anot}] += $spravne_strom;
    $celkem[$#{$anot}] += $spravne_strom+$spatne_strom;
}



#------------------------------------------------------------------------------
# Vypí¹e na výstup ve formátu CSTS dva stromy, které zavìsí pod jeden koøen.
# Díky tomu bude mo¾né si je v prohlí¾eèi zobrazit vedle sebe a porovnávat.
#------------------------------------------------------------------------------
sub vypsat_dvojstrom
{
    return if(!$dbglog);
    my $i;
    vypsat("debug.csts", "<s id=\"$a\">\n");
    my $pvzor = 1;
    for($i = 0; $i<=$#_; $i++)
    {
        if($i==0 || $i==$#_/2+0.5)
        {
            my $uspesnost;
            if($i==0)
            {
                $uspesnost = "VZOR";
            }
            else
            {
                $uspesnost = sprintf("%d/%d=%d%%", $spravne_strom, $celkem_strom, $uspesnost_strom*100);
            }
            vypsat("debug.csts", "<f>$uspesnost<r>".($i+1)."<g>0\n");
        }
        elsif($i<$#_/2)
        {
            my ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($_[$i], $i);
            $pvzor *= $p;
            $p = sprintf("%.3f", -log($p)/log(10)) unless($p==0);
            vypsat("debug.csts", "<f>$anot->[$i]{slovo}<l>$p<t>$anot->[$i]{znacka}<r>".($i+1)."<g>".($_[$i]+1)."\n");
        }
        else
        {
            my $p = sprintf("%s: %.3f", $pord[$i-$#_/2-0.5], -log($maxp[$i-$#_/2-0.5])/log(10)) unless($maxp[$i-$#_/2-0.5]==0);
            vypsat("debug.csts", "<f>$anot->[$i-$#_/2-0.5]{slovo}<l>$p<t>$anot->[$i-$#_/2-0.5]{znacka}<r>".($i+1)."<g>".($_[$i]+$#_/2+1.5)."\n");
        }
    }
    vypsat("debug.csts", "<pravdepodobnost wvz=\"$pvzor\" wan=\"$pstrom\">\n");
}



#------------------------------------------------------------------------------
# Vypí¹e výsledný strom na standardní výstup.
#------------------------------------------------------------------------------
sub vypsat_strom
{
    my $vetid = shift; # identifikátor vìty (opsat ze vstupu, nevymý¹let si vlastní)
    my $strom = shift; # odkaz na pole indexù rodièù uzlù
    # Zatím globální promìnné.
    my $anot = \@main::anot;
    vypsat("csts", "<s id=\"$vetid\" w=\"$pstrom\">\n");
    for(my $i = 1; $i<=$#{$strom}; $i++)
    {
        my $uzel = "<f>$anot->[$i]{slovo}";
        $uzel .= "<l>$anot->[$i]{heslo}";
        $uzel .= "<t>$anot->[$i]{znacka}";
        $uzel .= "<r>$i";
        $uzel .= "<g>$anot->[$i]{rodic_vzor}";
        $uzel .= "<MDg src=\"dz\">$strom->[$i]";
        vypsat("csts", "$uzel\n");
    }
}
