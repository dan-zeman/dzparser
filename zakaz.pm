package zakaz;



#------------------------------------------------------------------------------
# P�id� z�vislost na �ernou listinu (resp. p�id� dal�� d�vod, pro� ji tam
# nechat, pokud u� tam je).
#------------------------------------------------------------------------------
sub pridat_zakaz
{
    my $zakaz = shift; # odkaz na skal�r se seznamem z�kaz�
    my $r = shift; # index ��d�c�ho uzlu hrany, kter� se m� zak�zat
    my $z = shift; # index z�visl�ho uzlu hrany, kter� se m� zak�zat
    my $duvod = shift; # d�vod z�kazu (aby bylo mo�n� odvolat z�kazy maj�c� stejnou p���inu)
    if($$zakaz !~ m/\($r-$z:$duvod\)/)
    {
        $$zakaz .= "($r-$z:$duvod)";
    }
}



#------------------------------------------------------------------------------
# Odebere jeden d�vod z�kazu dan� z�vislosti z �ern� listiny. Pokud toto byl
# posledn� d�vod, z�vislost se stane povolenou a je op�t schopna sout�e.
#------------------------------------------------------------------------------
sub zrusit_zakaz
{
    my $zakaz = shift; # odkaz na skal�r se seznamem z�kaz�
    my $r = shift; # index ��d�c�ho uzlu hrany, kter� se m� zak�zat
    my $z = shift; # index z�visl�ho uzlu hrany, kter� se m� zak�zat
    my $duvod = shift; # d�vod z�kazu (aby bylo mo�n� odvolat z�kazy maj�c� stejnou p���inu)
    $$zakaz =~ s/\($r-$z:$duvod\)//g;
}



#------------------------------------------------------------------------------
# Zjist�, zda je z�vislost na �ern� listin� (do�asn� zak�zan�).
#------------------------------------------------------------------------------
sub je_zakazana
{
    my $zakaz = shift; # skal�r se seznamem z�kaz�
    my $r = shift; # index ��d�c�ho uzlu hrany, kter� se m� zak�zat
    my $z = shift; # index z�visl�ho uzlu hrany, kter� se m� zak�zat
    return $zakaz =~ m/\($r-$z:/;
}



#------------------------------------------------------------------------------
# Inicializuje seznam z�kaz� na za��tku zpracov�n� v�ty.
# Vr�t� �et�zec se zak�dovan�m seznamem z�kaz�.
# (Jazykov� z�visl� funkce.)
#------------------------------------------------------------------------------
sub formulovat_zakazy
{
    my $stav = shift; # odkaz na hash
    my $prislusnost_k_useku = $stav->{prislusnost_k_useku}; # odkaz na pole s p��slu�nost� slov k mezi��rkov�m �sek�m
    my $hotovost_useku = $stav->{hotovost_useku}; # odkaz na pole s �daji o �plnosti anal�zy mezi dv�ma ��rkami
    my $zakaz; # v�stupn� �et�zec
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    ### Z�vislosti na ��rk�ch jsou zak�z�ny ###
    # Ve skute�nosti toti� z�vislost na ��rce v�dy znamen� Coord nebo Apos.
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
    ### �seky mezi ��rkami ###
    if($konfig->{mezicarkove_useky})
    {
        # Zapamatovat si rozd�len� v�ty interpunkc� na �seky.
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
        # Zak�zat z�vislosti vedouc� p�es ��rku. Povoleny budou a� po spojen� v�ech
        # mezi��rkov�ch �sek�.
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
        ### P�eskakov�n� bezd�tn�ch p�edlo�ek ###
        # Zak�zat z�vislosti, kter� p�eskakuj� p�edlo�ku, je� dosud nem� d�t�.
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
# Zv�� uvoln�n� n�kter�ch z�kaz� na z�klad� naposledy p�idan� z�vislosti.
# (Jazykov� z�visl� funkce.)
#------------------------------------------------------------------------------
sub prehodnotit_zakazy
{
    my $stav = shift; # odkaz na hash
    my $r = shift; # index ��d�c�ho uzlu naposledy p�idan� z�vislosti
    my $z = shift; # index z�visl�ho uzlu naposledy p�idan� z�vislosti
    my $prislusnost_k_useku = $stav->{prislusnost_k_useku}; # odkaz na pole s p��slu�nost� slov k mezi��rkov�m �sek�m
    my $hotovost_useku = $stav->{hotovost_useku}; # odkaz na pole s �daji o �plnosti anal�zy mezi dv�ma ��rkami
    my $n_zbyva_zavesit = $stav->{zbyva}; # po�et uzl�, kte�� dosud nemaj� rodi�e
    # Zat�m glob�ln� prom�nn�.
    my $konfig = \%main::konfig;
    my $anot = \@main::anot;
    ### �seky mezi ��rkami ###
    # Zv��it hotovost �seku, ke kter�mu n�le�� naposledy zav�en� uzel.
    my $hotovost = --$hotovost_useku->[$prislusnost_k_useku->[$z]];
    # Jestli�e u� jsou hotov� mezi��rkov� �seky, povolit i z�vislosti vedouc�
    # mezi �seky.
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
    ### P�eskakov�n� bezd�tn�ch p�edlo�ek ###
    if($konfig->{predlozky})
    {
        ### P�eskakov�n� bezd�tn�ch p�edlo�ek ###
        # Zru�it z�kaz z�vislost�, kter� p�eskakuj� p�edlo�ku, je� u� m� d�t�.
        if($stav->{uznck}[$r] =~ m/^R/)
        {
            zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "predlozka $r");
        }
        # Teoreticky se m��e st�t, �e na ka�d�m konci v�ty z�stane jedna
        # bezd�tn� p�edlo�ka a zbytek z�stane mezi nimi uv�zn�n a nebude se
        # moci p�ipojit ani na jednu stranu. Proto ve chv�li, kdy zb�v�
        # zav�sit posledn� uzel, uvolnit v�echny z�kazy.
        if($n_zbyva_zavesit==1)
        {
            zrusit_zakaz(\$stav->{zakaz}, "\\d+", "\\d+", "predlozka \\d+");
        }
    }
}



1;
