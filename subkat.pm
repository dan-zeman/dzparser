# Funkce související se subkategorizací sloves.
package subkat;
use utf8;
use model;



#------------------------------------------------------------------------------
# Načte seznam subkategorizačních rámců sloves.
#------------------------------------------------------------------------------
sub cist
{
    my $jmeno_souboru = shift;
    my %subcat; # výstupní hash (subkategorizační slovník)
    open(SUBCAT, $jmeno_souboru) or die("Nelze otevrit soubor $jmeno_souboru se seznamem ramcu: $!\n");
    binmode(SUBCAT, ":encoding(iso-8859-2)");
    while(<SUBCAT>)
    {
        chomp;
        # Na řádku je nejdříve sloveso, pak dvě (?) mezery, pak rámec.
        # Rámec mezery neobsahuje. Členy jsou odděleny dvěma vlnovkami.
        # Prázdný rámec nepřechodných sloves je zastoupen značkou <INTR>.
        if(m/(.+?)\s+(.+)$/)
        {
            my $sloveso = $1;
            next if($sloveso eq "být");
            my $ramec = $2;
            # Rozdělit rámce na jednotlivé vazby.
            my @vazby = split(/~~/, $ramec);
            for(my $i = 0; $i<=$#vazby; $i++)
            {
                # Vazba se skládá ze subkategorizační značky a
                # z analytické funkce (s-značky), oddělené jsou
                # lomítkem. Odstranit lomítko a s-značku.
                $vazby[$i] =~ s-/.*--;
                $subcat{"$sloveso $vazby[$i]"}++;
            }
            # Zapamatovat si, že sloveso je slovníkem vůbec nějak pokryto.
            $subcat{"SLO $sloveso"}++;
            # Zapamatovat si celý rámec slovesa (výše jsme si pamatovali jen jednotlivé
            # vazby) tak, aby bylo možné najít všechny rámce určitého slovesa.
            push(@{$subcat{"RAM $sloveso"}}, "$sloveso $ramec");
        }
    }
    close(SUBCAT);
    return \%subcat;
}



#------------------------------------------------------------------------------
# Převede (neredukovanou) morfologickou značku na subkategorizační.
#------------------------------------------------------------------------------
sub prevest_mznacku_na_vazbu
{
    my $mznacka = $_[0];
    my $heslo = $_[1];
    # Základem vazby je slovní druh. Podstatná jména, přídavná jména, zájmena
    # a číslovky však považujeme za jediný slovní druh. Výjimkou jsou určité
    # výskyty zvratných zájmen "se" a "si" (vlastně jen ty, v nichž vystupují
    # jako zvratné částice. Nikdy však nemají morfologickou značku částice.
    my $vazba = substr($mznacka, 0, 1);
    if($vazba eq "P" && $heslo =~ m/^(se|si)/)
    {
        $vazba = PR;
    }
    else
    {
        $vazba =~ s/[APC]/N/;
    }
    # Přes podřadící spojky visí na slovesech závislé klauze (že, aby...)
    if(substr($mznacka, 0, 2) eq "J,")
    {
        $vazba = "JS";
    }
    # Pokud visí na slovese jiné určité sloveso, jde o klauzi (který...)
    # nebo o přímou řeč.
    if($mznacka =~ m/^V[^f]/)
    {
        $vazba = "S";
    }
    # Pokud visí na slovese infinitiv, chceme to vyjádřit zřetelněji.
    if(substr($mznacka, 0, 2) eq "Vf")
    {
        $vazba = "VINF";
    }
    # Příslovce byla značena DB (i pokud jejich m-značka je Dg).
    if($vazba eq "D")
    {
        $vazba = "DB";
    }
    # Je-li relevantní pád, přidat ho (může nastat u výše uvedených a u
    # předložek.
    my $pad = substr($mznacka, 4, 1);
    if($pad ne "-")
    {
        $vazba .= $pad;
    }
    # U předložek a podřadících spojek přidat do závorky heslo.
    # Totéž platí i o slovech "jak" a "proč", která jsou sice ve slovníku
    # vedena jako příslovce, ale anotátoři je občas pověsili jako AuxC.
    # Kvůli této nekonzistenci se tu musí objevit jazykově závislý seznam.
    if($vazba =~ m/^(R|JS)/ ||
    $vazba eq "DB" && $heslo =~ m/^(jak|proč)(?:[-_].*)?$/)
    {
        # Z hesla odstranit případné rozlišení významů za pomlčkou.
        $heslo =~ s/-.*//;
        $vazba .= "($heslo)";
    }
    return $vazba;
}



#------------------------------------------------------------------------------
# Vytipuje valenční závislosti ve větě. Volá se před vlastní analýzou věty.
# Vrací pole @valencni, jehož prvek má tvar $r-$z($p), r a z jsou indexy
# řídícího a závislého uzlu a p je pravděpodobnost takové závislosti (podle
# normálního modelu, nemá zatím nic společného s pravděpodobností použitého
# rámce).
#------------------------------------------------------------------------------
sub vytipovat_valencni_zavislosti
{
    my $anot = shift; # odkaz na pole hashů
    my $subcat = shift; # odkaz na hash se subkategorizačním slovníkem
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Zjistit, které potenciální závislosti ve větě by mohly být valenční.
    my @valencni;
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{uznacka}=~m/^V/)
        {
            # Pro každé sloveso projít všechny ostatní uzly a zkoumat,
            # jestli by mohly být jeho vazbami.
            for(my $j = 0; $j<=$#{$anot}; $j++)
            {
                if($j!=$i)
                {
                    my $zn = $anot->[$j]{uznacka};
                    $zn =~ s/P(\d)/N$1/;
                    $zn =~ s/V([Bp]|jsem|jsi|je|ní|jsme|jste|jsou|budu|budeš|bude|budeme|budete|budou|byl[aoiy]?)/S/;
                    $zn =~ s/V(f|být)/VINF/;
                    $zn =~ s/Pse(s)?/PR4/;
                    $zn =~ s/Psi(s)?/PR3/;
                    $zn =~ s/Db/DB/;
                    # Předložky se konvertují při načítání valencí,
                    # protože tady neznáme jejich pád.
                    $zn =~ s/J(,|že|aby|zda)/JS($anot->[$j]{slovo})/;
                jeste_jako_n:
                    if(exists($subcat->{"$anot->[$i]{heslo} $zn"}))
                    {
                        # Závislost i-j by mohla být valenční.
                        # Zjistit její pravděpodobnost.
                        my ($p, $c) = model::zjistit_nezkreslenou_pravdepodobnost($anot, $i, $j);
                        push(@valencni, "$i-$j($p)");
                    }
                    elsif($zn=~s/^PR/N/)
                    {
                        goto jeste_jako_n;
                    }
                }
            }
        }
    }
    # Setřídit seznam potenciálních valenčních závislostí v této větě sestupně podle pravděpodobnosti.
    @valencni = sort
    {
        $a =~ m/(\d+)-(\d+)\((.*)\)/;
        my $ap = $3;
        my $ad = abs($1-$2);
        $b =~ m/(\d+)-(\d+)\((.*)\)/;
        my $bp = $3;
        my $bd = abs($1-$2);
        if($ap!=$bp)
        {
            return $bp<=>$ap;
        }
        else
        {
            return $bd<=>$ad;
        }
    }
    (@valencni);
    return \@valencni;
}



