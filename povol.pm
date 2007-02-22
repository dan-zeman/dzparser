package povol;



#------------------------------------------------------------------------------
# Podle nastaven� konfigurace vybere funkci, kter� um� k libovoln�mu rozpraco-
# van�mu stromu ��ct, kter� z�vislosti do n�j lze v p��t�m kroku p�idat.
#------------------------------------------------------------------------------
sub zjistit_povol
{
    my $konfig = \%main::konfig;
    if($konfig->{neproj})
    {
        my $rodic = shift;
        my $anot = \@main::anot;
        return povolit_rematizator_za_predlozku($anot, $rodic);
    }
    else
    {
        if($konfig->{komponentove})
        {
            return zjistit_povol_komponentove(@_);
        }
        else
        {
            return zjistit_povol_shora_dolu(@_);
        }
    }
}



#------------------------------------------------------------------------------
# Pro libovoln� ne�pln� strom zjist�, kter� z�vislosti je do n�j mo�n� p�idat,
# ani� by naru�ily projektivitu. Strom se p�ed�v� v parametrech jako seznam
# odkaz� na rodi�e. Funkce vrac� seznam povolen�ch hran (pole, ne �et�zec!).
#------------------------------------------------------------------------------
sub zjistit_povol_komponentove
{
    my $rodic = shift; # odkaz na pole index� rodi�� uzl�
    my @povol; # v�stupn� pole
    # P�es $i proj�t uzly, kter� lze zav�sit, proto�e je�t� nemaj� rodi�e.
    # Vynechat uzel �. 0, to bude ka�dop�dn� ko�en.
    for(my $i = 1; $i<=$#{$rodic}; $i++)
    {
        if($rodic->[$i]==-1 || $rodic->[$i] eq "")
        {
            # Vyhledat mezi sousedy uzlu jeho mo�n� rodi�e.
            # Soused� vlevo.
            # Zat�m nev�me, jestli soused vlevo nez�vis� na m�.
            my $nejdale = $i-1;
            my @mozna_povol;
            for(my $j = $nejdale; $j!=-1 && $j ne ""; $j = $rodic->[$j])
            {
                $nejdale = $j if($j<$nejdale);
                if($j==$i)
                {
                    # Sm�la. Zat�m jsem se pohyboval ve sv�m podstromu.
                    splice(@mozna_povol);
                    $j = $nejdale-1;
                    $nejdale = $j;
                }
                push(@mozna_povol, "$j-$i");
            }
            # OK, vypadli jsme na sirotkovi, te� je v @mozna_povol to, co je
            # opravdu dovoleno.
            splice(@povol, $#povol+1, 0, @mozna_povol);
            # Soused� vpravo.
            if($i<$#{$rodic})
            {
                $nejdale = $i+1;
                splice(@mozna_povol);
                for(my $j = $nejdale; $j!=-1 && $j ne ""; $j = $rodic->[$j])
                {
                    $nejdale = $j if($j>$nejdale);
                    if($j==$i)
                    {
                        # Sm�la. Zat�m jsem se pohyboval ve sv�m podstromu.
                        splice(@mozna_povol);
                        $j = $nejdale+1;
                        # Pozor na prav� okraj v�ty!
                        last if($j>$#{$rodic});
                        $nejdale = $j;
                    }
                    push(@mozna_povol, "$j-$i");
                }
                # OK, vypadli jsme na sirotkovi, te� je v @mozna_povol to, co
                # je opravdu dovoleno.
                splice(@povol, $#povol+1, 0, @mozna_povol);
            }
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Zjist�, kter� z�vislosti lze p�idat do stromu, aby byl zachov�n postup shora
# dol�. Pozor, na rozd�l od komponentov�, tato verze nehl�d� projektivitu
# stromu!
#------------------------------------------------------------------------------
sub zjistit_povol_shora_dolu
{
    my $rodic = shift; # odkaz na rozpracovan� strom
    my @povol; # v�stupn� pole
    # Povolen� jsou z�vislosti uzl�, kter� je�t� ve stromu nejsou, na uzlech,
    # kter� ji� ve stromu jsou.
    for(my $i = 0; $i<=$#{$rodic}; $i++)
    {
        if($i==0 || $rodic->[$i]>=0)
        {
            for(my $j = 1; $j<=$#{$rodic}; $j++)
            {
                if($rodic->[$j]==-1)
                {
                    push(@povol, "$i-$j");
                }
            }
        }
    }
#    print(join(",", @{$rodic}), "\n");
#    print(join(",", @povol), "\n");
    return @povol;
}



#------------------------------------------------------------------------------
# Zjist�, zda ur�it� z�vislost je povolen�. Pokud dostane odkaz na seznam
# povolen�ch z�vislost�, pouze projde tento seznam. Jinak si ho nejd��v sama
# zjist� podle glob�ln� prom�nn� @rodic.
#------------------------------------------------------------------------------
sub je_povoleno
{
    my $r = $_[0];
    my $z = $_[1];
    my $povolref = $_[2];
    my @povol;
    if(!$povolref)
    {
        @povol = zjistit_povol(@rodic);
        $povolref = \@povol;
    }
    for(my $i = 0; $i<=$#{$povolref}; $i++)
    {
        if($povolref->[$i] eq "$r-$z")
        {
            return 1;
        }
    }
    return 0;
}



#==============================================================================
# NEPROJEKTIVITY
#==============================================================================



#------------------------------------------------------------------------------
# Na�te seznam rematiz�tor�. Podle nich se daj� poznat neprojektivity typu
# rematiz�tor - p�edlo�ka - slovo vis�c� na p�edlo�ce a ��d�c� rematiz�tor.
#------------------------------------------------------------------------------
sub cist_rematizatory
{
    open(REM, "rematizatory.txt") or die("Nelze otevrit rematizatory: $!\n");
    while(<REM>)
    {
        if(m/^\S+ \d+ \d+ (\S+)/)
        {
            $rematizatory{$1} = 1;
        }
    }
    close(REM);
}



#------------------------------------------------------------------------------
# Povol� neprojektivn� z�vislosti rematiz�tor� na slovech za p�edlo�kou nad
# r�mec toho, co dovoluje modul povol. Podm�nkou je, �e je�t� nebyla naru�ena
# situace, kter� neprojektivity zp�sobuje, tj. p�edev��m rematiz�tor je�t� nem�
# rodi�e, d�le p�edlo�ka nevis� ani na rematiz�toru, ani na slov� za n�.
#------------------------------------------------------------------------------
sub povolit_rematizator_za_predlozku
{
    my $anot = shift;
    my $rodic = shift; # rozpracovan� strom
    my @povol = povolit_infinitivy($anot, $rodic);
    for(my $i = 0; $i<$#{$anot}; $i++)
    {
        # Kv�li obav� z cykl� rad�ji po�adovat, aby uzel za p�edlo�kou byl
        # p�ipojen nanejv�� na p�edlo�ku a p�edlo�ka aby je�t� rodi�e nem�la v�bec.
        if(exists($rematizatory{$anot->[$i]{slovo}}) &&
           $anot->[$i+1]{znacka} =~ m/^R/ &&
           $rodic->[$i] == -1 &&
           $rodic->[$i+1] == -1 &&
           ($rodic->[$i+2] == -1 || $rodic->[$i+2] == $i+1))
        {
            push(@povol, ($i+2)."-".$i);
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Povol� neprojektivn� z�vislosti na infinitivech, pokud infinitiv vis� na sv�m
# lev�m sousedovi a neprojektivita podl�z� pouze tohoto souseda a uzly, kter�
# u� na n�m vis� (p�esn� �e�eno, povol�me, aby na infinitivu viselo nav�c v�e,
# co m��e viset na jeho rodi�i.
#------------------------------------------------------------------------------
sub povolit_infinitivy
{
    my $anot = shift;
    my $rodic = shift; # rozpracovan� strom
    my @povol = povolit_li($anot, $rodic);
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{uznacka} =~ m/^Vf/ &&
           $rodic->[$i]==$i-1)
        {
            # Povolit v�em uzl�m, kter� mohou zleva viset na uzlu nalevo od
            # infinitivu, aby visely i na infinitivu samotn�m.
            for(my $j = 0; $j<=$#povol; $j++)
            {
                $povol[$j] =~ m/^(\d+)-(\d+)$/;
                my $r = $1;
                my $z = $2;
                if($r==$i-1 && $z<$r)
                {
                    push(@povol, "$i-$z");
                }
            }
        }
    }
    return @povol;
}



#------------------------------------------------------------------------------
# Povol� neprojektivn� z�vislosti p�es -li a v�ak.
#------------------------------------------------------------------------------
sub povolit_li
{
    my $anot = shift;
    my $rodic = shift; # rozpracovan� strom
    my @povol = zjistit_povol_komponentove($rodic);
    for(my $i = 1; $i<=$#{$anot}; $i++)
    {
        if($anot->[$i]{slovo} eq "li" &&
           $anot->[$i-1]{slovo} eq "-" &&
           $i>2)
        {
            # Povolit v�em uzl�m, kter� mohou zprava viset na li, aby visely i
            # na slov� p�ed poml�kou.
            for(my $j = 0; $j<=$#povol; $j++)
            {
                $povol[$j] =~ m/^(\d+)-(\d+)$/;
                my $r = $1;
                my $z = $2;
                if($r==$i && $z>$r)
                {
                    push(@povol, ($i-2)."-$z");
                }
            }
        }
        elsif($anot->[$i]{slovo} eq "v�ak" && $i>1 && $i<$#{$anot})
        {
            # Povolit v�em uzl�m, kter� mohou zleva viset na v�ak, aby visely i
            # na jeho prav�m sousedovi, a v�em uzl�m, kter� mohou na v�ak viset
            # zprava, aby visely i na jeho lev�m sousedovi.
            for(my $j = 0; $j<=$#povol; $j++)
            {
                $povol[$j] =~ m/^(\d+)-(\d+)$/;
                my $r = $1;
                my $z = $2;
                if($r==$i)
                {
                    if($z<$i)
                    {
                        # Pozor, mohl by vzniknout cyklus! Nap�. pokud je "v�ak" na pozici
                        # 2 a u� minule bylo p�esko�eno z�vislost� 3-1, nesm�me te� bezhlav�
                        # dovolit z�vislost 1-3!
                        my $ok = 1;
                        for(my $k = $i+1; $k>0; $k = $rodic->[$k])
                        {
                            if($k==$z)
                            {
                                $ok = 0;
                                last;
                            }
                        }
                        if($ok)
                        {
                            push(@povol, ($i+1)."-$z");
                        }
                    }
                    else
                    {
                        # Pozor, mohl by vzniknout cyklus! Nap�. pokud je "v�ak" na pozici
                        # 2 a u� minule bylo p�esko�eno z�vislost� 3-1, nesm�me te� bezhlav�
                        # dovolit z�vislost 1-3!
                        my $ok = 1;
                        for(my $k = $i-1; $k>0; $k = $rodic->[$k])
                        {
                            if($k==$z)
                            {
                                $ok = 0;
                                last;
                            }
                        }
                        if($ok)
                        {
                            push(@povol, ($i-1)."-$z");
                        }
                    }
                }
            }
        }
    }
    return @povol;
}



1;
