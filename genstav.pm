package genstav;
use povol;
use zakaz;
use model;
use lokon;
use stav;
use vystupy; # kvùli chybovým a ladícím výpisùm



#------------------------------------------------------------------------------
# Vezme aktuální stav (les), projde závislosti, které je mo¾né pøidat, zjistí
# jejich pravdìpodobnosti a nageneruje pøíslu¹né pokraèovací stavy. Vrací hash
# s prvky r (index øídícího), z (index závislého), c (èetnost) a p (pravdìpo-
# dobnost).
#------------------------------------------------------------------------------
sub generovat_stavy
{
    my $stav = shift; # odkaz na hash s dosavadním stavem analýzy
    my $generovat_vse = shift; # generovat v¹echny pokraèovací stavy, nebo jen vítìzný?
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    # Zjistit seznam závislostí, jejich¾ pøidání do stromu je momentálnì povolené.
    my @povol = povol::zjistit_povol($stav->{rodic});
    # Ulo¾it seznam povolených hran do stavu analýzy, jednak aby se o nìm dozvìdìly volané funkce
    # (tøeba pøi navrhování koordinace je potøeba vìdìt, zda je povolena i druhá hrana), jednak
    # kvùli ladìní, aby bylo mo¾né zpìtnì zjistit, z jakých hran jsme vybírali.
    $stav->{povol} = \@povol;
    # Nejdøíve spojit koøen s koncovou interpunkcí. Zde nepustíme statistiku vùbec ke slovu.
    my $nove_stavy;
    if($konfig->{koncint})
    {
        if($nove_stavy = generovat_pro_koncovou_interpunkci($stav, $anot, $generovat_vse))
        {
            return $nove_stavy;
        }
    }
    # Zjistit, zda jsme v minulém kole nepøipojovali první èást koordinace.
    # To bychom v tomto kole byli povinni pøipojit zbytek.
    if($nove_stavy = generovat_pro_druhou_cast_koordinace($stav, $generovat_vse))
    {
        return $nove_stavy;
    }
    # Pokud je mezi povolenými závislostmi nejlépe hodnocená valenèní
    # závislost, vybere se ona (i kdyby nìkteré nevalenèní byly lep¹í).
    if($konfig->{valence})
    {
        if($nove_stavy = generovat_pro_valencni_zavislost($stav, $generovat_vse))
        {
            return $nove_stavy;
        }
    }
    # Projít povolené a nezakázané závislosti, vygenerovat pro nì stavy a vrátit jejich seznam.
    # Zatím se pomocí parametru %max získává zvlá¹» i popis vítìzného kandidáta.
    # Èasem to pøestane být potøeba, proto¾e první stav v seznamu bude odpovídat tomuto kandidátovi.
    my %max;
    $nove_stavy = generovat_zaklad($stav, \%max, $generovat_vse);
    # Jestli¾e máme generovat i zálo¾ní stavy, zjistit k nim také váhy, podle kterých
    # bude mo¾né mezi nimi vybírat.
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
        # Seøadit nové stavy podle váhy. Dìláme to je¹tì pøed øe¹ením lokálních konfliktù.
        # Pokud nìkdo vyhraje na základì nich, bude vyta¾en mimo poøadí.
        @{$nove_stavy} = sort{$b->{vaha}<=>$a->{vaha}}(@{$nove_stavy});
    }
    if($konfig->{lokon})
    {
        # Je vybrán vítìzný kandidát na základì své relativní èetnosti bez
        # ohledu na kontext. Teï zohlednit kontext a pokusit se vyøe¹it lokální
        # konflikty.
        lokalni_konflikty($stav, $nove_stavy, $generovat_vse);
    }
    # Vrátit celé pole.
    return $nove_stavy;
}