#------------------------------------------------------------------------------
# Projde strom vytvořený parserem a pokusí se najít slovesa, kterým chybí
# nějaký argument. Pokud taková najde a pokud navíc zjistí, že ve větě existuje
# materiál, kterým by rámce mohly jít naplnit, vrátí 1. Jinak vrátí 0.
#------------------------------------------------------------------------------
sub najit_nenaplnene_ramce
{
    my $anot = shift;
    my $subcat = shift; # odkaz na hash se subkategorizačním slovníkem
    my $stav = shift; # odkaz na hash se stavem analýzy (obsahuje mj. návrh stromu)
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Najít slovesa.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zajímají nás pouze slovesa pokrytá subkategorizačním slovníkem.
        # Nezajímají nás, pokud jsou v příčestí trpném (pak totiž asi chybí N4 a nemá se doplňovat).
        if($anot->[$i]{znacka} =~ m/^V[^s]/ && exists($subcat->{"SLO $anot->[$i]{heslo}"}))
        {
            # Najít všechny navrhované děti tohoto slovesa.
            my @deti;
            my %vazby_navrh;
            my %k_dispozici;
            for(my $j = 0; $j<=$#{$stav->{rodic}}; $j++)
            {
                # Zapamatovat si, jaké vazby by byly k dispozici.
                my $vznacka;
                if(exists($anot->[$j]{dedic}))
                {
                    $vznacka = prevest_mznacku_na_vazbu($anot->[$anot->[$j]{dedic}]{znacka}, $anot->[$anot->[$j]{dedic}]{heslo});
                }
                else
                {
                    $vznacka = prevest_mznacku_na_vazbu($anot->[$j]{znacka}, $anot->[$j]{heslo});
                }
                $k_dispozici{$vznacka}++;
                if($stav->{rodic}[$j]==$i)
                {
                    push(@deti, $anot->[$j]);
                    # Zapamatovat si, že se v návrhu vyskytla určitá vazba.
                    # Bude se nám to hodit při ověřování naplněnosti rámců.
                    $vazby_navrh{$vznacka}++;
                    my $spravne = $anot->[$j]{rodic_vzor}==$i ? 1 : 0;
                }
            }
            # Projít všechny známé rámce tohoto slovesa a hledat nějaký naplněný.
            my $n_naplnenych = 0;
            my $n_lze_naplnit;
            foreach my $ramec (@{$subcat->{"RAM $anot->[$i]{heslo}"}})
            {
                # Zjistit, zda je tento rámec v navrhovaném stromu naplněn.
                # Udělat si kopii evidence navrhovaných vazeb, abychom si v ní mohli čmárat.
                my %kopie_navrhovanych_vazeb = %vazby_navrh;
                my %kopie_vazeb_k_dispozici = %k_dispozici;
                # Rozdělit rámec na jednotlivé vazby.
                # Nejdřív z rámce odstranit sloveso.
                my $ramec_bez_slovesa = $ramec;
                $ramec_bez_slovesa =~ s/^\S+ //;
                my $ok = 1;
                my $lze_naplnit = 1;
                # Rámec "<INTR>" znamená, že jde o nepřechodné sloveso, které nevyžaduje žádné argumenty.
                unless($ramec_bez_slovesa eq "<INTR>")
                {
                    my @vazby = split(/~~/, $ramec_bez_slovesa);
                    foreach my $vazba (@vazby)
                    {
                        # Vazba se skládá ze subkategorizační značky a
                        # z analytické funkce (s-značky), oddělené jsou
                        # lomítkem. Odstranit lomítko a s-značku.
                        $vazba =~ s-/.*--;
                        # Zjistit, zda na tuto vazbu ještě zbývá nějaký uzel z návrhu.
                        if($kopie_navrhovanych_vazeb{$vazba}>0)
                        {
                            $kopie_navrhovanych_vazeb{$vazba}--;
                            $kopie_vazeb_k_dispozici{$vazba}--;
                        }
                        else
                        {
                            # Zvláštní případ: PR4 může naplnit i N4, takže pokud nemůžeme najít N4, zkusíme ještě PR4.
                            if($vazba eq "N4" && $kopie_navrhovanych_vazeb{"PR4"}>0)
                            {
                                $kopie_navrhovanych_vazeb{"PR4"}--;
                                $kopie_vazeb_k_dispozici{"PR4"}--;
                            }
                            else
                            {
                                $ok = 0;
                                if($kopie_vazeb_k_dispozici{$vazba}<=0)
                                {
                                    $lze_naplnit = 0;
                                    last;
                                }
                                else
                                {
                                    $kopie_vazeb_k_dispozici{$vazba}--;
                                }
                            }
                        }
                    }
                }
                if($ok)
                {
                    $n_naplnenych++;
                }
                else
                {
                    if($lze_naplnit)
                    {
                        $n_lze_naplnit++;
                        return 1;
                    }
                }
            }
        }
    }
    return 0;
}



