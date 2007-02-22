package zakaz;
use utf8;



#------------------------------------------------------------------------------
# Přidá závislost na černou listinu (resp. přidá další důvod, proč ji tam
# nechat, pokud už tam je).
#------------------------------------------------------------------------------
sub pridat_zakaz
{
    my $zakaz = shift; # odkaz na skalár se seznamem zákazů
    my $r = shift; # index řídícího uzlu hrany, která se má zakázat
    my $z = shift; # index závislého uzlu hrany, která se má zakázat
    my $duvod = shift; # důvod zákazu (aby bylo možné odvolat zákazy mající stejnou příčinu)
    if($$zakaz !~ m/\($r-$z:$duvod\)/)
    {
        $$zakaz .= "($r-$z:$duvod)";
    }
}



#------------------------------------------------------------------------------
# Odebere jeden důvod zákazu dané závislosti z černé listiny. Pokud toto byl
# poslední důvod, závislost se stane povolenou a je opět schopna soutěže.
#------------------------------------------------------------------------------
sub zrusit_zakaz
{
    my $zakaz = shift; # odkaz na skalár se seznamem zákazů
    my $r = shift; # index řídícího uzlu hrany, která se má zakázat
    my $z = shift; # index závislého uzlu hrany, která se má zakázat
    my $duvod = shift; # důvod zákazu (aby bylo možné odvolat zákazy mající stejnou příčinu)
    $$zakaz =~ s/\($r-$z:$duvod\)//g;
}



#------------------------------------------------------------------------------
# Zjistí, zda je závislost na černé listině (dočasně zakázaná).
#------------------------------------------------------------------------------
sub je_zakazana
{
    my $zakaz = shift; # skalár se seznamem zákazů
    my $r = shift; # index řídícího uzlu hrany, která se má zakázat
    my $z = shift; # index závislého uzlu hrany, která se má zakázat
    return $zakaz =~ m/\($r-$z:/;
}



#------------------------------------------------------------------------------
# Inicializuje seznam zákazů na začátku zpracování věty.
# Vrátí řetězec se zakódovaným seznamem zákazů.
# (Jazykově závislá funkce.)
#------------------------------------------------------------------------------
sub formulovat_zakazy
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na hash
    my $prislusnost_k_useku = $stav->{prislusnost_k_useku}; # odkaz na pole s příslušností slov k mezičárkovým úsekům
    my $hotovost_useku = $stav->{hotovost_useku}; # odkaz na pole s údaji o úplnosti analýzy mezi dvěma čárkami
    my $zakaz; # výstupní řetězec
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    ### Závislosti na čárkách jsou zakázány ###
    # Ve skutečnosti totiž závislost na čárce vždy znamená Coord nebo Apos.
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
    ### Úseky mezi čárkami ###
    if($konfig->{mezicarkove_useky})
    {
        # Zapamatovat si rozdělení věty interpunkcí na úseky.
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
        # Zakázat závislosti vedoucí přes čárku. Povoleny budou až po spojení všech
        # mezičárkových úseků.
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
        ### Přeskakování bezdětných předložek ###
        # Zakázat závislosti, které přeskakují předložku, jež dosud nemá dítě.
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
# Zváží uvolnění některých zákazů na základě naposledy přidané závislosti.
# (Jazykově závislá funkce.)
#------------------------------------------------------------------------------
sub prehodnotit_zakazy
{
    my $anot = shift; # odkaz na pole hashů
    my $stav = shift; # odkaz na hash
    my $r = shift; # index řídícího uzlu naposledy přidané závislosti
    my $z = shift; # index závislého uzlu naposledy přidané závislosti
    my $prislusnost_k_useku = $stav->{prislusnost_k_useku}; # odkaz na pole s příslušností slov k mezičárkovým úsekům
    my $hotovost_useku = $stav->{hotovost_useku}; # odkaz na pole s údaji o úplnosti analýzy mezi dvěma čárkami
    my $n_zbyva_zavesit = $stav->{zbyva}; # počet uzlů, kteří dosud nemají rodiče
    # Zatím globální proměnné.
    my $konfig = \%main::konfig;
    ### Úseky mezi čárkami ###
    # Zvýšit hotovost úseku, ke kterému náleží naposledy zavěšený uzel.
    my $hotovost = --$hotovost_useku->[$prislusnost_k_useku->[$z]];
    # Jestliže už jsou hotové mezičárkové úseky, povolit i závislosti vedoucí
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
    ### Přeskakování bezdětných předložek ###
    if($konfig->{predlozky})
    {
        ### Přeskakování bezdětných předložek ###
        # Zrušit zákaz závislostí, které přeskakují předložku, jež už má dítě.
        if($stav->{uznck}[$r] =~ m/^R/)
        {
            zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "predlozka $r");
        }
        # Teoreticky se může stát, že na každém konci věty zůstane jedna
        # bezdětná předložka a zbytek zůstane mezi nimi uvězněn a nebude se
        # moci připojit ani na jednu stranu. Proto ve chvíli, kdy zbývá
        # zavěsit poslední uzel, uvolnit všechny zákazy.
        if($n_zbyva_zavesit==1)
        {
            zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "predlozka \\d+");
        }
    }
}



1;
