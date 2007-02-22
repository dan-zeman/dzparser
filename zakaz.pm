package zakaz;



#------------------------------------------------------------------------------
# Pøidá závislost na èernou listinu (resp. pøidá dal¹í dùvod, proè ji tam
# nechat, pokud u¾ tam je).
#------------------------------------------------------------------------------
sub pridat_zakaz
{
    my $zakaz = shift; # odkaz na skalár se seznamem zákazù
    my $r = shift; # index øídícího uzlu hrany, která se má zakázat
    my $z = shift; # index závislého uzlu hrany, která se má zakázat
    my $duvod = shift; # dùvod zákazu (aby bylo mo¾né odvolat zákazy mající stejnou pøíèinu)
    if($$zakaz !~ m/\($r-$z:$duvod\)/)
    {
        $$zakaz .= "($r-$z:$duvod)";
    }
}



#------------------------------------------------------------------------------
# Odebere jeden dùvod zákazu dané závislosti z èerné listiny. Pokud toto byl
# poslední dùvod, závislost se stane povolenou a je opìt schopna soutì¾e.
#------------------------------------------------------------------------------
sub zrusit_zakaz
{
    my $zakaz = shift; # odkaz na skalár se seznamem zákazù
    my $r = shift; # index øídícího uzlu hrany, která se má zakázat
    my $z = shift; # index závislého uzlu hrany, která se má zakázat
    my $duvod = shift; # dùvod zákazu (aby bylo mo¾né odvolat zákazy mající stejnou pøíèinu)
    $$zakaz =~ s/\($r-$z:$duvod\)//g;
}