#==============================================================================
# Funkce pro zjištění, co lze na současné analýze věty zlepšit, aby byly lépe
# naplněny valenční rámce.
#==============================================================================



#------------------------------------------------------------------------------
# Získá seznam slov, která v dané analýze zaplňují některé místo ve valenčních
# rámcích (a není tedy vhodné na jejich zavěšení něco měnit) a seznam slov,
# která nepatří do první množiny a současně jejich převěšení může vést
# k zaplnění dalších valenčních míst. Oba seznamy zakóduje do návratového pole
# takto: 0 ... slovo už zaplňuje valenci, neměnit; 1 ... slovo nezaplňuje
# valenci, ale mohlo by; 2 ... slovo nezaplňuje valenci a ani nebylo zjištěno,
# že by mohlo.
#------------------------------------------------------------------------------
sub najit_valencni_rezervy
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na hash (potřebujeme z něj zejména návrh stromu, ale nejen ten)
    my $subkat = shift; # odkaz na hash se subkategorizačním slovníkem
    my @evidence; # výstupní pole (0 už použito 1 lze použít 2 ostatní)
    # Naplnit evidenci výchozími hodnotami.
    @evidence = map{2}(0..$#{$anot});
    # Získat seznam sloves ve větě, pokrytých valenčním slovníkem.
    my $slovesa = ziskat_seznam_sloves($anot, $subkat);
    # Získat doplňující údaje ke všem uzlům navrženým za děti sloves.
    my $deti = obohatit_deti($anot, $stav);
    # Projít slovesa a zjistit, co mají a co jim chybí.
    foreach my $sloveso (@{$slovesa})
    {
        # Pro dané sloveso vybrat rámec, zjistit, která slova se v něm angažují a
        # jaké druhy slov rámec ještě shání. Tato zjištění rovnou připsat do
        # centrální evidence využitelnosti slov pro valenci.
        vybrat_ramec_a_promitnout_ho_do_evidence($anot, $sloveso, $deti, $subkat, \@evidence);
    }
    return \@evidence;
}



