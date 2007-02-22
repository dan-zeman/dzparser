package genstav;
use utf8;
use povol;
use zakaz;
use model;
use lokon;
use stav;
use vystupy; # kvůli chybovým a ladícím výpisům



#------------------------------------------------------------------------------
# Vezme aktuální stav (les), projde závislosti, které je možné přidat, zjistí
# jejich pravděpodobnosti a nageneruje příslušné pokračovací stavy. Vrací hash
# s prvky r (index řídícího), z (index závislého), c (četnost) a p (pravděpo-
# dobnost).
#------------------------------------------------------------------------------
sub generovat_stavy
{
    my $stav = shift; # odkaz na hash s dosavadním stavem analýzy
    my $anot = shift; # odkaz na pole hashů
    my $generovat_vse = shift; # generovat všechny pokračovací stavy, nebo jen vítězný?
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    # Zjistit seznam závislostí, jejichž přidání do stromu je momentálně povolené.
    my @povol = povol::zjistit_povol($anot, $stav->{rodic});
    # Uložit seznam povolených hran do stavu analýzy, jednak aby se o něm dozvěděly volané funkce
    # (třeba při navrhování koordinace je potřeba vědět, zda je povolena i druhá hrana), jednak
    # kvůli ladění, aby bylo možné zpětně zjistit, z jakých hran jsme vybírali.
    $stav->{povol} = \@povol;
    # Nejdříve spojit kořen s koncovou interpunkcí. Zde nepustíme statistiku vůbec ke slovu.
    my $nove_stavy;
    if($konfig->{koncint})
    {
        if($nove_stavy = generovat_pro_koncovou_interpunkci($stav, $anot, $generovat_vse))
        {
            return $nove_stavy;
        }
    }
    # Zjistit, zda jsme v minulém kole nepřipojovali první část koordinace.
    # To bychom v tomto kole byli povinni připojit zbytek.
    if($nove_stavy = generovat_pro_druhou_cast_koordinace($stav, $anot, $generovat_vse))
    {
        return $nove_stavy;
    }
    # Pokud je mezi povolenými závislostmi nejlépe hodnocená valenční
    # závislost, vybere se ona (i kdyby některé nevalenční byly lepší).
    if($konfig->{valence})
    {
        if($nove_stavy = generovat_pro_valencni_zavislost($stav, $anot, $generovat_vse))
        {
            return $nove_stavy;
        }
    }
    # Projít povolené a nezakázané závislosti, vygenerovat pro ně stavy a vrátit jejich seznam.
    # Zatím se pomocí parametru %max získává zvlášť i popis vítězného kandidáta.
    # Časem to přestane být potřeba, protože první stav v seznamu bude odpovídat tomuto kandidátovi.
    my %max;
    $nove_stavy = generovat_zaklad($stav, $anot, \%max, $generovat_vse);
    # Jestliže máme generovat i záložní stavy, zjistit k nim také váhy, podle kterých
    # bude možné mezi nimi vybírat.
    if($generovat_vse)
    {
        for(my $i = 0; $i<=$#{$nove_stavy}; $i++)
        {
            my $prst_moje = $nove_stavy->[$i]{maxp}[$nove_stavy->[$i]{poslz}];
            my $prst_viteze = $nove_stavy->[0]{maxp}[$nove_stavy->[0]{poslz}];
            if($prst_viteze!=0)
            {
                $nove_stavy->[$i]{vaha} = $prst_moje/$prst_viteze;
            }
            elsif($prst_moje>0)
            {
                $nove_stavy->[$i]{vaha} = 1;
            }
            else
            {
                $nove_stavy->[$i]{vaha} = 0;
            }
        }
        # Seřadit nové stavy podle váhy. Děláme to ještě před řešením lokálních konfliktů.
        # Pokud někdo vyhraje na základě nich, bude vytažen mimo pořadí.
        @{$nove_stavy} = sort{$b->{vaha}<=>$a->{vaha}}(@{$nove_stavy});
    }
    if($konfig->{lokon})
    {
        # Je vybrán vítězný kandidát na základě své relativní četnosti bez
        # ohledu na kontext. Teď zohlednit kontext a pokusit se vyřešit lokální
        # konflikty.
        lokalni_konflikty($anot, $stav, $nove_stavy, $generovat_vse);
    }
    # Vrátit celé pole.
    return $nove_stavy;
}



#------------------------------------------------------------------------------
# Vezme aktuální stav, zkontroluje, zda už byla zavěšena koncová interpunkce,
# a pokud ne, zavěsí ji a vrátí odkaz na pole, jehož jediným prvkem je výsledný
# stav.
#------------------------------------------------------------------------------
sub generovat_pro_koncovou_interpunkci
{
    my $stav = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashů
    my $generovat_vse = shift; # generovat všechny pokračovací stavy, nebo jen vítězný?
    if($stav->{rodic}[$#{$anot}]==-1 && $anot->[$#{$anot}]{uznacka}=~m/^Z/)
    {
        my $r = 0;
        my $z = $#{$anot};
        my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
        stav::pridat_zavislost($anot, $stav1, model::ohodnotit_hranu($anot, $r, $z, $stav1));
        my @vysledek;
        push(@vysledek, $stav1);
        return \@vysledek;
    }
    else
    {
        return "";
    }
}



#------------------------------------------------------------------------------
# Vezme aktuální stav, zkontroluje, zda se má tvořit druhá část koordinace,
# a pokud ano, zavěsí ji a vrátí odkaz na pole, jehož jediným prvkem je
# výsledný stav.
#------------------------------------------------------------------------------
sub generovat_pro_druhou_cast_koordinace
{
    my $stav = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashů
    my $generovat_vse = shift; # generovat všechny pokračovací stavy, nebo jen vítězný?
    if($stav->{priste}=~m/^(\d+)-(\d+)$/)
    {
        my $r = $1;
        my $z = $2;
        # Pro všechny případy ověřit, že tato závislost je povolená.
        if(!povol::je_povoleno($anot, $r, $z, $stav->{povol}))
        {
            vypsat("prubeh", "Požadováno povinné přidání závislosti $r-$z.\n");
            vypsat("prubeh", "Povoleny jsou závislosti ".join(",", @{$stav->{povol}})."\n");
            die("CHYBA! Druhá část koordinace přestala být po přidání první části povolena.\n");
        }
        my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
        $stav1->{priste} = "";
        stav::pridat_zavislost($anot, $stav1, {"r" => $r, "z" => $z, "c" => 0, "p" => "1"});
        my @vysledek;
        push(@vysledek, $stav1);
        return \@vysledek;
    }
    else
    {
        return "";
    }
}



#------------------------------------------------------------------------------
# Vezme aktuální stav, zkontroluje, zda lze přidat valenční závislost, a pokud
# ano, zavěsí ji a vrátí odkaz na pole, jehož jediným prvkem je výsledný stav.
#------------------------------------------------------------------------------
sub generovat_pro_valencni_zavislost
{
    my $stav = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashů
    my $generovat_vse = shift; # generovat všechny pokračovací stavy, nebo jen vítězný?
    if($#{$stav->{valencni}}>=0)
    {
        $stav->{valencni}[0] =~ m/^(\d+)-(\d+)/;
        my %max;
        $max{r} = $1;
        $max{z} = $2;
        # Zjistit, zda je nejlepší valenční závislost mezi povolenými.
        for(my $i = 0; $i<=$#{$stav->{povol}}; $i++)
        {
            if($stav->{povol}[$i] eq "$max{r}-$max{z}" && !zakaz::je_zakazana($stav->{zakaz}, $max{r}, $max{z}))
            {
                my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
                shift(@{$stav1->{valencni}});
                ($max{p}, $max{c}) = model::zjistit_pravdepodobnost($anot, $max{r}, $max{z}, $stav1);
                stav::pridat_zavislost($anot, $stav1, \%max);
                my @vysledek;
                push(@vysledek, $stav1);
                return \@vysledek;
            }
        }
    }
    return "";
}



#------------------------------------------------------------------------------
# Projde povolené a nezakázané závislosti, pro každou vygeneruje stav analýzy,
# jako kdyby tato závislost byla přidána do stromu, a vybere nejlepší z těchto
# stavů. Pokud nejsou k dispozici povolené a nezakázané hrany, zruší všechny
# zákazy. Vrátí seznam pokračovacích stavů, na prvním místě vítěze.
#------------------------------------------------------------------------------
sub generovat_zaklad
{
    my $stav = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashů
    my $max = shift; # odkaz, kam opsat vítězného kandidáta
    my $generovat_vse = shift; # generovat všechny pokračovací stavy, nebo jen vítězný?
    my @nove_stavy;
    my $index_viteze;
    # Generování případně opakovat dvakrát. Pokud se napoprvé nic nenajde, zrušit všechny zákazy a zkusit to znova.
    for(; $max->{p} eq "";)
    {
        die("CHYBA! Není povolena ani jedna závislost a hrozí nekonečná smyčka.\n") unless($#{$stav->{povol}}+1);
        for(my $i = 0; $i<=$#{$stav->{povol}}; $i++)
        {
            # Přečíst závislost - kandidáta.
            $stav->{povol}[$i] =~ m/(\d+)-(\d+)/;
            my $r = $1;
            my $z = $2;
            # Pokud je závislost na černé listině, vyřadit ji ze soutěže.
            # Černá listina $zakaz má vyšší prioritu než $povol.
            if(zakaz::je_zakazana($stav->{zakaz}, $r, $z))
            {
                next;
            }
            # Přidat do seznamu pokračovací stav pro tuto závislost.
            my $kandidat = model::ohodnotit_hranu($anot, $r, $z, $stav);
            if($generovat_vse)
            {
                my $stav1 = stav::zduplikovat($stav);
                stav::pridat_zavislost($anot, $stav1, $kandidat);
                push(@nove_stavy, $stav1);
            }
            # Zjistit, zda je tato pravděpodobnost vyšší než pravděpodobnosti
            # závislostí testovaných v předchozích průchodech.
            if($max->{p} eq "" || $kandidat->{p}>$max->{p}) # i==0 nefunguje, kvuli $zakaz
            {
                %{$max} = %{$kandidat};
                # U pole nových stavů si zatím pamatovat jen index nejlepšího pokračovacího stavu.
                $index_viteze = $#nove_stavy;
            }
        }
        # Pokud se mezi povolenými nenašla jediná nezakázaná závislost, nouzová
        # situace: zrušit všechny zákazy pro tuto větu.
        if($max->{p} eq "")
        {
            $stav->{zakaz} = "";
        }
    }
    # Pokud se neměly generovat všechny pokračovací stavy, je teď čas vygenerovat
    # ten jeden vítězný.
    unless($generovat_vse)
    {
        my $stav1 = stav::zduplikovat($stav);
        stav::pridat_zavislost($anot, $stav1, $max);
        $nove_stavy[0] = $stav1;
    }
    else
    {
        # Před návratem zařídit, aby vítězný kandidát byl v seznamu nových stavů na prvním místě.
        my $vitezny_stav = $nove_stavy[$index_viteze];
        splice(@nove_stavy, $index_viteze, 1);
        unshift(@nove_stavy, $vitezny_stav);
    }
    return \@nove_stavy;
}



#------------------------------------------------------------------------------
# Přehodnotí názor na vítěze na základě modelu lokálních konfliktů. Množinu
# nových stavů nemění, může však změnit pořadí nových stavů.
#------------------------------------------------------------------------------
sub lokalni_konflikty
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na hash s dosavadním stavem (nový kandidát ještě nebyl přidán)
    my $nove_stavy = shift; # odkaz na pole hashů s novými stavy; první z nich je vítěz ze základního kola
    my $generovat_vse = shift; # generovat všechny pokračovací stavy, nebo jen vítězný?
    my $poslz = $nove_stavy->[0]{poslz};
    my %max0 =
    (
        "r" => $nove_stavy->[0]{rodic}[$poslz],
        "z" => $poslz,
        "c" => $nove_stavy->[0]{maxc}[$poslz],
        "p" => $nove_stavy->[0]{maxp}[$poslz],
        "priste" => $nove_stavy->[0]{priste}
    );
    my %max1 = lokon::lokalni_konflikty($anot, \%max0, $stav);
    # Vrstva kompatibility mezi starou implementací lokálních konfliktů a novou
    # implementací generování stavů. Najít mezi novými stavy ten, který reprezentuje
    # vítěze lokálních konfliktů. Lepší by bylo, kdyby modul lokon pracoval
    # rovnou s polem nových stavů.
    if($max1{r}!=$max0{r} || $max1{z}!=$max0{z})
    {
        # Pokud se neměly generovat všechny pokračovací stavy, nemáme nikde nachystaný
        # stav, ve kterém místo základního vítěze vyhrál vítěz lokálního konfliktu,
        # a musíme ho vygenerovat teď.
        unless($generovat_vse)
        {
            my $stav1 = stav::zduplikovat($stav);
            stav::pridat_zavislost($anot, $stav1, \%max1);
            $nove_stavy->[0] = $stav1;
        }
        # Jinak stačí nového vítěze mezi stavy najít a přesunout na první místo.
        else
        {
            my $index_viteze = 0;
            for(my $i = 1; $i<=$#{$nove_stavy}; $i++)
            {
                my $novez = $nove_stavy->[$i]{poslz};
                my $nover = $nove_stavy->[$i]{rodic}[$novez];
                if($nover==$max1{r} && $novez==$max1{z})
                {
                    $index_viteze = $i;
                    last;
                }
            }
            # Před návratem zařídit, aby vítězný kandidát byl v seznamu nových stavů opět na prvním místě.
            my $vitezny_stav = $nove_stavy->[$index_viteze];
            splice(@{$nove_stavy}, $index_viteze, 1);
            unshift(@{$nove_stavy}, $vitezny_stav);
        }
    }
}



1;