#------------------------------------------------------------------------------
# Zjistí, zda je závislost na èerné listinì (doèasnì zakázaná).
#------------------------------------------------------------------------------
sub je_zakazana
{
    my $zakaz = shift; # skalár se seznamem zákazù
    my $r = shift; # index øídícího uzlu hrany, která se má zakázat
    my $z = shift; # index závislého uzlu hrany, která se má zakázat
    return $zakaz =~ m/\($r-$z:/;
}



#------------------------------------------------------------------------------
# Inicializuje seznam zákazù na zaèátku zpracování vìty.
# Vrátí øetìzec se zakódovaným seznamem zákazù.
# (Jazykovì závislá funkce.)
#------------------------------------------------------------------------------
sub formulovat_zakazy
{
    my $stav = shift; # odkaz na hash
    my $prislusnost_k_useku = $stav->{prislusnost_k_useku}; # odkaz na pole s pøíslu¹ností slov k mezièárkovým úsekùm
    my $hotovost_useku = $stav->{hotovost_useku}; # odkaz na pole s údaji o úplnosti analýzy mezi dvìma èárkami
    my $zakaz; # výstupní øetìzec
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    ### Závislosti na èárkách jsou zakázány ###
    # Ve skuteènosti toti¾ závislost na èárce v¾dy znamená Coord nebo Apos.
    if($konfig->{carka_je_list})
    {
        for(my $i = 1; $i<=$#{$anot}; $i++)
        {
            if($anot->[$i]{slovo} eq ",")
            {
                for(my $j = 1; $j<=$#{$anot}; $j++)
                {
                    pridat_zakaz(\$zakaz, $i, $j, "carky jsou listy");
                }
            }
        }
    }
    ### Úseky mezi èárkami ###
    if($konfig->{mezicarkove_useky})
    {
        # Zapamatovat si rozdìlení vìty interpunkcí na úseky.
        splice(@{$prislusnost_k_useku});
        splice(@{$hotovost_useku});
        my $i_usek = -1;
        my $carka = 0;
        my $je_co_zakazovat = 0;
        for(my $i = 0; $i<=$#{$anot}; $i++)
        {
            if($i==0 || $anot->[$i]{slovo} eq "," || $i==$#{$anot} && $stav->{uznck}[$i]=~m/^Z/)
            {
                $i_usek++;
                $carka = 1;
                $hotovost_useku->[$i_usek] = 1;
            }
            elsif($carka)
            {
                $i_usek++;
                $carka = 0;
                $hotovost_useku->[$i_usek] = 1;
            }
            else
            {
                $hotovost_useku->[$i_usek]++;
                $je_co_zakazovat = 1;
            }
            $prislusnost_k_useku->[$i] = $i_usek;
        }
        # Zakázat závislosti vedoucí pøes èárku. Povoleny budou a¾ po spojení v¹ech
        # mezièárkových úsekù.
        if($je_co_zakazovat)
        {
            for(my $i = 0; $i<=$#{$anot}; $i++)
            {
                for(my $j = $i+1; $j<=$#{$anot}; $j++)
                {
                    if($prislusnost_k_useku->[$i]!=$prislusnost_k_useku->[$j])
                    {
                        pridat_zakaz(\$zakaz, $i, $j, "carky");
                        pridat_zakaz(\$zakaz, $j, $i, "carky");
                    }
                }
            }
        }
    }
    if($konfig->{predlozky})
    {
        ### Pøeskakování bezdìtných pøedlo¾ek ###
        # Zakázat závislosti, které pøeskakují pøedlo¾ku, je¾ dosud nemá dítì.
        for(my $i = 0; $i<=$#{$anot}; $i++)
        {
            if($stav->{uznck}[$i] =~ m/^R/)
            {
                for(my $j = 0; $j<$i; $j++)
                {
                    for(my $k = $i+1; $k<=$#{$anot}; $k++)
                    {
                        pridat_zakaz(\$zakaz, $j, $k, "predlozka $i");
                        pridat_zakaz(\$zakaz, $k, $j, "predlozka $i");
                    }
                }
            }
        }
    }
    return $stav->{zakaz} = $zakaz;
}



#------------------------------------------------------------------------------
# Zvá¾í uvolnìní nìkterých zákazù na základì naposledy pøidané závislosti.
# (Jazykovì závislá funkce.)
#------------------------------------------------------------------------------
sub prehodnotit_zakazy
{
    my $stav = shift; # odkaz na hash
    my $r = shift; # index øídícího uzlu naposledy pøidané závislosti
    my $z = shift; # index závislého uzlu naposledy pøidané závislosti
    my $prislusnost_k_useku = $stav->{prislusnost_k_useku}; # odkaz na pole s pøíslu¹ností slov k mezièárkovým úsekùm
    my $hotovost_useku = $stav->{hotovost_useku}; # odkaz na pole s údaji o úplnosti analýzy mezi dvìma èárkami
    my $n_zbyva_zavesit = $stav->{zbyva}; # poèet uzlù, kteøí dosud nemají rodièe
    # Zatím globální promìnné.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    ### Úseky mezi èárkami ###
    # Zvý¹it hotovost úseku, ke kterému nále¾í naposledy zavì¹ený uzel.
    my $hotovost = --$hotovost_useku->[$prislusnost_k_useku->[$z]];
    # Jestli¾e u¾ jsou hotové mezièárkové úseky, povolit i závislosti vedoucí
    # mezi úseky.
    if($hotovost<=1 && $stav->{zakaz} =~ m/:carky/)
    {
        for(my $i = 0; $i <= $#{$hotovost_useku}; $i++)
        {
            if($hotovost_useku->[$i] > 1)
            {
                goto nektere_useky_jeste_nejsou_hotove;
            }
        }
        zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "carky");
        nektere_useky_jeste_nejsou_hotove:
    }
    ### Pøeskakování bezdìtných pøedlo¾ek ###
    if($konfig->{predlozky})
    {
        ### Pøeskakování bezdìtných pøedlo¾ek ###
        # Zru¹it zákaz závislostí, které pøeskakují pøedlo¾ku, je¾ u¾ má dítì.
        if($stav->{uznck}[$r] =~ m/^R/)
        {
            zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "predlozka $r");
        }
        # Teoreticky se mù¾e stát, ¾e na ka¾dém konci vìty zùstane jedna
        # bezdìtná pøedlo¾ka a zbytek zùstane mezi nimi uvìznìn a nebude se
        # moci pøipojit ani na jednu stranu. Proto ve chvíli, kdy zbývá
        # zavìsit poslední uzel, uvolnit v¹echny zákazy.
        if($n_zbyva_zavesit==1)
        {
            zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "predlozka \\d+");
        }
    }
}



1;
