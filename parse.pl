#!/usr/bin/perl
# Načte natrénované statistiky a s jejich pomocí analyzuje věty na vstupu.
# Analýzy nikam nevypisuje, místo toho je rovnou porovnává se vzorovými
# a počítá si úspěšnost.
# (c) 1995-2007 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Licence: GNU GPL

sub usage
{
    print STDERR ("Usage: parse.pl [-i config] [-m model] < input > output\n");
    print STDERR ("  config: path to configuration file\n");
    print STDERR ("  model:  path to trained model\n");
    print STDERR ("  input:  CSTS file to parse\n");
    print STDERR ("  output: parsed CSTS file\n");
}

use utf8;
use Getopt::Long;
use debug;
use parse;
use csts;
use vystupy;
use rozebrat; # sub rozebrat_vetu
use model; # kvůli sub zjistit_nezkreslenou_pravdepodobnost()
use krvety;
use ntice;
use subkat;
use nepreskocv;
use plodnost;
use povol;
use vyhodnoceni;



$starttime = time();
my $inisoubor = "parser.ini"; # jméno souboru s konfigurací
# parse.pl --i parser2.ini
GetOptions('model=s' => \$model, 'ini=s' => \$inisoubor);
parse::precist_konfig($inisoubor, \%konfig);
if($model ne "")
{
    $konfig{stat} = $model;
}
# Nastavit, který výstup půjde na STDOUT. Ostatní půjdou na STDERR.
$vystupy::vystupy{csts}{stdout} = 1;