#------------------------------------------------------------------------------
# Vezme aktuální stav, zkontroluje, zda u¾ byla zavì¹ena koncová interpunkce,
# a pokud ne, zavìsí ji a vrátí odkaz na pole, jeho¾ jediným prvkem je výsledný
# stav.
#------------------------------------------------------------------------------
sub generovat_pro_koncovou_interpunkci
{
    my $stav = shift; # odkaz na hash
    my $anot = shift; # odkaz na pole hashù
    my $generovat_vse = shift; # generovat v¹echny pokraèovací stavy, nebo jen vítìzný?
    if($stav->{rodic}[$#{$anot}]==-1 && $anot->[$#{$anot}]{uznacka}=~m/^Z/)
    {
        my $r = 0;
        my $z = $#{$anot};
        my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
        stav::pridat_zavislost($stav1, model::ohodnotit_hranu($r, $z, $stav1));
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
# Vezme aktuální stav, zkontroluje, zda se má tvoøit druhá èást koordinace,
# a pokud ano, zavìsí ji a vrátí odkaz na pole, jeho¾ jediným prvkem je
# výsledný stav.
#------------------------------------------------------------------------------
sub generovat_pro_druhou_cast_koordinace
{
    my $stav = shift; # odkaz na hash
    my $generovat_vse = shift; # generovat v¹echny pokraèovací stavy, nebo jen vítìzný?
    if($stav->{priste}=~m/^(\d+)-(\d+)$/)
    {
        my $r = $1;
        my $z = $2;
        # Pro v¹echny pøípady ovìøit, ¾e tato závislost je povolená.
        if(!povol::je_povoleno($r, $z, $stav->{povol}))
        {
            vypsat("prubeh", "Po¾adováno povinné pøidání závislosti $r-$z.\n");
            vypsat("prubeh", "Povoleny jsou závislosti ".join(",", @{$stav->{povol}})."\n");
            die("CHYBA! Druhá èást koordinace pøestala být po pøidání první èásti povolena.\n");
        }
        my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
        $stav1->{priste} = "";
        stav::pridat_zavislost($stav1, {"r" => $r, "z" => $z, "c" => 0, "p" => "1"});
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
# Vezme aktuální stav, zkontroluje, zda lze pøidat valenèní závislost, a pokud
# ano, zavìsí ji a vrátí odkaz na pole, jeho¾ jediným prvkem je výsledný stav.
#------------------------------------------------------------------------------
sub generovat_pro_valencni_zavislost
{
    my $generovat_vse = shift; # generovat v¹echny pokraèovací stavy, nebo jen vítìzný?
    my $stav = shift; # odkaz na hash
    if($#{$stav->{valencni}}>=0)
    {
        $stav->{valencni}[0] =~ m/^(\d+)-(\d+)/;
        my %max;
        $max{r} = $1;
        $max{z} = $2;
        # Zjistit, zda je nejlep¹í valenèní závislost mezi povolenými.
        for(my $i = 0; $i<=$#{$stav->{povol}}; $i++)
        {
            if($stav->{povol}[$i] eq "$max{r}-$max{z}" && !zakaz::je_zakazana($stav->{zakaz}, $max{r}, $max{z}))
            {
                my $stav1 = $generovat_vse ? stav::zduplikovat($stav) : $stav;
                shift(@{$stav1->{valencni}});
                ($max{p}, $max{c}) = model::zjistit_pravdepodobnost($max{r}, $max{z}, $stav1);
                stav::pridat_zavislost($stav1, \%max);
                my @vysledek;
                push(@vysledek, $stav1);
                return \@vysledek;
            }
        }
    }
    return "";
}



#------------------------------------------------------------------------------
# Projde povolené a nezakázané závislosti, pro ka¾dou vygeneruje stav analýzy,
# jako kdyby tato závislost byla pøidána do stromu, a vybere nejlep¹í z tìchto
# stavù. Pokud nejsou k dispozici povolené a nezakázané hrany, zru¹í v¹echny
# zákazy. Vrátí seznam pokraèovacích stavù, na prvním místì vítìze.
#------------------------------------------------------------------------------
sub generovat_zaklad
{
    my $stav = shift; # odkaz na hash
    my $max = shift; # odkaz, kam opsat vítìzného kandidáta
    my $generovat_vse = shift; # generovat v¹echny pokraèovací stavy, nebo jen vítìzný?
    my @nove_stavy;
    my $index_viteze;
    # Generování pøípadnì opakovat dvakrát. Pokud se napoprvé nic nenajde, zru¹it v¹echny zákazy a zkusit to znova.
    for(; $max->{p} eq "";)
    {
        die("CHYBA! Není povolena ani jedna závislost a hrozí nekoneèná smyèka.\n") unless($#{$stav->{povol}}+1);
        for(my $i = 0; $i<=$#{$stav->{povol}}; $i++)
        {
            # Pøeèíst závislost - kandidáta.
            $stav->{povol}[$i] =~ m/(\d+)-(\d+)/;
            my $r = $1;
            my $z = $2;
            # Pokud je závislost na èerné listinì, vyøadit ji ze soutì¾e.
            # Èerná listina $zakaz má vy¹¹í prioritu ne¾ $povol.
            if(zakaz::je_zakazana($stav->{zakaz}, $r, $z))
            {
                next;
            }
            # Pøidat do seznamu pokraèovací stav pro tuto závislost.
            my $kandidat = model::ohodnotit_hranu($r, $z, $stav);
            if($generovat_vse)
            {
                my $stav1 = stav::zduplikovat($stav);
                stav::pridat_zavislost($stav1, $kandidat);
                push(@nove_stavy, $stav1);
            }
            # Zjistit, zda je tato pravdìpodobnost vy¹¹í ne¾ pravdìpodobnosti
            # závislostí testovaných v pøedchozích prùchodech.
            if($max->{p} eq "" || $kandidat->{p}>$max->{p}) # i==0 nefunguje, kvuli $zakaz
            {
                %{$max} = %{$kandidat};
                # U pole nových stavù si zatím pamatovat jen index nejlep¹ího pokraèovacího stavu.
                $index_viteze = $#nove_stavy;
            }
        }
        # Pokud se mezi povolenými nena¹la jediná nezakázaná závislost, nouzová
        # situace: zru¹it v¹echny zákazy pro tuto vìtu.
        if($max->{p} eq "")
        {
            $stav->{zakaz} = "";
        }
    }
    # Pokud se nemìly generovat v¹echny pokraèovací stavy, je teï èas vygenerovat
    # ten jeden vítìzný.
    unless($generovat_vse)
    {
        my $stav1 = stav::zduplikovat($stav);
        stav::pridat_zavislost($stav1, $max);
        $nove_stavy[0] = $stav1;
    }
    else
    {
        # Pøed návratem zaøídit, aby vítìzný kandidát byl v seznamu nových stavù na prvním místì.
        my $vitezny_stav = $nove_stavy[$index_viteze];
        splice(@nove_stavy, $index_viteze, 1);
        unshift(@nove_stavy, $vitezny_stav);
    }
    return \@nove_stavy;
}



#------------------------------------------------------------------------------
# Pøehodnotí názor na vítìze na základì modelu lokálních konfliktù. Mno¾inu
# nových stavù nemìní, mù¾e v¹ak zmìnit poøadí nových stavù.
#------------------------------------------------------------------------------
sub lokalni_konflikty
{
    my $stav = shift; # odkaz na hash s dosavadním stavem (nový kandidát je¹tì nebyl pøidán)
    my $nove_stavy = shift; # odkaz na pole hashù s novými stavy; první z nich je vítìz ze základního kola
    my $generovat_vse = shift; # generovat v¹echny pokraèovací stavy, nebo jen vítìzný?
    my $poslz = $nove_stavy->[0]{poslz};
    my %max0 =
    (
        "r" => $nove_stavy->[0]{rodic}[$poslz],
        "z" => $poslz,
        "c" => $nove_stavy->[0]{maxc}[$poslz],
        "p" => $nove_stavy->[0]{maxp}[$poslz],
        "priste" => $nove_stavy->[0]{priste}
    );
    my %max1 = lokon::lokalni_konflikty(\%max0, $stav);
    # Vrstva kompatibility mezi starou implementací lokálních konfliktù a novou
    # implementací generování stavù. Najít mezi novými stavy ten, který reprezentuje
    # vítìze lokálních konfliktù. Lep¹í by bylo, kdyby modul lokon pracoval
    # rovnou s polem nových stavù.
    if($max1{r}!=$max0{r} || $max1{z}!=$max0{z})
    {
        # Pokud se nemìly generovat v¹echny pokraèovací stavy, nemáme nikde nachystaný
        # stav, ve kterém místo základního vítìze vyhrál vítìz lokálního konfliktu,
        # a musíme ho vygenerovat teï.
        unless($generovat_vse)
        {
            my $stav1 = stav::zduplikovat($stav);
            stav::pridat_zavislost($stav1, \%max1);
            $nove_stavy->[0] = $stav1;
        }
        # Jinak staèí nového vítìze mezi stavy najít a pøesunout na první místo.
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
            # Pøed návratem zaøídit, aby vítìzný kandidát byl v seznamu nových stavù opìt na prvním místì.
            my $vitezny_stav = $nove_stavy->[$index_viteze];
            splice(@{$nove_stavy}, $index_viteze, 1);
            unshift(@{$nove_stavy}, $vitezny_stav);
        }
    }
}



1;