#------------------------------------------------------------------------------
# Dílčí funkce pro kontrolu valence. Projde větu a najde slovesa, pro která
# známe alespoň jeden rámec.
#------------------------------------------------------------------------------
sub ziskat_seznam_sloves
{
    my $anot = shift; # odkaz na pole hashů
    my $subcat = shift; # odkaz na hash se subkategorizačním slovníkem
    my @slovesa;
    # Najít slovesa.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zajímají nás pouze slovesa pokrytá subkategorizačním slovníkem.
        # Nezajímají nás, pokud jsou v příčestí trpném (pak totiž asi chybí N4 a nemá se doplňovat).
        if($anot->[$i]{znacka} =~ m/^V[^s]/ && exists($subcat->{"SLO $anot->[$i]{heslo}"}))
        {
            push(@slovesa, $i);
        }
    }
    return \@slovesa;
}



#------------------------------------------------------------------------------
# Zjistí pro každé dítě slovesa informace, které mohou rozhodovat o jeho zařazení
# mezi povinná nebo volitelná doplnění.
#------------------------------------------------------------------------------
sub obohatit_deti
{
    my $anot = shift; # odkaz na anotace jednotlivých slov
    my $stav = shift; # odkaz na hash; potřebujeme jen předat dál do model::ohodnotit_hranu(), jinak stačí pole navrhovaných rodičů
    my $navrhrod = $stav->{rodic}; # odkaz na pole indexů navrhovaných rodičů
    my @hodnoceni; # výstupní pole hashů
    # Potřebujeme zjistit:
    # - pro každé dítě slovesa váhu jeho závislosti na jeho rodiči
    # - pro každé dítě slovesa počet sloves mezi ním a jeho rodičem
    # - pro každé dítě slovesa počet sloves od něj směrem pryč od jeho rodiče
    my @slovesa; # seznam indexů dosud viděných sloves
    my @deti; # evidence rozpracovaných a zpracovaných dětí
    # A teď vlastní implementace.
    # Procházet slova ve větě.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        # Zkonstruovat valenční značku podle morfologické značky a dát ji do hodnocení.
        $hodnoceni[$i]{vznacka} = zjistit_valencni_znacku($anot, $i);
        # Zkopírovat do hodnocení index navrhovaného rodiče, aby se všem funkcím nemusel předávat i stav analýzy.
        $hodnoceni[$i]{index} = $i;
        $hodnoceni[$i]{rodic} = $navrhrod->[$i];
        $hodnoceni[$i]{vzdalenost} = abs($i-$navrhrod->[$i]);
        # Jsme na dítěti slovesa?
        if(je_sloveso($anot->[$navrhrod->[$i]]))
        {
            # Zjistit váhu závislosti aktuálního dítěte na slovese.
            $hodnoceni[$i]{vaha} = model::ohodnotit_hranu($anot, $i, $navrhrod->[$i], $stav);
            # Je rodičovské sloveso vpravo od nás?
            if($navrhrod->[$i]>$i)
            {
                # Všechna dosud viděná slovesa přičíst jako vnější slovesa tohoto uzlu.
                $hodnoceni[$i]{vnejsi} += $#slovesa+1;
                # Přidat se do seznamu dětí jako rozpracované.
                push(@deti, {"index" => $i, "stav" => "rozprac"});
            }
            # Rodičovské sloveso je vlevo od nás.
            else
            {
                # Vrátit se po seznamu viděných sloves až k rodiči tohoto uzlu a spočítat vnitřní slovesa.
                for(my $j = $#slovesa; $j>=0 && $slovesa[$j]!=$navrhrod->[$i]; $j--)
                {
                    $hodnoceni[$i]{vnitrni}++;
                }
                # Přidat se do seznamu dětí rovnou jako zpracované.
                push(@deti, {"index" => $i, "stav" => "zprac"});
            }
        }
        # Jsme na slovese? (Pozor na pořadí kroků, i sloveso může být dítětem jiného slovesa!)
        if(je_sloveso($anot->[$i]))
        {
            # Připsat se mezi viděná slovesa.
            push(@slovesa, $i);
            # Projít rozpracované děti. K cizím se přičíst jako vnitřní, své ukončit, ke zpracovaným případně jako vnější.
            for(my $j = 0; $j<=$#deti; $j++)
            {
                # Ke zpracovaným dětem (nemohou být moje), jejichž rodič leží vlevo od nich, se přičíst jako vnější.
                my $index = $deti[$j]{index};
                if($deti[$j]{stav} eq "zprac" && $navrhrod->[$index]<$index)
                {
                    $hodnoceni[$index]{vnejsi}++;
                }
                # Rozpracované děti.
                elsif($deti[$j]{stav} eq "rozprac")
                {
                    # Pokud jsou moje, označit je za zpracované.
                    if($navrhrod->[$index]==$i)
                    {
                        $deti[$j]{stav} = "zprac";
                    }
                    # Pokud nejsou moje, přičíst se k nim jako vnitřní.
                    else
                    {
                        $hodnoceni[$index]{vnitrni}++;
                    }
                }
            }
        }
    }
    return \@hodnoceni;
}



#------------------------------------------------------------------------------
# Dílčí funkce pro kontrolu valence. Zjistí valenční značku slova.
#------------------------------------------------------------------------------
sub zjistit_valencni_znacku
{
    my $anot = shift; # odkaz na pole hashů pro jednotlivá slova ve větě
    my $index = shift; # index slova, jehož valenční značka nás zajímá
    my $vznacka;
    if(exists($anot->[$index]{dedic}))
    {
        $vznacka = prevest_mznacku_na_vazbu($anot->[$anot->[$index]{dedic}]{znacka}, $anot->[$anot->[$index]{dedic}]{heslo});
    }
    else
    {
        $vznacka = prevest_mznacku_na_vazbu($anot->[$index]{znacka}, $anot->[$index]{heslo});
    }
    return $vznacka;
}



#------------------------------------------------------------------------------
# Projde rámce zadaného slovesa a porovná je s dětmi, které slovesu navrhl
# parser. Vybere rámec, který je danou množinou dětí nejlépe naplněn. Vyhraje
# rámec, kterému zůstalo nejméně nezaplněných míst. Při rovnosti vyhraje první
# takový nalezený rámec. Mohli bychom ještě brát v úvahu, kolik je ve větě
# k dispozici uzlů s valenční značkou, kterou požaduje některé nezaplněné místo
# rámce, ale tento počet nebudeme znát přesně, dokud všem slovesům nepřiřadíme
# rámce (některé děti sloves mohou být označeny za volná doplnění a být tak
# k dispozici pro rámce, které by z nich chtěly udělat povinná doplnění), a to
# je začarovaný kruh. Funkce už také nehledí na to, jak kvalitními doplněními
# jsou jednotlivá místa rámce zaplněna (např. jak daleko má příslušné dítě ke
# slovesu), přestože se tato kritéria používají při vlastním zaplňování jednoho
# rámce a výběru mezi několika dětmi, které by dané místo mohly zaplnit.
#
# Funkce nevrací přímo vybraný rámec, ale rovnou výsledky jeho srovnání s dětmi
# slovesa, protože to je to, co volající potřebuje, a my to v průběhu vybírání
# tak jako tak musíme získat.
#------------------------------------------------------------------------------
sub vybrat_ramec_a_promitnout_ho_do_evidence
{
    my $anot = shift; # odkaz na pole hashů
    my $sloveso = shift; # index do pole @{$anot}
    my $deti = shift; # odkaz na pole s doplňujícími informacemi o dětech sloves
    my $subcat = shift; # odkaz na hash se subkategorizačním slovníkem
    my $evidence = shift; # odkaz na cílové pole
    # Získat seznam rámců daného slovesa ze slovníku.
    my $ramce = $subcat->{"RAM $anot->[$sloveso]{heslo}"};
    # Vybrat z pole informací o dětech sloves pouze děti našeho slovesa.
    my @me_deti = grep{$_->{rodic}==$sloveso}(@{$deti});
    # Projít všechny rámce slovesa, hledat ten nejlépe zaplněný.
    my $min_nezaplnenych;
    my $srovnani_min;
    foreach my $ramec (@{$ramce})
    {
        my $vazby = pripravit_ramec_k_porovnani($ramec);
        my $srovnani = porovnat_deti_s_ramcem(\@me_deti, $vazby);
        # Jestliže srovnání vyšlo lépe než u dosud nejlepšího rámce, prohlásit za nejlepší tenhle.
        if($min_nezaplnenych eq "" || $srovnani->{n_chybi}<$min_nezaplnenych)
        {
            $min_nezaplnenych = $srovnani->{n_chybi};
            $srovnani_min = $srovnani;
        }
    }
    # Připsat nejlepší rámec do evidence.
    # Uzlům, které se podílejí na zaplnění rámce, nastavit v evidenci 0.
    foreach my $i (@{$srovnani_min->{nalezeno}})
    {
        $evidence->[$i] = 0;
    }
    # Uzlům, které ode mne ani od nikoho jiného nemají 0, ale mohly by mi pomoci k lepšímu zaplnění, nastavit 1.
    for(my $i = 0; $i<=$#{$anot}; $i++)
    {
        if($srovnani_min->{chybi}{$deti->[$i]{vznacka}} && $evidence->[$i]!=0)
        {
            $evidence->[$i] = 1;
        }
    }
}



#------------------------------------------------------------------------------
# Zpracuje rámec tak, aby bylo možné s ním porovnat seznam uzlů, které ho mají
# naplnit.
#------------------------------------------------------------------------------
sub pripravit_ramec_k_porovnani
{
    my $ramec = shift; # řetězec vazeb oddělených ~~ nebo <INTR>
    # Odstranit z rámce sloveso.
    my $ramec_bez_slovesa = $ramec;
    $ramec_bez_slovesa =~ s/^\S+ //;
    # Převést rámec na seznam vazeb. Seznam reprezentovat hashem, pro každou vazbu počet výskytů.
    # Rámec "<INTR>" znamená, že jde o nepřechodné sloveso, které nemá žádné vazby.
    my %hash;
    unless($ramec_bez_slovesa eq "<INTR>")
    {
        my @vazby = split(/~~/, $ramec_bez_slovesa);
        # Převést pole vazeb na reprezentační hash.
        for(my $i = 0; $i<=$#vazby; $i++)
        {
            # Vazby jsou uloženy ve tvaru vznacka/afun. Odstranit analytickou funkci.
            $vazby[$i] =~ s-/.*--;
            $hash{$vazby[$i]}++;
        }
    }
    return \%hash;
}



#------------------------------------------------------------------------------
# Dílčí funkce pro kontrolu valence. Porovná seznam navrhovaných dětí slovesa
# s rámcem tohoto slovesa.
#
# Vrací:
# - seznam valenčních značek, které chybí
# - seznam indexů uzlů, které plní roli argumentů
#
# Může se stát, že rámec požaduje menší počet doplnění určitého druhu (např. N4),
# než kolik takových doplnění na slovesu podle návrhu visí. V tom případě je třeba
# rozhodnout, které z navrhovaných dětí je to nejlepší a ostatní prohlásit za
# volná doplnění. Za nejlepší prohlásíme to dítě, jehož závislosti model přiřadí
# největší váhu. Při rovnosti vah rozhodne vzdálenost dítěte od slovesa: vyhrává
# dítě oddělené menším počtem jiných sloves, potom bližší dítě, potom dítě na
# straně, na které je méně dalších sloves, potom dítě vpravo.
#
# Pozor, tato funkce nebere v úvahu, že mohou existovat ještě jiné rámce téhož
# slovesa, které by seznam dětí uspokojil.
#------------------------------------------------------------------------------
sub porovnat_deti_s_ramcem
{
    my $deti = shift; # odkaz na pole hashů o dětech (obsahují mj. i odkaz do @anot na standardní údaje)
    my $ramec = shift; # odkaz na hash indexovaný valenčními značkami, hodnoty jsou počet požadovaných takových vazeb
    # Seřadit děti sestupně podle pravděpodobnosti, že právě ony jsou povinnými doplněními slovesa.
    # "Pravděpodobností" se zde nemyslí jen váha podle modelu, ale při nerozhodnosti i další heuristiky.
    my @sdeti = sort
    {
        my $vysledek = $b->{vaha}<=>$a->{vaha};
        unless($vysledek)
        {
            $vysledek = $a->{vnitrni}<=>$b->{vnitrni};
            unless($vysledek)
            {
                $vysledek = $a->{vzdalenost}<=>$b->{vzdalenost};
                unless($vysledek)
                {
                    $vysledek = $a->{vnejsi}<=>$b->{vnejsi};
                    unless($vysledek)
                    {
                        $vysledek = $a->{index}<=>$b->{index};
                    }
                }
            }
        }
        return $vysledek;
    }
    (@{$deti});
    # Vytvořit si kopii rámce, abychom si v ní mohli čmárat.
    my %ramec = %{$ramec};
    # Procházet děti a u každého se zeptat, jestli je povinné (umazáváním příslušných značek z rámce).
    # PR4 uspokojí přednostně požadavek na PR4, ale pokud takový požadavek není, zkusí uspokojit požadavek na N4.
    for(my $i = 0; $i<=$#sdeti; $i++)
    {
        if($ramec{$sdeti[$i]{vznacka}})
        {
            # Poznamenat si, že tento člen rámce už je naplněn.
            $ramec{$sdeti[$i]{vznacka}}--;
            # Poznamenat si, že tento uzel už je angažován jako povinné doplnění.
            $sdeti[$i]{arg} = 1;
        }
        elsif($sdeti[$i]{vznacka} eq "PR4" && $ramec{"N4"})
        {
            # Poznamenat si, že tento člen rámce už je naplněn.
            $ramec{"N4"}--;
            # Poznamenat si, že tento uzel už je angažován jako povinné doplnění.
            $sdeti[$i]{arg} = 1;
        }
    }
    # Sestavit návratové údaje a vrátit je.
    my %srovnani;
    while(my ($klic, $hodnota) = each(%ramec))
    {
        $srovnani{n_chybi} += $hodnota;
    }
    $srovnani{chybi} = \%ramec;
    my @nalezeno = map{$_->{index}}(grep{$_->{arg}}(@sdeti));
    $srovnani{nalezeno} = \@nalezeno;
    return \%srovnani;
}



#==============================================================================
# Pomocné funkce, ze kterých by se časem měl vytvořit samostatný modul pro
# odstínění zvláštností jazyka nebo značení v konkrétním korpusu.
#==============================================================================



#------------------------------------------------------------------------------
# Zjistí z anotace slova, zda jde o sloveso.
#------------------------------------------------------------------------------
sub je_sloveso
{
    my $anot = shift;
    return $anot->{znacka} =~ m/^V/;
}



1;
