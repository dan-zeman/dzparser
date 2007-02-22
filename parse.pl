#!/usr/bin/perl
# Na�te natr�novan� statistiky a s jejich pomoc� analyzuje v�ty na vstupu.
# Anal�zy nikam nevypisuje, m�sto toho je rovnou porovn�v� se vzorov�mi
# a po��t� si �sp�nost.
use debug;
use parse;
use csts;
use vystupy;
use rozebrat; # sub rozebrat_vetu
use model; # kv�li sub zjistit_nezkreslenou_pravdepodobnost()
use krvety;
use ntice;
use subkat;
use nepreskocv;
use plodnost;
use povol;



$starttime = time();
parse::precist_konfig("parser.ini", \%konfig);



# Na��st natr�novan� statistiky.
# V�choz�: naj�t v pracovn�m adres��i soubor s nejvy���m ��slem.
if($konfig{stat} eq "")
{
    opendir(DIR, $konfig{prac}) or die("Nelze otev��t pracovn� slo�ku $konfig{prac}: $!\n");
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
    vypsat("konfig", "Pou�ita statistika $konfig{prac}/$konfig{stat}.\n");
    # Pokud najdeme z�znam konfigurace, pod kterou statistika vznikla, opsat ji do na�� konfigurace.
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
    or die("Chyba: pr�zdn� statistika");
$ls = $konfig{"ls"};
$lz = 1-$ls;
# Je mo�n� na��st i druhou statistiku a porovn�vat, jak se m�n� �sp�nost
# anal�zy p�i pou�it� jedn� �i druh�. Voliteln� statistika je stat1, z�kladn�
# je stat.
if($konfig{stat1})
{
    cist_statistiku($konfig{prac}."/".$konfig{stat1}, \%stat1);
}



# Na��st seznam subkategoriza�n�ch r�mc� sloves.
if($konfig{valence} || $konfig{valence1})
{
    $konfig{nacteny_subkategorizacni_slovnik} = subkat::cist($konfig{subcat}); # vr�t� odkaz na hash se subkategoriza�n�m slovn�kem
}



# Na��st seznam z�kaz� p�esko�en� slovesa ur�itou z�vislost�.
if($konfig{nepreskocv})
{
    $konfig{nacteny_seznam_zakazu_preskoceni_slovesa} = nepreskocv::cist($konfig{nepreskocv_cesta}); # vr�t� odkaz na hash
}



# Na��st model plodnosti.
if($konfig{plodnost})
{
    if($konfig{plodnost_model} eq "ffm")
    {
        plodnost::pripravit_ffm(\%stat);
    }
    else
    {
        plodnost::cist($konfig{plodnost_cesta}); # plodnost_cesta se zat�m nezohled�uje, �te se natvrdo plodnost.txt
    }
}



# Na��st pom�cky pro model neprojektivit.
if($konfig{neproj})
{
    povol::cist_rematizatory();
}



# Na��st vzory n-tic.
if($konfig{ntice})
{
    $ntice = ntice::cist("ntice.txt");
}



# ��st testovac� v�ty a analyzovat je.

vypsat("csts", "<csts lang=cs><h><source>PDT</source></h><doc file=\"$konfig{analyza}\" id=\"1\"><a><mod>s<txtype>pub<genre>mix<med>nws<temp>1994<authname>y<opus>ln94206<id>3</a><c><p n=\"1\">\n");

$konfig{hook_zacatek_cteni} = sub
{
    my $maska = shift;
    my $soubory = shift;
    vypsat("prubeh", "Maska pro jm�na soubor� s daty: $maska\n");
    vypsat("prubeh", "Nalezeno ".($#{$soubory}+1)." soubor�.\n");
};
csts::projit_data($konfig{test}, \%konfig);

vypsat("csts", "</c></doc></csts>\n");



# Vytisknout v�sledky srovn�n�.
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
vypsat("vysledky", "$vzor_lepsi_nez_navrh� m�l vzorov� strom VY��� pravd�podobnost ne� navrhovan�.\n");
vypsat("vysledky", "$vzor_horsi_nez_navrh� m�l vzorov� strom NI��� pravd�podobnost ne� navrhovan�.\n");
vypsat("vysledky", "$vzor_stejny_jako_navrh� m�l vzorov� strom STEJNOU pravd�podobnost jako navrhovan�.\n");
vypsat("vysledky", "Vybr�no $nuly_navrh/$nuly_vzor z�vislost� s nulovou pravd�podobnost�.\n");
vypsat("vysledky", ntice::vytvorit_hlaseni()) if($konfig{ntice});



$stoptime = time();
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "konfig");
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "vysledky");



###############################################################################
# PODPROGRAMY
###############################################################################



#------------------------------------------------------------------------------
# Analyzuje v�tu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s �daji o aktu�ln�m dokumentu, odstavci a v�t�
    my $anot = shift; # pole hash� o jednotliv�ch slovech
    @anot = @{$anot}; # zat�m se ukl�d� jako glob�ln� prom�nn� v main
    if(!$vynechat_vetu)
    {
        $veta++;
        # Lad�c� v�pisy.
        my ($sek, $min, $hod) = localtime(time());
        my $jmeno_souboru_do_hlaseni = $stav_cteni->{soubor};
        $jmeno_souboru_do_hlaseni =~ s-^.*/([^/]*)$-$1-;
        $jmeno_souboru_do_hlaseni =~ s/\.(?:csts|amm)$//i;
        vypsat("prubeh", parse::cas()." $jmeno_souboru_do_hlaseni Analyzuje se veta $veta ...");
        # Povolit lad�c� v�pisy jen u prvn�ch 50 v�t.
        $dbglog = $veta<=50;
        ###############################################
        # TADY ZA��N� VLASTN� ANAL�ZA.
        ###############################################
        my $stav; # v�stup parseru: krom� vlastn� stromov� struktury obsahuje i v�hy a jin� dopl�kov� informace
        # Ke kr�tk�m v�t�m m�me k dispozici cel� stromy.
        if($#{$anot}<=8 && $konfig{krvety})
        {
            $stav = krvety::rozebrat(\%vzorstrom);
        }
        # Ostatn� v�ty rozebrat klasicky p�kn� slovo za slovem.
        else
        {
            # Rozebrat v�tu pomoc� statistick�ho modelu z�vislost� dvou slov na sob�.
            $stav = rozebrat::rozebrat_vetu();
            if($konfig{ntice})
            {
                # Na z�v�r opravit n�kter� chyby pomoc� modelu n-tic.
                # N-tice klidn� mohou pou��vat upraven� morfologick� zna�ky z pole
                # @anot, proto�e te� u� se do nich neprom�t� d�d�n� v r�mci koordinace.
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
                # Po zhodnocen� vlivu n-tic ulo�it jimi ovlivn�n� strom na
                # v�stup, aby se po��tala jeho celkov� �sp�nost.
                $stav->{rodic} = \@ana1;
            }
        }
        # Spo��tat chyby.
        zkontrolovat_strom($stav);
        # Vypsat v�sledn� strom.
        vypsat_strom($stav_cteni->{vetid}, $stav->{rodic});
        # Vymazat prom�nn�, aby bylo mo�n� ��st dal�� v�tu.
        $spravne_strom = 0;
        $spatne_strom = 0;
    }
}



#------------------------------------------------------------------------------
# Na�te statistick� model z�vislost� na ur�it�ch datech (nap�. na zna�k�ch).
#------------------------------------------------------------------------------
sub cist_statistiku
{
    my $soubor = $_[0];
    my $statref = $_[1];
    open(STAT, $soubor);
    vypsat("prubeh", "�te se statistika $soubor [");
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
        # P�i��st i do celkov�ho po�tu v�ech ud�lost� (jmenovatel).
        $celkem += $c;
        # Bohu�el se mus�m alespo� do�asn� uch�lit k ne�ist�mu programov�n�.
        # N�kter� ud�losti je vhodn� ukl�dat v jin�m tvaru, a vzhledem
        # k obrovsk�mu celkov�mu po�tu ud�lost� je nejefektivn�j�� prov�d�t
        # �pravy u� tady.
        if($udalost =~ m/^VET (\S+) (\S+)/)
        {
            my $vzor = $1;
            my $strom = $2;
            # V evidenci lze ke ka�d� dvojici vzor v�ty - strom nal�zt �etnost.
            # My chceme ke ka�d�mu vzoru v�ty zn�t pr�v� jeden strom, a to ten
            # s nejv�t�� �etnost�.
            if($c>$vzorstrom{$vzor}{cetnost})
            {
                $vzorstrom{$vzor}{strom} = $strom;
                $vzorstrom{$vzor}{cetnost} = $c;
                $vzorstrom{$vzor}{celkem} += $c;
            }
        }
        # Ozn�mit pokrok ve �ten�.
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
# Ov��� shodu z�vislost� ve strom� se z�vislostmi ve vzorov�m strom�.
#------------------------------------------------------------------------------
sub zkontrolovat_strom
{
    my $stav = shift; # odkaz na koncov� stav anal�zy
    my $navrh = $stav->{rodic};
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    #
    my $spravne_strom = 0;
    my $spatne_strom = 0;
    # Pravd�podobnosti cel�ch strom� pom��ou vyhodnotit, zda by n�co dok�zal backtracking.
    my $pstrom_vzor = 1;
    my $pstrom_navrh = 1;
    # Proj�t v�tu a porovn�vat navrhovan� z�vislosti se vzorov�mi.
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        my $z = $i; # index z�visl�ho uzlu
        my $rvzo = $anot->[$i]{rodic_vzor}; # index ��d�c�ho uzlu podle vzorov� anotace
        my $rnav = $navrh->[$i]; # index ��d�c�ho uzlu navr�en� parserem
        # P�idat pravd�podobnost z�vislosti do pravd�podobnosti stromu.
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
        # Porovnat navr�enou z�vislost se vzorovou.
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
    # Do hl�en� na standardn� v�stup vypsat �sp�nost anal�zy t�to v�ty.
    my $celkova_uspesnost = $spravne+$spatne>0 ? $spravne/($spravne+$spatne) : 0;
    vypsat("prubeh", sprintf(" %3d %% %3d %% (%2d/%2d) $anot->[1]{slovo} $anot->[2]{slovo} $anot->[3]{slovo}\n", $celkova_uspesnost*100, $uspesnost_strom*100, $spravne_strom, $celkem_strom));
#    vypsat("prubeh",
#    sprintf(" %3d %% (%2d/%2d) $anot->[1]{slovo} $anot->[2]{slovo} $anot->[3]{slovo}\n",
#    $uspesnost_strom*100, $spravne_strom, $celkem_strom));
    # Zapamatovat si odd�len� �sp�nost na v�t�ch r�zn� d�lky.
    $spravne[$#{$anot}] += $spravne_strom;
    $celkem[$#{$anot}] += $spravne_strom+$spatne_strom;
}



#------------------------------------------------------------------------------
# Vyp�e na v�stup ve form�tu CSTS dva stromy, kter� zav�s� pod jeden ko�en.
# D�ky tomu bude mo�n� si je v prohl�e�i zobrazit vedle sebe a porovn�vat.
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
# Vyp�e v�sledn� strom na standardn� v�stup.
#------------------------------------------------------------------------------
sub vypsat_strom
{
    my $vetid = shift; # identifik�tor v�ty (opsat ze vstupu, nevym��let si vlastn�)
    my $strom = shift; # odkaz na pole index� rodi�� uzl�
    # Zat�m glob�ln� prom�nn�.
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