# Načíst natrénované statistiky.
# Výchozí: najít v pracovním adresáři soubor s nejvyšším číslem.
if($konfig{stat} eq "")
{
    opendir(DIR, $konfig{prac}) or die("Nelze otevřít pracovní složku $konfig{prac}: $!\n");
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
    $konfig{stat} = "$konfig{prac}/$maxstat.stat";
    vypsat("konfig", "Použita statistika $konfig{stat}.\n");
    # Pokud najdeme záznam konfigurace, pod kterou statistika vznikla, opsat ji do naší konfigurace.
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
cist_statistiku($konfig{stat}, \%stat, $konfig{kodovani_data}) or die("Chyba: prázdná statistika");
$ls = $konfig{"ls"};
$lz = 1-$ls;
# Je možné načíst i druhou statistiku a porovnávat, jak se mění úspěšnost
# analýzy při použití jedné či druhé. Volitelná statistika je stat1, základní
# je stat.
if($konfig{stat1})
{
    cist_statistiku($konfig{prac}."/".$konfig{stat1}, \%stat1, $konfig{kodovani_data});
}



# Načíst seznam subkategorizačních rámců sloves.
if($konfig{valence} || $konfig{valence1})
{
    $konfig{nacteny_subkategorizacni_slovnik} = subkat::cist($konfig{subcat}); # vrátí odkaz na hash se subkategorizačním slovníkem
}



# Načíst seznam zákazů přeskočení slovesa určitou závislostí.
if($konfig{nepreskocv})
{
    $konfig{nacteny_seznam_zakazu_preskoceni_slovesa} = nepreskocv::cist($konfig{nepreskocv_cesta}); # vrátí odkaz na hash
}



# Načíst model plodnosti.
if($konfig{plodnost})
{
    if($konfig{plodnost_model} eq "ffm")
    {
        plodnost::pripravit_ffm(\%stat);
    }
    else
    {
        plodnost::cist($konfig{plodnost_cesta}); # plodnost_cesta se zatím nezohledňuje, čte se natvrdo plodnost.txt
    }
}



# Načíst pomůcky pro model neprojektivit.
if($konfig{neproj})
{
    povol::cist_rematizatory();
}



# Načíst vzory n-tic.
if($konfig{ntice})
{
    $ntice = ntice::cist_ze_stat(\%stat);
}



# Číst testovací věty a analyzovat je.

vypsat("csts", "<csts lang=cs><h><source>PDT</source></h><doc file=\"dz-parser-output\" id=\"1\"><a><mod>s<txtype>pub<genre>mix<med>nws<temp>1994<authname>y<opus>ln94206<id>3</a><c><p n=\"1\">\n");

$konfig{hook_zacatek_cteni} = sub
{
    my $maska = shift;
    my $soubory = shift;
    vypsat("prubeh", "Maska pro jména souborů s daty: $maska\n");
    vypsat("prubeh", "Nalezeno ".($#{$soubory}+1)." souborů.\n");
};
csts::projit_data($konfig{test}, \%konfig);

vypsat("csts", "</c></doc></csts>\n");



if($vystupy::cislo_instance)
{
    my $g = $hodnoceni{spravne};
    my $p = $g/($g+$hodnoceni{spatne});
    my $predmet = sprintf("Parsing $vystupy::cislo_instance skoncil: %4.1f %% (G $g)", $p*100);
    vystupy::kopirovat_do_mailu("vysledky", $predmet);
}
vyhodnoceni::vypsat(\%hodnoceni);
$stoptime = time();
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "konfig");
parse::vypsat_delku_trvani_programu($starttime, $stoptime, "vysledky");



###############################################################################
# PODPROGRAMY
###############################################################################



#------------------------------------------------------------------------------
# Analyzuje větu.
#------------------------------------------------------------------------------
sub zpracovat_vetu
{
    my $stav_cteni = shift; # hash s údaji o aktuálním dokumentu, odstavci a větě
    my $anot = shift; # pole hashů o jednotlivých slovech
    # Vynechat prázdné věty a věty splňující zvláštní podmínky.
    # Za prázdnou se považuje i věta, která obsahuje pouze 1 prvek (kořen).
    if(scalar(@{$anot})>1 && !$vynechat_vetu)
    {
        $veta++;
        # Ladící výpisy.
        my ($sek, $min, $hod) = localtime(time());
        my $jmeno_souboru_do_hlaseni = $stav_cteni->{soubor};
        $jmeno_souboru_do_hlaseni =~ s-^.*/([^/]*)$-$1-;
        $jmeno_souboru_do_hlaseni =~ s/\.(?:csts|amm)$//i;
        my $n_slov = scalar(@{$anot});
        vypsat("prubeh", parse::cas()." $jmeno_souboru_do_hlaseni Analyzuje se věta $veta (", sprintf("%3d", $n_slov), ") ...");
        # Povolit ladící výpisy jen u prvních 50 vět.
        $dbglog = $veta<=50;
        ###############################################
        # TADY ZAČÍNÁ VLASTNÍ ANALÝZA.
        ###############################################
        my $stav; # výstup parseru: kromě vlastní stromové struktury obsahuje i váhy a jiné doplňkové informace
        # Ke krátkým větám máme k dispozici celé stromy.
        if($#{$anot}<=8 && $konfig{krvety})
        {
            $stav = krvety::rozebrat($anot, \%vzorstrom);
        }
        # Ostatní věty rozebrat klasicky pěkně slovo za slovem.
        else
        {
            # Rozebrat větu pomocí statistického modelu závislostí dvou slov na sobě.
            $stav = rozebrat::rozebrat_vetu($anot);
            if($konfig{ntice})
            {
                # Na závěr opravit některé chyby pomocí modelu n-tic.
                # N-tice klidně mohou používat upravené morfologické značky z pole
                # @anot, protože teď už se do nich nepromítá dědění v rámci koordinace.
                my $rozbor_ntice = ntice::nasadit($ntice, $anot);
                my @ana1 = @{$stav->{rodic}};
                for(my $i = 0; $i<=$#ana1; $i++)
                {
                    if($rozbor_ntice->[$i] ne "" && $rozbor_ntice->[$i]!=-1)
                    {
                        $ana1[$i] = $rozbor_ntice->[$i];
                    }
                }
                my @vzor = map{$_->{rodic_vzor}}(@{$anot});
                ntice::zhodnotit(\@vzor, $stav->{rodic}, \@ana1, $rozbor_ntice);
                # Po zhodnocení vlivu n-tic uložit jimi ovlivněný strom na
                # výstup, aby se počítala jeho celková úspěšnost.
                $stav->{rodic} = \@ana1;
            }
        }
        # Spočítat chyby.
        vyhodnoceni::zkontrolovat_strom($anot, $stav, \%hodnoceni);
        # Do hlášení na standardní výstup vypsat úspěšnost analýzy této věty.
        my $celkova_uspesnost = $hodnoceni{spravne}+$hodnoceni{spatne}>0 ? $hodnoceni{spravne}/($hodnoceni{spravne}+$hodnoceni{spatne}) : 0;
        vypsat("prubeh", sprintf(" %3d %% %3d %% (%2d/%2d) $anot->[1]{slovo} $anot->[2]{slovo} $anot->[3]{slovo}\n", $celkova_uspesnost*100, $hodnoceni{uspesnost_posledni_strom}*100, $hodnoceni{spravne_posledni_strom}, $hodnoceni{celkem_posledni_strom}));
        # Vypsat výsledný strom.
        vypsat_strom($anot, $stav_cteni->{vetid}, $stav->{rodic});
        # Vymazat proměnné, aby bylo možné číst další větu.
        $spravne_strom = 0;
        $spatne_strom = 0;
    }
}



#------------------------------------------------------------------------------
# Načte statistický model závislostí na určitých datech (např. na značkách).
#------------------------------------------------------------------------------
sub cist_statistiku
{
    my $soubor = shift; # odkud číst
    my $statref = shift; # kam uložit
    my $kodovani = shift; # z jakého kódování dekódovat
    open(STAT, $soubor);
    if($kodovani)
    {
        binmode(STAT, ":encoding($kodovani)");
    }
    vypsat("prubeh", "Čte se statistika $soubor [");
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
        # Přičíst i do celkového počtu všech událostí (jmenovatel).
        $celkem += $c;
        # Bohužel se musím alespoň dočasně uchýlit k nečistému programování.
        # Některé události je vhodné ukládat v jiném tvaru, a vzhledem
        # k obrovskému celkovému počtu událostí je nejefektivnější provádět
        # úpravy už tady.
        if($udalost =~ m/^VET (\S+) (\S+)/)
        {
            my $vzor = $1;
            my $strom = $2;
            # V evidenci lze ke každé dvojici vzor věty - strom nalézt četnost.
            # My chceme ke každému vzoru věty znát právě jeden strom, a to ten
            # s největší četností.
            if($c>$vzorstrom{$vzor}{cetnost})
            {
                $vzorstrom{$vzor}{strom} = $strom;
                $vzorstrom{$vzor}{cetnost} = $c;
            }
            $vzorstrom{$vzor}{celkem} += $c;
        }
        # Oznámit pokrok ve čtení.
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
# Vypíše výsledný strom na standardní výstup.
#------------------------------------------------------------------------------
sub vypsat_strom
{
    my $anot = shift; # odkaz na pole hashů
    my $vetid = shift; # identifikátor věty (opsat ze vstupu, nevymýšlet si vlastní)
    my $strom = shift; # odkaz na pole indexů rodičů uzlů
    # Zatím globální proměnné.
    vypsat("csts", "<s id=\"$vetid\" w=\"$pstrom\">\n");
    for(my $i = 1; $i<=$#{$strom}; $i++)
    {
        my %uzel;
        foreach my $atribut (qw(form lemma znacka afun))
        {
            $uzel{$atribut} = $anot->[$i]{$atribut};
            # Zakódovat znaky, které mají v CSTS zvláštní význam.
            $uzel{$atribut} =~ s/&/&amp;/g;
            $uzel{$atribut} =~ s/</&lt;/g;
            $uzel{$atribut} =~ s/>/&gt;/g;
        }
        my $uzel = "<f>$uzel{form}";
        $uzel .= "<l>$uzel{lemma}";
        $uzel .= "<t>$uzel{znacka}";
        $uzel .= "<r>$i";
        $uzel .= "<g>$anot->[$i]{rodic_vzor}";
        $uzel .= "<A>$uzel{afun}";
        $uzel .= "<MDg src=\"dz\">$strom->[$i]";
        vypsat("csts", "$uzel\n");
    }
}
